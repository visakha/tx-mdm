"""0.9.12: /openapi-typed.json - the app's OpenAPI spec plus concrete per-entity schemas.

Vamsi (voice, 2026-11-23 02:32 CST): /openapi.json only shows generic shapes (BusinessEntity,
EntityField, EntityRecord); he wants a "more concrete" typed contract per business entity.

For each focus entity in b360_entities.toml this adds, from the live metadata (same service and
5-minute cache, read-only):
  Record_<e>          the flat record: root fields with real JSON types, one array per field group
                      (items Row_<e>_<group>), system fields and _meta readOnly, x-origin SYSTEM
  Values_<e>          root fields only (NewRecord.values / EntityRecord.values)
  Row_<e>_<group>     one row of a field group
  NewRecord_<e>, CreateRequest_<e>, EntityRecord_<e>, RecordPage_<e>
and concrete paths /api/b360/entities/<e>/records (GET, POST) that reference them.
Picklists are an enum of real Codes (Reference 360 first, else observed), else a plain string
with a note. All fields are shown (the TOML field visibility list does not apply here).
A failed metadata read never fails the spec: it is listed under x-typed-warnings.
"""

import copy

from pydantic import JsonValue

from app.b360data import forms
from app.b360data.models import (
    BusinessEntity,
    EntityField,
    FieldDataType,
    FieldGroup,
    FieldOrigin,
    PicklistSource,
)
from app.common import naming

JsonObj = dict[str, JsonValue]

_PICKS = (FieldDataType.PICKLIST, FieldDataType.DEPENDENT_PICKLIST)


def schema_key(entity: str) -> str:
    return naming.apply(naming.Transform.SCHEMA_KEY, entity)


def _ref(name: str) -> JsonObj:
    return {"$ref": f"#/components/schemas/{name}"}


def field_schema(f: EntityField, lists: forms.Picklists, group: str = "") -> JsonObj:
    """JSON schema of one field's value, as this backend's API carries it."""
    out: JsonObj
    match f.data_type:
        case FieldDataType.STRING:
            out = {"type": "string"}
        case FieldDataType.INTEGER:
            out = {"type": "integer"}
        case FieldDataType.DOUBLE:
            out = {"type": "number"}
        case FieldDataType.BOOLEAN:
            out = {"type": "boolean"}
        case FieldDataType.DATE:
            out = {"type": "string", "format": "date"}
        case FieldDataType.DATETIME:
            out = {"type": "string", "format": "date-time"}
        case FieldDataType.PICKLIST | FieldDataType.DEPENDENT_PICKLIST:
            out = _picklist(f, lists, group)
        case _:
            out = {"description": f"type not known ({f.raw_type})"}
    limits = forms.bounds(f)
    for key, number in (
        ("maxLength", limits.max_length),
        ("minLength", limits.min_length),
        ("maximum", limits.le),
        ("minimum", limits.ge),
    ):
        if number is not None:
            out[key] = number
    if f.length is not None:
        out["x-length-origin"] = f.length.origin.value
    out["title"] = f.label
    out["x-idmc-type"] = f.raw_type
    if f.origin is FieldOrigin.SYSTEM:
        out["readOnly"] = True
        out["x-origin"] = "SYSTEM"
    return out


def _picklist(f: EntityField, lists: forms.Picklists, group: str) -> JsonObj:
    codes = [o.code for o in lists.options.get((group, f.name), [])]
    source = lists.sources.get((group, f.name), PicklistSource.NONE)
    lookup = f.lookup
    out: JsonObj = {"type": "string", "x-picklist-source": source.value}
    if lookup is not None and lookup.rdm_entity:
        out["x-reference-360"] = lookup.rdm_entity
    if lookup is not None and lookup.code_list:
        out["x-code-list"] = lookup.code_list
    if codes:
        out["enum"] = list(codes)
        out["description"] = f"Picklist Code ({source.value})."
    else:
        out["description"] = "Picklist Code. No known values (none from Reference 360 or records)."
    return out


def _object(fields: list[EntityField], lists: forms.Picklists, group: str = "") -> JsonObj:
    props: JsonObj = {f.name: field_schema(f, lists, group) for f in fields}
    required: list[JsonValue] = [f.name for f in fields if f.mandatory]
    out: JsonObj = {"type": "object", "properties": props, "additionalProperties": False}
    if required:
        out["required"] = required
    return out


