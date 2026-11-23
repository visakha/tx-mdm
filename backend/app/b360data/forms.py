"""Dynamic Pydantic model per business entity, built from its metadata. ONE place for the rule.

Vamsi (voice, 2026-11-23 01:06 CST): "show me a form based on the metadata that you have
inferred ... most probably Pydantic should be able to do that."

record_model(entity) -> a pydantic.create_model class: one attribute per ROOT field, typed by its
FieldDataType, required when the metadata marks it mandatory. The same class validates what the
form saves and what the generator produces, before anything is sent to IDMC.
0.9.10: field groups too (any group in the metadata, not just x_phone): each group gets its own
dynamic model the same way, rows are validated with it, and the create / update body carries them
in the reference's shape (list of rows with "_id", picklists as {"Code": ...}, pp. 53-54, 86-87).
"""

import json
import uuid
from datetime import date, datetime
from typing import Any

from pydantic import BaseModel, ConfigDict, Field, ValidationError, create_model

from app.b360data.models import (
    BusinessEntity,
    EntityField,
    FieldDataType,
    FieldGroup,
    FieldValue,
    FormField,
    FormGroup,
    FormInput,
    FormSchema,
    NewGroupRow,
    NewGroupRows,
    NewRecord,
    PatchOp,
    PatchOperation,
    PicklistOption,
    PicklistSource,
)

# (group name or "" for root, field name) -> options IDMC returned
PicklistOptions = dict[tuple[str, str], list[PicklistOption]]
_PICKLISTS = (FieldDataType.PICKLIST, FieldDataType.DEPENDENT_PICKLIST)
Scalar = str | int | float | bool | None
WireCell = Scalar | dict[str, Scalar]

_PY_TYPE: dict[FieldDataType, type] = {
    FieldDataType.STRING: str,
    FieldDataType.PICKLIST: str,
    FieldDataType.DEPENDENT_PICKLIST: str,
    FieldDataType.UNKNOWN: str,
    FieldDataType.INTEGER: int,
    FieldDataType.DOUBLE: float,
    FieldDataType.DECIMAL: float,
    FieldDataType.BOOLEAN: bool,
    FieldDataType.DATE: date,
    FieldDataType.DATETIME: datetime,
}

_INPUT: dict[FieldDataType, FormInput] = {
    FieldDataType.INTEGER: FormInput.INTEGER,
    FieldDataType.DOUBLE: FormInput.DECIMAL,
    FieldDataType.DECIMAL: FormInput.DECIMAL,
    FieldDataType.BOOLEAN: FormInput.CHECKBOX,
    FieldDataType.DATE: FormInput.DATE,
    FieldDataType.DATETIME: FormInput.DATETIME,
}


def form_input(data_type: FieldDataType) -> FormInput:
    return _INPUT.get(data_type, FormInput.TEXT)


def _model_name(entity: BusinessEntity) -> str:
    cleaned = "".join(ch if ch.isalnum() else "_" for ch in entity.name)
    return f"Record_{cleaned}"


def _definition(field: EntityField) -> tuple[Any, Any]:
    py_type = _PY_TYPE[field.data_type]
    if field.mandatory:
        min_length = 1 if py_type is str else None
        return (py_type, Field(alias=field.name, title=field.label, min_length=min_length))
    return (py_type | None, Field(default=None, alias=field.name, title=field.label))


def record_model(entity: BusinessEntity) -> type[BaseModel]:
    """Python attribute names are f0, f1, ...; the alias is the IDMC field name (any spelling)."""
    return _fields_model(_model_name(entity), entity.fields)


def group_model(entity: BusinessEntity, group: FieldGroup) -> type[BaseModel]:
    cleaned = "".join(ch if ch.isalnum() else "_" for ch in group.name)
    return _fields_model(f"{_model_name(entity)}__{cleaned}", group.fields)


def _fields_model(name: str, fields: list[EntityField]) -> type[BaseModel]:
    definitions = {f"f{i}": _definition(field) for i, field in enumerate(fields)}
    model: type[BaseModel] = create_model(  # type: ignore[call-overload]
        name,
        __config__=ConfigDict(extra="forbid", populate_by_name=False),
        **definitions,
    )
    return model


def _form_field(group: str, f: EntityField, options: PicklistOptions) -> FormField:
    is_pick = f.data_type in _PICKLISTS
    found = options.get((group, f.name), []) if is_pick else []
    source = None
    if is_pick:
        source = PicklistSource.OBSERVED_IN_RECORDS if found else PicklistSource.NONE
    return FormField(
        name=f.name,
        label=f.label,
        data_type=f.data_type,
        input=form_input(f.data_type),
        required=f.mandatory,
        options=found,
        options_source=source,
    )


