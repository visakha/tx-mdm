"""The client boundary: IDMC JSON in, typed models out. The only place raw JSON is read.

Wire shapes (Business 360 REST API Reference, Oct 2026):
  - metadata objects (Relationship Metadata API pp. 94-96): "eClass"
    "http://informatica.com/mdm/v2/Core#//<Type>", "guid", "name", "label" {"en": ...},
    a "field" list, each field with eClass (TextField, IntegerField), "allowMany",
    "mandatory", "options"; list calls are paged as {"content": [...]}.
  - search (pp. 20-36): {"searchResult": {"hits", "records": [...]}}; record keys are
    "<entity without dots>.<field>" (c360person.lastName, p. 33), field groups are arrays,
    picklists are objects with "Name" (and "Code"), "_meta" carries "businessId" (p. 27).

UNVERIFIED (not printed in the reference; exercised only against dev/fake_idmc.py):
  - how business entities sit inside tenantModel/datamodel: we take every metadata object with
    eClass ...#//BusinessEntity, or listed under a "businessEntity" key with a guid;
  - field-group detection: a field entry that has its own "field" list or eClass ...FieldGroup;
  - eClass names other than TextField / IntegerField (DateField, BooleanField, LookupField ...);
  - "searchable" inside a field's options (Informatica KB says to look for "searchable": true).
"""

from datetime import UTC, date, datetime

from pydantic import BaseModel, ConfigDict, Field, JsonValue, TypeAdapter, ValidationError

from app.b360data import scope as entity_scope
from app.b360data.models import (
    BusinessEntity,
    BusinessEntitySummary,
    Cardinality,
    EntityField,
    EntityRecord,
    FieldDataType,
    FieldGroup,
    FieldGroupRows,
    FieldOrigin,
    FieldValue,
    OriginSource,
)

_JSON = TypeAdapter(JsonValue)

# eClass suffix -> data type. TextField and IntegerField are in the reference (p. 95); the
# rest follow the same naming and are UNVERIFIED.
ECLASS_TYPES: dict[str, FieldDataType] = {
    "TextField": FieldDataType.STRING,
    "StringField": FieldDataType.STRING,
    "IntegerField": FieldDataType.INTEGER,
    "LongField": FieldDataType.INTEGER,
    "DoubleField": FieldDataType.DOUBLE,
    "FloatField": FieldDataType.DOUBLE,
    "DecimalField": FieldDataType.DECIMAL,
    "BooleanField": FieldDataType.BOOLEAN,
    "DateField": FieldDataType.DATE,
    "DateTimeField": FieldDataType.DATETIME,
    "LookupField": FieldDataType.PICKLIST,
    "PicklistField": FieldDataType.PICKLIST,
    "DependentLookupField": FieldDataType.DEPENDENT_PICKLIST,
    "DependentPicklistField": FieldDataType.DEPENDENT_PICKLIST,
}


class _Wire(BaseModel):
    model_config = ConfigDict(extra="ignore", populate_by_name=True)


class WireLabel(_Wire):
    en: str | None = None


class WireOptions(_Wire):
    searchable: bool | None = None


class WireNode(_Wire):
    """One metadata object: business entity, field group or field."""

    e_class: str = Field(default="", alias="eClass")
    guid: str | None = None
    name: str = ""
    label: WireLabel | str | None = None
    allow_many: bool | None = Field(default=None, alias="allowMany")
    mandatory: bool | None = None
    searchable: bool | None = None
    options: WireOptions | None = None
    system: bool | None = None  # UNVERIFIED flag names for system-defined metadata objects
    system_field: bool | None = Field(default=None, alias="systemField")
    is_system: bool | None = Field(default=None, alias="isSystem")
    field: list["WireNode"] | None = None
    fields: list["WireNode"] | None = None

    @property
    def type_name(self) -> str:
        return self.e_class.rsplit("//", 1)[-1] if "//" in self.e_class else self.e_class

    @property
    def text(self) -> str:
        if isinstance(self.label, WireLabel) and self.label.en:
            return self.label.en
        if isinstance(self.label, str) and self.label:
            return self.label
        return self.name or self.guid or ""

    @property
    def is_system_object(self) -> bool:
        """System-defined: an explicit system flag, or a name starting with "_" (like _meta).

        UNVERIFIED: the reference does not print the businessEntity metadata reply, so we do not
        know whether (or how) it marks system fields. Live zlv_guest (2026-11-23) came back with
        configured fields only.
        """
        return bool(self.system or self.system_field or self.is_system) or self.name.startswith("_")

    @property
    def children(self) -> list["WireNode"]:
        return [c for c in (self.field or self.fields or []) if c.name]

    @property
    def is_group(self) -> bool:
        return bool(self.children) or self.type_name.endswith("FieldGroup")