def entity_schemas(entity: BusinessEntity, lists: forms.Picklists) -> JsonObj:
    key = schema_key(entity.name)
    schemas: JsonObj = {}
    values = _object(entity.fields, lists)
    values["title"] = f"Values_{key}"
    values["description"] = f"Root fields of {entity.name} ({entity.label})."
    schemas[f"Values_{key}"] = values

    def row(g: FieldGroup) -> str:
        name = f"Row_{key}_{schema_key(g.name)}"
        body = _object(g.fields, lists, g.name)
        body["title"] = name
        body["description"] = f"One row of field group {g.name} ({g.label}, {g.cardinality})."
        schemas[name] = body
        return name

    group_rows = {g.name: row(g) for g in entity.field_groups}
    record_props: JsonObj = {f.name: field_schema(f, lists) for f in entity.fields}
    for g in entity.field_groups:
        record_props[g.name] = {
            "type": "array",
            "title": g.label,
            "items": _ref(group_rows[g.name]),
            **({"maxItems": 1} if g.cardinality.value == "ONE" else {}),
        }
    for f in entity.system_fields:
        record_props[f.name] = {**field_schema(f, lists), "readOnly": True, "x-origin": "SYSTEM"}
    for g in entity.system_field_groups:
        record_props[g.name] = {
            "type": "object",
            "title": g.label,
            "readOnly": True,
            "x-origin": "SYSTEM",
            "properties": {
                f.name: {**field_schema(f, lists), "readOnly": True, "x-origin": "SYSTEM"}
                for f in g.fields
            },
        }
    required: list[JsonValue] = [f.name for f in entity.fields if f.mandatory]
    record: JsonObj = {
        "type": "object",
        "title": f"Record_{key}",
        "description": f"One {entity.name} record ({entity.label}): every field, as typed by "
        "the B360 metadata. Field groups are arrays of rows; SYSTEM parts are readOnly.",
        "properties": record_props,
    }
    if required:
        record["required"] = required
    schemas[f"Record_{key}"] = record

    group_items: list[JsonValue] = [
        {
            "type": "object",
            "required": ["group", "rows"],
            "properties": {
                "group": {"type": "string", "enum": [g.name]},
                "rows": {
                    "type": "array",
                    "items": {
                        "type": "object",
                        "required": ["values"],
                        "properties": {
                            "row_id": {"type": ["string", "null"]},
                            "values": _ref(group_rows[g.name]),
                        },
                    },
                },
            },
        }
        for g in entity.field_groups
    ]
    groups_schema: JsonObj = {"type": "array", "items": {"oneOf": group_items}}
    schemas[f"NewRecord_{key}"] = {
        "type": "object",
        "title": f"NewRecord_{key}",
        "required": ["values"],
        "properties": {
            "source_pkey": {"type": ["string", "null"], "maxLength": 255},
            "values": _ref(f"Values_{key}"),
            "groups": groups_schema,
        },
    }
    schemas[f"CreateRequest_{key}"] = {
        "type": "object",
        "title": f"CreateRequest_{key}",
        "required": ["source_system", "records"],
        "properties": {
            "source_system": {"type": "string", "minLength": 1, "maxLength": 128},
            "records": {
                "type": "array",
                "minItems": 1,
                "maxItems": 100,
                "items": _ref(f"NewRecord_{key}"),
            },
        },
    }
    schemas[f"EntityRecord_{key}"] = {
        "allOf": [_ref("EntityRecord")],
        "title": f"EntityRecord_{key}",
        "properties": {"values": _ref(f"Values_{key}")},
    }
    schemas[f"RecordPage_{key}"] = {
        "allOf": [_ref("RecordPage")],
        "title": f"RecordPage_{key}",
        "properties": {"records": {"type": "array", "items": _ref(f"EntityRecord_{key}")}},
    }
    return schemas


def _json_body(name: str) -> JsonObj:
    return {"content": {"application/json": {"schema": _ref(name)}}}


def entity_paths(entity: BusinessEntity) -> JsonObj:
    key = schema_key(entity.name)
    tag = f"b360 typed: {entity.name}"
    return {
        f"/api/b360/entities/{entity.name}/records": {
            "get": {
                "tags": [tag],
                "operationId": f"listRecords_{key}",
                "summary": f"{entity.label}: one page of records (typed)",
                "description": "Same route as /api/b360/entities/{name}/records with "
                f"name={entity.name}; values typed as Values_{key}.",
                "responses": {"200": {"description": "OK", **_json_body(f"RecordPage_{key}")}},
            },
            "post": {
                "tags": [tag],
                "operationId": f"createRecords_{key}",
                "summary": f"{entity.label}: create master records (typed)",
                "description": "Same route as POST /api/b360/entities/{name}/records with "
                f"name={entity.name}. Each record's values follow Values_{key}; Record_{key} "
                "shows the whole record as one flat object.",
                "requestBody": {"required": True, **_json_body(f"CreateRequest_{key}")},
                "responses": {"200": {"description": "OK", **_json_body("CreateResponse")}},
            },
        }
    }


def build(
    base: JsonObj,
    entities: list[tuple[BusinessEntity, forms.Picklists]],
    warnings: list[str],
) -> JsonObj:
    spec = copy.deepcopy(base)
    info = spec.get("info")
    if isinstance(info, dict):
        info["title"] = f"{info.get('title', 'API')} (typed per business entity)"
    components = spec.setdefault("components", {})
    assert isinstance(components, dict)
    schemas = components.setdefault("schemas", {})
    paths = spec.setdefault("paths", {})
    assert isinstance(schemas, dict) and isinstance(paths, dict)
    for entity, lists in entities:
        schemas.update(entity_schemas(entity, lists))
        paths.update(entity_paths(entity))
    spec["x-typed-entities"] = [e.name for e, _ in entities]
    spec["x-typed-warnings"] = list(warnings)
    return spec
