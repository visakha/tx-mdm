"""0.9.14 (Vamsi 03:15 CST): /openapi-idmc.json - ONLY the real Informatica IDMC endpoints this
backend calls (not our /api routes), built from the typed registry in idmc_registry.py.

Path keys are absolute from each host root (platform paths under /saas), each path item names its
own server (login / platform / pod / MDM host). One operation per registry row.
"""

from pydantic import BaseModel
from pydantic.json_schema import models_json_schema

from app.common.idmc_registry import HOSTS, IDMC_CALLS, DocStatus, IdmcCallSpec, SessionHeader
from app.version import VERSION

JsonObj = dict[str, object]

_SCHEME_NAME: dict[SessionHeader, str] = {
    SessionHeader.IDS: "IDS-SESSION-ID",
    SessionHeader.INFA: "INFA-SESSION-ID",
    SessionHeader.IC: "icSessionId",
}


def _models() -> list[type[BaseModel]]:
    seen: list[type[BaseModel]] = []
    for spec in IDMC_CALLS:
        for model in (spec.request_model, spec.response_model):
            if model is not None and model not in seen:
                seen.append(model)
    return seen


def _ref(model: type[BaseModel]) -> JsonObj:
    return {"$ref": f"#/components/schemas/{model.__name__}"}


def _operation(spec: IdmcCallSpec) -> JsonObj:
    status = "UNVERIFIED-DOC" if spec.status == DocStatus.UNVERIFIED_DOC else spec.status.value
    words = [
        spec.summary + ".",
        f"Doc source ({status}): {spec.doc}.",
        f"Host: {HOSTS[spec.host].words}.",
        f"Auth header: {spec.auth.value if spec.auth else 'none (this call creates the session)'}.",
        f"Registry id: {spec.id} (same id in Copy IDMC curl).",
    ]
    if spec.notes:
        words.append(spec.notes)
    op: JsonObj = {
        "operationId": spec.id,
        "summary": spec.summary,
        "description": " ".join(words),
        "tags": [spec.area.value],
        "x-doc-status": status,
        "x-doc-source": spec.doc,
        "x-writes": spec.writes,
    }
    params: list[JsonObj] = [
        {"name": n, "in": "path", "required": True, "schema": {"type": "string"}}
        for n in spec.path_params
    ]
    params += [
        {
            "name": q.name,
            "in": "query",
            "required": q.required,
            "description": q.description,
            "schema": {"type": "string"},
        }
        for q in spec.query
    ]
    params += [
        {"name": k, "in": "header", "required": True, "schema": {"type": "string", "const": v}}
        for k, v in spec.extra_headers
    ]
    if params:
        op["parameters"] = params
    if spec.auth is not None:
        op["security"] = [{_SCHEME_NAME[spec.auth]: []}]
    else:
        op["security"] = []
    if spec.request_model is not None:
        body = _ref(spec.request_model)
        schema: JsonObj = {"type": "array", "items": body} if spec.request_array else body
        op["requestBody"] = {"required": True, "content": {"application/json": {"schema": schema}}}
    elif spec.writes:
        op["requestBody"] = {
            "required": False,
            "content": {"application/json": {"schema": {"type": "object"}}},
            "description": "Shape not modelled in tx-mdm; see the doc source.",
        }
    ok: JsonObj = {"description": "OK"}
    if spec.response_model is not None:
        body_schema = _ref(spec.response_model)
        if spec.response_array:
            body_schema = {"type": "array", "items": body_schema}
        ok["content"] = {"application/json": {"schema": body_schema}}
    else:
        ok["description"] = "OK (shape not modelled in tx-mdm; see the doc source)"
    op["responses"] = {
        "200": ok,
        "401": {"description": "Session expired: tx-mdm logs in again and retries once"},
        "429": {"description": "Rate limited: tx-mdm stops, never retries"},
    }
    return op


def build() -> JsonObj:
    _, defs = models_json_schema(
        [(m, "validation") for m in _models()], ref_template="#/components/schemas/{model}"
    )
    schemas = defs.get("$defs", {})
    paths: dict[str, JsonObj] = {}
    for spec in IDMC_CALLS:
        item = paths.setdefault(spec.doc_path(), {"servers": [{"url": HOSTS[spec.host].server}]})
        item[spec.method.value.lower()] = _operation(spec)
    return {
        "openapi": "3.1.0",
        "info": {
            "title": "IDMC calls made by tx-mdm",
            "version": VERSION,
            "description": (
                "Only the Informatica IDMC endpoints this backend actually calls (not the tx-mdm "
                "/api routes - those are in /openapi.json and /openapi-typed.json). Built from "
                "backend/app/common/idmc_registry.py, the same registry Copy IDMC curl uses. "
                "Servers are his org's hosts; the platform host comes from the login reply "
                "(baseApiUrl). Shapes are only as far as tx-mdm models them. UNVERIFIED-DOC = "
                "not in any Informatica document we found."
            ),
        },
        "servers": [{"url": HOSTS[spec.host].server} for spec in IDMC_CALLS[:1]],
        "paths": paths,
        "components": {
            "schemas": schemas,
            "securitySchemes": {
                name: {"type": "apiKey", "in": "header", "name": name}
                for name in _SCHEME_NAME.values()
            },
        },
    }