class WireSearchResult(_Wire):
    hits: int | None = None
    records: list[dict[str, JsonValue]] = Field(default_factory=list)


class WireSearchResponse(_Wire):
    search_result: WireSearchResult = Field(default_factory=WireSearchResult, alias="searchResult")


# ---- parsing (boundary) ----------------------------------------------------------------------


def as_json(body: object) -> JsonValue:
    """Validate an httpx JSON body once into pydantic's typed JsonValue."""
    return _JSON.validate_python(body)


def _nodes(value: JsonValue) -> list[dict[str, JsonValue]]:
    found: list[dict[str, JsonValue]] = []
    stack: list[JsonValue] = [value]
    while stack:
        cur = stack.pop()
        if isinstance(cur, dict):
            found.append(cur)
            stack.extend(cur.values())
        elif isinstance(cur, list):
            stack.extend(cur)
    return found


def _node(raw: JsonValue) -> WireNode | None:
    try:
        return WireNode.model_validate(raw)
    except ValidationError:
        return None


def entities_from_datamodel(body: object) -> list[BusinessEntitySummary]:
    seen: dict[str, BusinessEntitySummary] = {}
    for raw in _nodes(as_json(body)):
        candidates: list[JsonValue] = []
        if str(raw.get("eClass") or "").endswith("#//BusinessEntity"):
            candidates.append(raw)
        listed = raw.get("businessEntity")
        if isinstance(listed, list):
            candidates.extend(listed)
        for cand in candidates:
            node = _node(cand)
            key = node.guid or node.name if node else None
            if node and key and key not in seen:
                seen[key] = BusinessEntitySummary(
                    name=key,
                    label=node.text,
                    category=entity_scope.category_of(key),
                    focus=entity_scope.is_focus(key),
                )
    return sorted(seen.values(), key=lambda e: e.label.lower())


def _origin(node: WireNode, parent_system: bool = False) -> FieldOrigin:
    return FieldOrigin.SYSTEM if parent_system or node.is_system_object else FieldOrigin.CONFIGURED


def _field(node: WireNode, parent_system: bool = False) -> EntityField:
    raw_type = node.type_name
    searchable = bool(node.searchable or (node.options and node.options.searchable))
    return EntityField(
        name=node.name,
        label=node.text,
        data_type=ECLASS_TYPES.get(raw_type, FieldDataType.UNKNOWN),
        raw_type=raw_type,
        searchable=searchable,
        mandatory=bool(node.mandatory),
        origin=_origin(node, parent_system),
    )


def _group(node: WireNode) -> FieldGroup:
    system = node.is_system_object
    return FieldGroup(
        name=node.name,
        label=node.text,
        cardinality=Cardinality.ONE if node.allow_many is False else Cardinality.MANY,
        fields=[_field(c, system) for c in node.children if not c.is_group],
        origin=_origin(node),
    )


# ---- documented system fields (0.9.9) ---------------------------------------------------------
# B360 REST API Reference Oct 2026. _meta parameters: Read Master Record by Business ID pp. 56-57
# and p. 61-62; search response p. 27 (score, status). System filter fields: Search API p. 25 and
# p. 29 (recordStateIndicator), p. 26 (_indexValidationError.code). Shown only when the org's
# metadata reply does not already list them.


def _doc_field(
    name: str, label: str, data_type: FieldDataType = FieldDataType.STRING
) -> EntityField:
    return EntityField(
        name=name,
        label=label,
        data_type=data_type,
        raw_type="documented",
        searchable=False,
        mandatory=False,
        origin=FieldOrigin.SYSTEM,
        origin_source=OriginSource.DOCUMENTED,
    )