PICKLIST_NOTE = (
    "Picklist options are the distinct {Code, Name} values IDMC returned in this entity's own "
    "records (Search API). The B360 REST API Reference documents no call that lists a picklist's "
    "allowed values, so a picklist nobody has filled yet has no options and is left empty "
    "(type the Code yourself). Nothing is invented."
)


def form_schema(entity: BusinessEntity, options: PicklistOptions | None = None) -> FormSchema:
    opts = options or {}
    model = record_model(entity)
    return FormSchema(
        entity=entity.name,
        label=entity.label,
        model_name=model.__name__,
        fields=[_form_field("", f, opts) for f in entity.fields],
        groups=[
            FormGroup(
                name=g.name,
                label=g.label,
                cardinality=g.cardinality,
                fields=[_form_field(g.name, f, opts) for f in g.fields],
            )
            for g in entity.field_groups
        ],
        skipped_groups=[],
        json_schema_text=json.dumps(model.model_json_schema(by_alias=True), indent=2),
        picklist_note=PICKLIST_NOTE,
    )


class RecordInvalidError(ValueError):
    """One record does not fit the entity's dynamic model. Nothing was sent."""

    def __init__(self, index: int, problems: list[str]) -> None:
        super().__init__(f"record {index}: " + "; ".join(problems))
        self.index = index
        self.problems = problems


def _validate(
    model: type[BaseModel], values: dict[str, FieldValue], index: int, where: str
) -> dict[str, FieldValue]:
    given = {k: v for k, v in values.items() if not (v == "" or v is None)}
    try:
        parsed = model.model_validate(given)
    except ValidationError as exc:
        problems = [
            f"{where}{'.'.join(str(p) for p in err['loc'])}: {err['msg']}" for err in exc.errors()
        ]
        raise RecordInvalidError(index, problems) from exc
    dumped: dict[str, FieldValue] = parsed.model_dump(by_alias=True, exclude_none=True)
    return dumped


def validate_values(
    entity: BusinessEntity, values: dict[str, FieldValue], index: int
) -> dict[str, FieldValue]:
    """Validate with the dynamic model; return the cleaned values keyed by IDMC field name.

    Empty strings on optional fields are dropped (an empty form box means "not given").
    """
    return _validate(record_model(entity), values, index, "")


def validate_groups(
    entity: BusinessEntity, groups: list[NewGroupRows], index: int
) -> list[NewGroupRows]:
    """Validate every group row with its group's dynamic model. Unknown group -> invalid.

    Rows with no value at all are dropped (an empty repeatable block means "no row").
    """
    by_name = {g.name: g for g in entity.field_groups}
    out: list[NewGroupRows] = []
    for block in groups:
        group = by_name.get(block.group)
        if group is None:
            raise RecordInvalidError(index, [f"{block.group}: not a field group of {entity.name}"])
        if group.cardinality.value == "ONE" and len(block.rows) > 1:
            raise RecordInvalidError(index, [f"{block.group}: cardinality ONE, got rows"])
        model = group_model(entity, group)
        rows = []
        for n, row in enumerate(block.rows):
            cleaned = _validate(model, row.values, index, f"{block.group}[{n}].")
            if cleaned or row.row_id:
                rows.append(NewGroupRow(row_id=row.row_id, values=cleaned))
        out.append(NewGroupRows(group=block.group, rows=rows))
    return out


def wire_value(value: FieldValue, kind: FieldDataType | None) -> WireCell:
    """One value as the reference sends it: picklist {"Code": ...} (pp. 53, 86), dates ISO."""
    if isinstance(value, datetime | date):
        return value.isoformat()
    if kind in _PICKLISTS and value is not None:
        return {"Code": value if not isinstance(value, bool) else str(value)}
    return value


def wire_row(group: FieldGroup, row: NewGroupRow) -> dict[str, WireCell]:
    """A group row with its "_id" (made here when new: uuid4 hex, like the reference's ids)."""
    types = {f.name: f.data_type for f in group.fields}
    body: dict[str, WireCell] = {"_id": row.row_id or uuid.uuid4().hex}
    for name, value in row.values.items():
        body[name] = wire_value(value, types.get(name))
    return body


