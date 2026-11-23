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
    FieldLookup,
    FieldOrigin,
    FieldValue,
    LookupStatus,
    NewGroupRow,
    NewGroupRows,
    OriginSource,
    PicklistOption,
    SourceKey,
    SourceRecord,
    SystemValue,
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
    """One metadata object: business entity, field group or field.

    extra="allow" (0.9.12) so the attributes this model does not name stay readable: the
    reference does not print the businessEntity reply, so where a LookupField names its
    Reference 360 code list is learned from the raw keys (see lookup_from_node).
    """

    model_config = ConfigDict(extra="allow", populate_by_name=True)

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


# Attribute names that may carry a picklist's Reference 360 list. lookupCodeList / masterCodeList /
# beReferenceEntity are the names the reference prints for custom picklist fields (Customer 360
# field designator, pp. 148-150); the others are UNVERIFIED alternatives. Order = preference.
LOOKUP_ATTRS: tuple[str, ...] = (
    "lookupCodeList",
    "codeList",
    "lookup",
    "lookupEntity",
    "referenceEntity",
    "beReferenceEntity",
    "reference",
)
_LOOKUP_INNER = (
    "guid",
    "name",
    "codeList",
    "lookupCodeList",
    "entity",
    "object",
    "referenceEntity",
)


def _lookup_text(value: object) -> str | None:
    if isinstance(value, str) and value.strip():
        return value.strip()
    if isinstance(value, dict):
        for key in _LOOKUP_INNER:
            inner = value.get(key)
            if isinstance(inner, str) and inner.strip():
                return inner.strip()
    return None


def lookup_from_node(node: WireNode) -> FieldLookup:
    """What the raw metadata says about a picklist's list: code list and/or rdm entity."""
    extra: dict[str, object] = dict(node.model_extra or {})
    raw_keys = sorted({*extra, *node.model_fields_set})
    code_list: str | None = None
    rdm_entity: str | None = None
    found_in: str | None = None
    for attr in LOOKUP_ATTRS:
        text = _lookup_text(extra.get(attr))
        if text is None:
            continue
        if text.startswith("rdm."):
            rdm_entity = rdm_entity or text
        else:
            code_list = code_list or text
        found_in = found_in or attr
    if rdm_entity is None:  # any attribute pointing straight at an rdm entity
        for attr, value in extra.items():
            text = _lookup_text(value)
            if text is not None and text.startswith("rdm.value.be."):
                rdm_entity, found_in = text, found_in or attr
                break
    master = _lookup_text(extra.get("masterCodeList"))
    return FieldLookup(
        code_list=code_list,
        master_code_list=master,
        rdm_entity=rdm_entity,
        status=LookupStatus.DECLARED if (code_list or rdm_entity) else LookupStatus.NOT_FOUND,
        found_in=found_in,
        raw_keys=raw_keys,
    )


