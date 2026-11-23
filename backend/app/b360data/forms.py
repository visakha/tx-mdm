"""Dynamic Pydantic model per business entity, built from its metadata. ONE place for the rule.

Vamsi (voice, 2026-11-23 01:06 CST): "show me a form based on the metadata that you have
inferred ... most probably Pydantic should be able to do that."

record_model(entity) -> a pydantic.create_model class: one attribute per ROOT field, typed by its
FieldDataType, required when the metadata marks it mandatory. The same class validates what the
form saves and what the generator produces, before anything is sent to IDMC.
Field groups are not in the form yet (root fields only in 0.9.8).
"""

import json
from datetime import date, datetime
from typing import Any

from pydantic import BaseModel, ConfigDict, Field, ValidationError, create_model

from app.b360data.models import (
    BusinessEntity,
    EntityField,
    FieldDataType,
    FieldValue,
    FormField,
    FormInput,
    FormSchema,
)

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
    definitions = {f"f{i}": _definition(field) for i, field in enumerate(entity.fields)}
    model: type[BaseModel] = create_model(  # type: ignore[call-overload]
        _model_name(entity),
        __config__=ConfigDict(extra="forbid", populate_by_name=False),
        **definitions,
    )
    return model


def form_schema(entity: BusinessEntity) -> FormSchema:
    model = record_model(entity)
    return FormSchema(
        entity=entity.name,
        label=entity.label,
        model_name=model.__name__,
        fields=[
            FormField(
                name=f.name,
                label=f.label,
                data_type=f.data_type,
                input=form_input(f.data_type),
                required=f.mandatory,
            )
            for f in entity.fields
        ],
        skipped_groups=[g.name for g in entity.field_groups],
        json_schema_text=json.dumps(model.model_json_schema(by_alias=True), indent=2),
    )


class RecordInvalidError(ValueError):
    """One record does not fit the entity's dynamic model. Nothing was sent."""

    def __init__(self, index: int, problems: list[str]) -> None:
        super().__init__(f"record {index}: " + "; ".join(problems))
        self.index = index
        self.problems = problems


def validate_values(
    entity: BusinessEntity, values: dict[str, FieldValue], index: int
) -> dict[str, FieldValue]:
    """Validate with the dynamic model; return the cleaned values keyed by IDMC field name.

    Empty strings on optional fields are dropped (an empty form box means "not given").
    """
    given = {k: v for k, v in values.items() if not (v == "" or v is None)}
    try:
        parsed = record_model(entity).model_validate(given)
    except ValidationError as exc:
        problems = [f"{'.'.join(str(p) for p in err['loc'])}: {err['msg']}" for err in exc.errors()]
        raise RecordInvalidError(index, problems) from exc
    dumped: dict[str, FieldValue] = parsed.model_dump(by_alias=True, exclude_none=True)
    return dumped


def wire_body(entity: BusinessEntity, values: dict[str, FieldValue]) -> dict[str, object]:
    """Request body for Create Master Record: root fields by name.

    Picklist fields go as {"Code": value}, the shape the reference's example uses (pp. 52-53).
    Dates go as ISO text. UNVERIFIED for picklists on Vamsi's org (zlv_guest has none).
    """
    types = {f.name: f.data_type for f in entity.fields}
    body: dict[str, object] = {}
    for name, value in values.items():
        kind = types.get(name)
        if isinstance(value, datetime | date):
            body[name] = value.isoformat()
        elif kind in (FieldDataType.PICKLIST, FieldDataType.DEPENDENT_PICKLIST):
            body[name] = {"Code": value}
        else:
            body[name] = value
    return body