DOCUMENTED_SYSTEM_FIELDS: tuple[EntityField, ...] = (
    _doc_field("validationType", "Validation type (ERROR, WARNING, INFO)"),
    _doc_field("validationState", "Validation state (PASSED, FAILED)"),
    _doc_field("recordStateIndicator", "Record state (ACTIVE, DELETED)"),
    _doc_field("_indexValidationError.code", "Index validation error code"),
)

DOCUMENTED_SYSTEM_GROUPS: tuple[FieldGroup, ...] = (
    FieldGroup(
        name="_meta",
        label="Record system metadata",
        cardinality=Cardinality.ONE,
        origin=FieldOrigin.SYSTEM,
        origin_source=OriginSource.DOCUMENTED,
        fields=[
            _doc_field("businessId", "Business ID"),
            _doc_field("id", "Internal ID (do not use)"),
            _doc_field("businessEntity", "Business entity"),
            _doc_field("state", "State (search: status)"),
            _doc_field("validation", "Validation status"),
            _doc_field("consolidation", "Match and merge status"),
            _doc_field("searchIndex", "Search index state"),
            _doc_field("score", "Trust score (search)", FieldDataType.DOUBLE),
            _doc_field("createdBy", "Created by"),
            _doc_field("creationDate", "Creation date", FieldDataType.DATETIME),
            _doc_field("updatedBy", "Updated by"),
            _doc_field("lastUpdateDate", "Last update date", FieldDataType.DATETIME),
            _doc_field("changeList", "Pending workflow task id"),
        ],
    ),
)


def business_entity_from_metadata(body: object, guid: str) -> BusinessEntity:
    value = as_json(body)
    paged = value.get("content") if isinstance(value, dict) else None
    if isinstance(paged, list):  # paged form, p. 95
        content = [n for n in (_node(c) for c in paged) if n is not None]
        root = next((n for n in content if n.guid == guid), content[0] if content else WireNode())
    else:
        root = _node(value) or WireNode()
    all_fields = [_field(c) for c in root.children if not c.is_group]
    all_groups = [_group(g) for g in root.children if g.is_group]
    sys_fields = [f for f in all_fields if f.origin is FieldOrigin.SYSTEM]
    sys_groups = [g for g in all_groups if g.origin is FieldOrigin.SYSTEM]
    seen_f = {f.name for f in sys_fields}
    seen_g = {g.name for g in sys_groups}
    sys_fields += [f for f in DOCUMENTED_SYSTEM_FIELDS if f.name not in seen_f]
    sys_groups += [g for g in DOCUMENTED_SYSTEM_GROUPS if g.name not in seen_g]
    return BusinessEntity(
        name=guid,
        label=root.text or guid,
        fields=[f for f in all_fields if f.origin is FieldOrigin.CONFIGURED],
        field_groups=[g for g in all_groups if g.origin is FieldOrigin.CONFIGURED],
        system_fields=sys_fields,
        system_field_groups=sys_groups,
    )


def search_response(body: object) -> WireSearchResult:
    return WireSearchResponse.model_validate(as_json(body)).search_result


# ---- typed values ----------------------------------------------------------------------------


def _picklist_text(raw: dict[str, JsonValue]) -> str | None:
    for key in ("Name", "name", "Code", "code"):
        item = raw.get(key)
        if isinstance(item, (str, int, float)) and not isinstance(item, bool):
            return str(item)
    return None


def _epoch_or_iso(raw: JsonValue) -> datetime | None:
    if isinstance(raw, (int, float)) and not isinstance(raw, bool):
        return datetime.fromtimestamp(raw / 1000, tz=UTC)
    if isinstance(raw, str) and raw.isdigit():  # search returns epoch ms as a string (p. 27)
        return datetime.fromtimestamp(int(raw) / 1000, tz=UTC)
    if isinstance(raw, str):
        try:
            return datetime.fromisoformat(raw.replace("Z", "+00:00"))
        except ValueError:
            return None
    return None


def _is_number(raw: JsonValue) -> bool:
    return isinstance(raw, (int, float)) and not isinstance(raw, bool)