def wire_body(
    entity: BusinessEntity,
    values: dict[str, FieldValue],
    groups: list[NewGroupRows] | None = None,
) -> dict[str, object]:
    """Request body for Create Master Record: root fields by name, then field groups as lists of
    rows (pp. 52-54 example: "Phone": [{"_id": ..., "phoneType": {"Code": ...}, ...}]).

    UNVERIFIED on Vamsi's org for picklists and groups (x_phone is his first group).
    """
    types = {f.name: f.data_type for f in entity.fields}
    body: dict[str, object] = {name: wire_value(v, types.get(name)) for name, v in values.items()}
    by_name = {g.name: g for g in entity.field_groups}
    for block in groups or []:
        group = by_name.get(block.group)
        if group is not None and block.rows:
            body[block.group] = [wire_row(group, row) for row in block.rows]
    return body


def _same(a: FieldValue, b: FieldValue) -> bool:
    if isinstance(a, datetime | date) or isinstance(b, datetime | date):
        return str(a) == str(b)
    return a == b


def _loose(model: type[BaseModel], values: dict[str, FieldValue]) -> dict[str, FieldValue]:
    """The loaded record, coerced like the edit so 5 and "5" compare equal; raw if it won't fit."""
    try:
        return _validate(model, values, 0, "")
    except RecordInvalidError:
        return {k: v for k, v in values.items() if not (v == "" or v is None)}


def patch_ops(
    entity: BusinessEntity,
    original: NewRecord,
    new_values: dict[str, FieldValue],
    new_groups: list[NewGroupRows],
) -> list[PatchOp]:
    """Only what changed, as Update Source Record Field operations (pp. 88-90).

    verified=True: the path shape is in the reference ("firstName", "Phone[<_id>].phoneNumber",
    op replace). verified=False (UNVERIFIED): remove of a field, add of a new group row
    (path "<group>", value [row]) and remove of a row ("<group>[<_id>]").
    """
    ops: list[PatchOp] = []
    old_values = _loose(record_model(entity), original.values)
    for f in entity.fields:
        old, new = old_values.get(f.name), new_values.get(f.name)
        if _same(old, new):
            continue
        if new is None:
            ops.append(PatchOp(op=PatchOperation.REMOVE, path=f.name, old=old, verified=False))
        else:
            ops.append(
                PatchOp(
                    op=PatchOperation.REPLACE,
                    path=f.name,
                    value=wire_value(new, f.data_type),
                    old=old,
                    new=new,
                    verified=True,
                )
            )
    old_groups = {b.group: b for b in original.groups}
    new_by_group = {b.group: b for b in new_groups}
    for group in entity.field_groups:
        model = group_model(entity, group)
        before = {
            r.row_id: _loose(model, r.values)
            for r in (old_groups[group.name].rows if group.name in old_groups else [])
            if r.row_id
        }
        after = new_by_group[group.name].rows if group.name in new_by_group else []
        # rows IDMC returned without an _id cannot be addressed; unchanged ones are not "new"
        unaddressed = [
            _loose(model, r.values)
            for r in (old_groups[group.name].rows if group.name in old_groups else [])
            if not r.row_id
        ]
        kept: set[str] = set()
        for row in after:
            if row.row_id and row.row_id in before:
                kept.add(row.row_id)
                old_row = before[row.row_id]
                for f in group.fields:
                    old, new = old_row.get(f.name), row.values.get(f.name)
                    if _same(old, new):
                        continue
                    path = f"{group.name}[{row.row_id}].{f.name}"
                    if new is None:
                        ops.append(
                            PatchOp(op=PatchOperation.REMOVE, path=path, old=old, verified=False)
                        )
                    else:
                        ops.append(
                            PatchOp(
                                op=PatchOperation.REPLACE,
                                path=path,
                                value=wire_value(new, f.data_type),
                                old=old,
                                new=new,
                                verified=True,
                            )
                        )
            elif not row.row_id and row.values in unaddressed:
                unaddressed.remove(row.values)
            elif row.values:
                ops.append(
                    PatchOp(
                        op=PatchOperation.ADD,
                        path=group.name,
                        value=[wire_row(group, row)],
                        new=", ".join(f"{k}={v}" for k, v in row.values.items()),
                        verified=False,
                    )
                )
        for row_id in before:
            if row_id not in kept:
                ops.append(
                    PatchOp(
                        op=PatchOperation.REMOVE,
                        path=f"{group.name}[{row_id}]",
                        old=", ".join(f"{k}={v}" for k, v in before[row_id].items()),
                        verified=False,
                    )
                )
    return ops