def _field(node: WireNode, parent_system: bool = False) -> EntityField:
    raw_type = node.type_name
    searchable = bool(node.searchable or (node.options and node.options.searchable))
    data_type = ECLASS_TYPES.get(raw_type, FieldDataType.UNKNOWN)
    picks = (FieldDataType.PICKLIST, FieldDataType.DEPENDENT_PICKLIST)
    return EntityField(
        lookup=lookup_from_node(node) if data_type in picks else None,
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
        system_values=system_values(meta_d),
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


# ---------------------------------------------------------------------------------------------
# 0.9.10 picklist options (observed) + source records (xref)
# ---------------------------------------------------------------------------------------------

_PICKS = (FieldDataType.PICKLIST, FieldDataType.DEPENDENT_PICKLIST)


def _option(raw: JsonValue) -> PicklistOption | None:
    if not isinstance(raw, dict):
        return None
    code = raw.get("Code", raw.get("code"))
    name = raw.get("Name", raw.get("name"))
    if not isinstance(code, (str, int)) or isinstance(code, bool):
        return None
    return PicklistOption(
        code=str(code), name=str(name) if isinstance(name, (str, int)) else str(code)
    )


def picklist_options(
    records: list[dict[str, JsonValue]], entity: BusinessEntity
) -> dict[tuple[str, str], list[PicklistOption]]:
    """Distinct {Code, Name} per picklist field as IDMC returned them in real records.

    The reference has no call that lists a picklist's allowed values; this is the only grounded
    source. Order: first seen. Root fields under key ("", field), group fields (group, field).
    """
    found: dict[tuple[str, str], dict[str, PicklistOption]] = {}

    def add(key: tuple[str, str], raw: JsonValue) -> None:
        option = _option(raw)
        if option is not None:
            found.setdefault(key, {}).setdefault(option.code, option)

    for record in records:
        by_local = {_local(k): v for k, v in record.items() if not k.startswith("_")}
        for f in entity.fields:
            if f.data_type in _PICKS:
                add(("", f.name), by_local.get(f.name))
        for group in entity.field_groups:
            cell = by_local.get(group.name)
            rows = cell if isinstance(cell, list) else [cell] if isinstance(cell, dict) else []
            for row in rows:
                if not isinstance(row, dict):
                    continue
                row_local = {_local(k): v for k, v in row.items()}
                for f in group.fields:
                    if f.data_type in _PICKS:
                        add((group.name, f.name), row_local.get(f.name))
    return {key: list(options.values()) for key, options in found.items()}


def _editable(raw: JsonValue, data_type: FieldDataType) -> FieldValue:
    """Like typed_value, but a picklist keeps its Code: the value an update sends back."""
    if isinstance(raw, dict) and data_type in _PICKS:
        option = _option(raw)
        return option.code if option else None
    return typed_value(raw, data_type)


class WireSourceKey(_Wire):
    source_pkey: str | int = Field(alias="sourcePKey")
    source_system: str = Field(alias="sourceSystem")


class WireMembers(_Wire):
    content: list[WireSourceKey] = Field(default_factory=list)


def source_members(body: object) -> list[SourceKey]:
    """Read Source Records by Master Record: {"content": [{sourcePKey, sourceSystem}]} (p. 71)."""
    data = as_json(body)
    parsed = WireMembers.model_validate(data if isinstance(data, dict) else {})
    return [
        SourceKey(source_system=m.source_system, source_pkey=str(m.source_pkey))
        for m in parsed.content
    ]


def source_record(
    body: object, entity: BusinessEntity, source_system: str, source_pkey: str
) -> SourceRecord:
    """Read Source Record reply (pp. 80-84): plain field names, groups as lists with _id, _meta."""
    data = as_json(body)
    raw: dict[str, JsonValue] = data if isinstance(data, dict) else {}
    meta = raw.get("_meta")
    meta_d: dict[str, JsonValue] = meta if isinstance(meta, dict) else {}
    by_local = {_local(k): v for k, v in raw.items() if not k.startswith("_")}
    values = {f.name: _editable(by_local.get(f.name), f.data_type) for f in entity.fields}
    groups: list[NewGroupRows] = []
    for group in entity.field_groups:
        cell = by_local.get(group.name)
        rows = cell if isinstance(cell, list) else [cell] if isinstance(cell, dict) else []
        groups.append(
            NewGroupRows(
                group=group.name,
                rows=[
                    NewGroupRow(
                        row_id=str(row["_id"]) if isinstance(row.get("_id"), (str, int)) else None,
                        values={
                            f.name: _editable(row.get(f.name), f.data_type) for f in group.fields
                        },
                    )
                    for row in rows
                    if isinstance(row, dict)
                ],
            )
        )
    states = meta_d.get("states")
    known = {f.name for f in entity.fields} | {g.name for g in entity.field_groups}
    updated_by = meta_d.get("updatedBy")
    xref_type = meta_d.get("xrefType")
    business_id = meta_d.get("businessId")
    return SourceRecord(
        entity=entity.name,
        source_system=str(meta_d.get("sourceSystem") or source_system),
        source_pkey=str(meta_d.get("sourcePrimaryKey") or source_pkey),
        business_id=str(business_id) if isinstance(business_id, (str, int)) else "",
        values=values,
        groups=groups,
        last_updated=_epoch_or_iso(meta_d.get("lastUpdateDate")),
        source_last_updated=_epoch_or_iso(meta_d.get("sourceLastUpdatedDate")),
        updated_by=str(updated_by) if isinstance(updated_by, (str, int)) else None,
        xref_type=str(xref_type) if isinstance(xref_type, str) else None,
        states=(
            {k: str(v) for k, v in states.items() if isinstance(v, (str, int))}
            if isinstance(states, dict)
            else {}
        ),
        unknown_keys=sorted(set(by_local) - known),
        system_values=system_values(meta_d),
    )


# Source (xref) _meta, Read Source Record GET response table + example (pp. 81-83).
DOCUMENTED_XREF_META_FIELDS: tuple[tuple[str, str, FieldDataType], ...] = (
    ("businessId", "Business ID (master record)", FieldDataType.STRING),
    ("businessEntity", "Business entity", FieldDataType.STRING),
    ("sourceSystem", "Source system", FieldDataType.STRING),
    ("sourcePrimaryKey", "Source primary key (sourcePKey)", FieldDataType.STRING),
    ("xrefType", "Xref type", FieldDataType.STRING),
    ("createdBy", "Created by", FieldDataType.STRING),
    ("creationDate", "Creation date", FieldDataType.DATETIME),
    ("updatedBy", "Updated by", FieldDataType.STRING),
    ("lastUpdateDate", "Last update date", FieldDataType.DATETIME),
    ("sourceLastUpdatedDate", "Source last updated date", FieldDataType.DATETIME),
    ("states.base", "State: base", FieldDataType.STRING),
    ("states.consolidation", "State: consolidation", FieldDataType.STRING),
    ("states.validation", "State: validation", FieldDataType.STRING),
    ("states.searchIndex", "State: search index", FieldDataType.STRING),
    ("populationName", "Population", FieldDataType.STRING),
)


def source_view(entity: BusinessEntity) -> BusinessEntity:
    """Metadata (S): same configured fields / groups (a source record carries the same model,
    pp. 82-87), the metadata's own system fields, and the documented xref _meta group instead of
    the master _meta group. Derived from the reference: no separate source metadata call."""
    xref_meta = FieldGroup(
        name="_meta",
        label="Source record _meta (xref)",
        cardinality=Cardinality.ONE,
        fields=[
            EntityField(
                name=name,
                label=label,
                data_type=kind,
                raw_type="documented",
                searchable=False,
                mandatory=False,
                origin=FieldOrigin.SYSTEM,
                origin_source=OriginSource.DOCUMENTED,
            )
            for name, label, kind in DOCUMENTED_XREF_META_FIELDS
        ],
        origin=FieldOrigin.SYSTEM,
        origin_source=OriginSource.DOCUMENTED,
    )
    others = [g for g in entity.system_field_groups if g.name != "_meta"]
    return entity.model_copy(update={"system_field_groups": [xref_meta, *others]})


# ---- 0.9.10 system values in the data (Vamsi 01:48 CST) ----------------------------------------


def system_values(meta: JsonValue) -> list[SystemValue]:
    """Every _meta value the reply carried, in reply order; nested objects dotted (states.base).
    A {code, name} object (populationName) shows its name. Lists are summarised. Never invented."""
    out: list[SystemValue] = []

    def walk(prefix: str, node: JsonValue) -> None:
        if isinstance(node, dict):
            option = _option(node)
            if option is not None and set(node) <= {"Code", "Name", "code", "name"}:
                out.append(SystemValue(name=prefix, value=option.name))
                return
            for key, value in node.items():
                walk(f"{prefix}.{key}" if prefix else key, value)
        elif isinstance(node, list):
            out.append(SystemValue(name=prefix, value=f"[{len(node)} items]"))
        elif prefix.lower().endswith("date") and (
            _is_number(node) or (isinstance(node, str) and node.isdigit())
        ):
            out.append(SystemValue(name=prefix, value=_epoch_or_iso(node)))
        elif node is None or isinstance(node, (str, int, float, bool)):
            out.append(SystemValue(name=prefix, value=node))

    if isinstance(meta, dict):
        walk("", meta)
    return out


def system_columns(rows: list[list[SystemValue]]) -> list[EntityField]:
    """Union of the system value names, first-seen order, as SYSTEM EntityFields."""
    seen: dict[str, EntityField] = {}
    for values in rows:
        for v in values:
            if v.name not in seen:
                kind = (
                    FieldDataType.DATETIME
                    if isinstance(v.value, datetime)
                    else (FieldDataType.STRING)
                )
                seen[v.name] = EntityField(
                    name=v.name,
                    label=v.name,
                    data_type=kind,
                    raw_type="_meta",
                    searchable=False,
                    mandatory=False,
                    origin=FieldOrigin.SYSTEM,
                    origin_source=OriginSource.METADATA,
                )
    return list(seen.values())


# ---- 0.9.12 Reference 360 picklist lists ------------------------------------------------------
# His org (read 2026-11-23 02:27 CST): rdm.value.be._ent_phonetype, label "RDM values of list
# Enterprise PhoneType", searchable with the Search API, fields Name / Code.

RDM_VALUE_PREFIX = "rdm.value.be."
RDM_LABEL_PREFIX = "RDM values of list "


def _norm(text: str) -> str:
    return "".join(ch for ch in text.lower() if ch.isalnum())


def _rdm_list_name(entity: BusinessEntitySummary) -> str:
    label = entity.label
    return label[len(RDM_LABEL_PREFIX) :] if label.startswith(RDM_LABEL_PREFIX) else label


def resolve_lookup(field: EntityField, rdm: list[BusinessEntitySummary]) -> FieldLookup | None:
    """Find the rdm.value.be.* entity holding this picklist's values. Never invents one.

    1. the metadata names an rdm entity -> kept (DECLARED);
    2. the metadata names a code list -> the rdm entity whose name or "RDM values of list <x>"
       label matches it (LABEL_MATCH);
    3. the metadata names nothing -> exactly one rdm entity whose list name ends with the
       field's label or name, letters only (GUESSED, shown as a guess);
    otherwise NOT_FOUND.
    """
    lookup = field.lookup
    if lookup is None:
        return None
    values = [e for e in rdm if e.name.startswith(RDM_VALUE_PREFIX)]
    if lookup.rdm_entity:
        return lookup
    if lookup.code_list:
        wanted = _norm(lookup.code_list)
        hit = next(
            (
                e
                for e in values
                if wanted in (_norm(e.name), _norm(e.name[len(RDM_VALUE_PREFIX) :]))
                or wanted == _norm(_rdm_list_name(e))
            ),
            None,
        )
        if hit is None:
            return lookup.model_copy(update={"status": LookupStatus.NOT_FOUND})
        return lookup.model_copy(
            update={"rdm_entity": hit.name, "status": LookupStatus.LABEL_MATCH}
        )
    keys = {k for k in (_norm(field.label), _norm(field.name)) if len(k) >= 4}
    hits = [
        e
        for e in values
        if any(_norm(_rdm_list_name(e)).endswith(k) or _norm(e.name).endswith(k) for k in keys)
    ]
    if len(hits) != 1:
        return lookup.model_copy(update={"status": LookupStatus.NOT_FOUND})
    return lookup.model_copy(update={"rdm_entity": hits[0].name, "status": LookupStatus.GUESSED})


def with_lookups(entity: BusinessEntity, rdm: list[BusinessEntitySummary]) -> BusinessEntity:
    def fix(f: EntityField) -> EntityField:
        found = resolve_lookup(f, rdm)
        return f if found is None else f.model_copy(update={"lookup": found})

    return entity.model_copy(
        update={
            "fields": [fix(f) for f in entity.fields],
            "field_groups": [
                g.model_copy(update={"fields": [fix(f) for f in g.fields]})
                for g in entity.field_groups
            ],
        }
    )


def rdm_options(records: list[dict[str, JsonValue]]) -> list[PicklistOption]:
    """{Code, Name} of each rdm value record (keys may be prefixed: last segment is used)."""
    out: dict[str, PicklistOption] = {}
    for record in records:
        by_last = {k.rsplit(".", 1)[-1]: v for k, v in record.items() if not k.startswith("_")}
        code = by_last.get("Code", by_last.get("code"))
        name = by_last.get("Name", by_last.get("name"))
        if isinstance(code, (str, int)) and not isinstance(code, bool) and str(code):
            text = str(name) if isinstance(name, (str, int)) and str(name) else str(code)
            out.setdefault(str(code), PicklistOption(code=str(code), name=text))
    return list(out.values())