def typed_value(raw: JsonValue, data_type: FieldDataType) -> FieldValue:
    """Convert one raw cell to the member of FieldValue its declared data type calls for."""
    if raw is None:
        return None
    if isinstance(raw, dict):
        return _picklist_text(raw)
    if isinstance(raw, list):
        return f"[{len(raw)} items]"
    match data_type:
        case FieldDataType.INTEGER:
            return (
                int(raw)
                if isinstance(raw, (int, float)) and not isinstance(raw, bool)
                else str(raw)
            )
        case FieldDataType.DOUBLE | FieldDataType.DECIMAL:
            return (
                float(raw)
                if isinstance(raw, (int, float)) and not isinstance(raw, bool)
                else str(raw)
            )
        case FieldDataType.BOOLEAN:
            return raw if isinstance(raw, bool) else str(raw).lower() == "true"
        case FieldDataType.DATETIME:
            return _epoch_or_iso(raw) or str(raw)
        case FieldDataType.DATE:
            moment = _epoch_or_iso(raw)
            if isinstance(raw, str) and len(raw) == 10:
                try:
                    return date.fromisoformat(raw)
                except ValueError:
                    return raw
            return moment.date() if moment else str(raw)
        case _:
            return str(raw)


def _local(key: str) -> str:
    return key.split(".", 1)[1] if "." in key else key


def record_from_search(raw: dict[str, JsonValue], entity: BusinessEntity) -> EntityRecord:
    by_local = {_local(k): v for k, v in raw.items() if not k.startswith("_")}
    meta = raw.get("_meta")
    meta_d: dict[str, JsonValue] = meta if isinstance(meta, dict) else {}
    business_id = meta_d.get("businessId")
    updated_by = meta_d.get("updatedBy")
    values = {f.name: typed_value(by_local.get(f.name), f.data_type) for f in entity.fields}
    groups: list[FieldGroupRows] = []
    for group in entity.field_groups:
        cell = by_local.get(group.name)
        rows = cell if isinstance(cell, list) else [cell] if isinstance(cell, dict) else []
        groups.append(
            FieldGroupRows(
                group=group.name,
                rows=[
                    {f.name: typed_value(row.get(f.name), f.data_type) for f in group.fields}
                    for row in rows
                    if isinstance(row, dict)
                ],
            )
        )
    return EntityRecord(
        business_id=str(business_id) if business_id is not None else "",
        values=values,
        groups=groups,
        last_updated=_epoch_or_iso(meta_d.get("lastUpdateDate")),
        updated_by=str(updated_by) if isinstance(updated_by, (str, int)) else None,
    )


def key_prefix(records: list[dict[str, JsonValue]]) -> str | None:
    """The "<prefix>." of the search record keys (c360person on p. 33), as IDMC really sent it."""
    for record in records:
        for key in record:
            if not key.startswith("_") and "." in key:
                return key.split(".", 1)[0]
    return None


def unknown_keys(records: list[dict[str, JsonValue]], entity: BusinessEntity) -> list[str]:
    known = {f.name for f in entity.fields} | {g.name for g in entity.field_groups}
    found = {_local(k) for r in records for k in r if not k.startswith("_")}
    return sorted(found - known)


# ---------------------------------------------------------------------------------------------
# 0.9.8 Add records
# ---------------------------------------------------------------------------------------------


def source_system_ids(body: object) -> list[str]:
    """Ids from the (undocumented) source-system metadata call. UNVERIFIED shape.

    Takes every JSON object whose eClass ends with "SourceSystem" (the style of the other
    /metadata/api/v2/objects replies), anywhere in the reply, plus {"content": [...]} paging.
    The id is "guid" if present, else "name". Order kept, duplicates dropped.
    """
    found: list[str] = []

    def walk(node: JsonValue) -> None:
        if isinstance(node, dict):
            e_class = node.get("eClass")
            if isinstance(e_class, str) and e_class.endswith("SourceSystem"):
                ident = node.get("guid") or node.get("name")
                if isinstance(ident, str) and ident and ident not in found:
                    found.append(ident)
            for value in node.values():
                walk(value)
        elif isinstance(node, list):
            for value in node:
                walk(value)

    walk(as_json(body))
    return found


class WireCreated(_Wire):
    """Create Master Record 200 reply (reference p. 55). id is deprecated; businessId wins."""

    approval_required: bool | None = Field(default=None, alias="approvalRequired")
    business_id: str | int | None = Field(default=None, alias="businessId")
    id: str | int | None = None


def created_record(body: object) -> WireCreated:
    data = as_json(body)
    return WireCreated.model_validate(data if isinstance(data, dict) else {})
