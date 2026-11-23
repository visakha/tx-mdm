"""0.9.8 Add records: sources gate, dynamic Pydantic form, Faker rows, sequential create."""

import json
from datetime import datetime
from pathlib import Path
from typing import Any

import pytest
import respx
from fastapi.testclient import TestClient

from app.b360data import forms, testdata
from app.b360data import scope as entity_scope
from app.b360data.models import FormInput
from app.b360data.scope import FocusConfigError, load_focus_config
from app.b360data.service import B360DataService
from app.b360data.wire import business_entity_from_metadata, source_system_ids
from app.common.idmc_session import IdmcHttp
from app.dependencies import get_b360_data_service
from app.main import create_app
from dev import fake_idmc
from tests.conftest import MDM

_CORE = "http://informatica.com/mdm/v2/Core#//"


def _text(name: str, mandatory: bool = False) -> dict[str, Any]:
    return {
        "eClass": _CORE + "TextField",
        "name": name,
        "label": {"en": name},
        "mandatory": mandatory,
    }


# Same root fields as Vamsi's live zlv_guest (verified 2026-11-23 01:00 CST), no field groups.
GUEST: dict[str, Any] = {
    "eClass": _CORE + "BusinessEntity",
    "guid": "zlv_guest",
    "label": {"en": "ZLV Guest"},
    "field": [
        _text("first_name", True),
        _text("clns_first_name", True),
        _text("last_name"),
        _text("clns_last_name"),
        _text("ffr_first_name"),
        _text("ffr_last_name"),
    ],
}
ENTITY = business_entity_from_metadata(GUEST, "zlv_guest")
CREATE = f"{MDM}/business-entity/public/api/v1/entity/zlv_guest"


def _client(idmc: respx.MockRouter, idmc_http: IdmcHttp) -> TestClient:
    idmc.get(f"{MDM}/metadata/api/v2/objects/businessEntity/zlv_guest").respond(200, json=GUEST)
    app = create_app()
    app.dependency_overrides[get_b360_data_service] = lambda: B360DataService(idmc_http, MDM)
    return TestClient(app)


def _rows(n: int) -> list[dict[str, Any]]:
    return [
        {"source_pkey": f"T-{i}", "values": {"first_name": f"A{i}", "clns_first_name": f"A{i}"}}
        for i in range(n)
    ]


def test_committed_toml_sources_are_lowercase_exact() -> None:
    sources = load_focus_config(entity_scope.DEFAULT_FILE).sources
    assert sources.allowed == ["zlv_ttf", "zlv_eci", "c360.default.system"]
    assert sources.default_source() == "zlv_ttf"
    assert not sources.is_allowed("ZLV_TTF")  # case-sensitive on purpose


def test_toml_default_must_be_allowed(tmp_path: Path) -> None:
    bad = tmp_path / "b.toml"
    bad.write_text('[sources]\nallowed = ["a"]\ndefault = "b"\n', encoding="ascii")
    with pytest.raises(FocusConfigError, match="default"):
        load_focus_config(bad)


def test_dynamic_model_types_and_required() -> None:
    schema = forms.form_schema(ENTITY)
    assert schema.model_name == "Record_zlv_guest"
    assert [f.name for f in schema.fields if f.required] == ["first_name", "clns_first_name"]
    assert {f.input for f in schema.fields} == {FormInput.TEXT}
    assert json.loads(schema.json_schema_text)["required"] == ["first_name", "clns_first_name"]
    with pytest.raises(forms.RecordInvalidError):
        forms.validate_values(ENTITY, {"first_name": "A"}, 0)
    with pytest.raises(forms.RecordInvalidError):
        forms.validate_values(ENTITY, {"first_name": "A", "clns_first_name": "A", "x": "1"}, 0)


def test_faker_rows_fit_and_derive() -> None:
    rows = testdata.generate(ENTITY, 3, 7, datetime(2026, 11, 23, 1, 15, 0))
    assert [r.source_pkey for r in rows.rows] == [
        "TXMDM-20261123011500-1",
        "TXMDM-20261123011500-2",
        "TXMDM-20261123011500-3",
    ]
    for row in rows.rows:
        first = str(row.values["first_name"])
        assert row.values["clns_first_name"] == "".join(c for c in first if c.isalnum()).upper()
        assert row.values["ffr_first_name"] == "".join(c for c in first if c.isalnum()).lower()


def test_generate_endpoint_caps_at_100(idmc: respx.MockRouter, idmc_http: IdmcHttp) -> None:
    client = _client(idmc, idmc_http)
    url = "/api/b360/entities/zlv_guest/records/generate"
    assert len(client.post(url, json={"count": 5}).json()["rows"]) == 5
    assert client.post(url, json={"count": 101}).status_code == 422
    assert client.post(url, json={"count": 0}).status_code == 422


def test_source_systems_discovered_and_gated(idmc: respx.MockRouter, idmc_http: IdmcHttp) -> None:
    idmc.get(f"{MDM}/metadata/api/v2/objects/sourceSystem").respond(
        200, json=fake_idmc.source_systems()
    )
    body = _client(idmc, idmc_http).get("/api/b360/source-systems").json()
    assert body["discovery"] == "OK"
    assert body["default"] == "zlv_ttf"
    assert body["not_allowed"] == ["salesforce"]


def test_source_systems_not_available(idmc: respx.MockRouter, idmc_http: IdmcHttp) -> None:
    idmc.get(f"{MDM}/metadata/api/v2/objects/sourceSystem").respond(404)
    body = _client(idmc, idmc_http).get("/api/b360/source-systems").json()
    assert body["discovery"] == "NOT_AVAILABLE"
    assert body["allowed"] == ["zlv_ttf", "zlv_eci", "c360.default.system"]


def test_source_ids_parse_any_depth() -> None:
    assert source_system_ids({"content": [{"eClass": "x#//SourceSystem", "name": "n"}]}) == ["n"]


def test_create_refuses_source_not_allowed(idmc: respx.MockRouter, idmc_http: IdmcHttp) -> None:
    route = idmc.post(CREATE).respond(200, json={"businessId": "1"})
    client = _client(idmc, idmc_http)
    for bad in ("ZLV_TTF", "salesforce"):
        r = client.post(
            "/api/b360/entities/zlv_guest/records",
            json={"source_system": bad, "records": _rows(1)},
        )
        assert r.status_code == 400
    assert route.call_count == 0


def test_create_validates_before_sending(idmc: respx.MockRouter, idmc_http: IdmcHttp) -> None:
    route = idmc.post(CREATE).respond(200, json={"businessId": "1"})
    client = _client(idmc, idmc_http)
    rows = _rows(2)
    rows[1]["values"].pop("clns_first_name")
    url = "/api/b360/entities/zlv_guest/records"
    assert client.post(url, json={"source_system": "zlv_ttf", "records": rows}).status_code == 422
    assert (
        client.post(url, json={"source_system": "zlv_ttf", "records": _rows(101)}).status_code
        == 422
    )
    dup = _rows(2)
    dup[1]["source_pkey"] = "T-0"
    assert client.post(url, json={"source_system": "zlv_ttf", "records": dup}).status_code == 422
    assert route.call_count == 0


def test_create_sequential_and_typed(idmc: respx.MockRouter, idmc_http: IdmcHttp) -> None:
    replies = iter(
        [
            {"approvalRequired": False, "id": "9", "businessId": "B1"},
            {"approvalRequired": True, "id": "10", "businessId": "B2"},
        ]
    )
    route = idmc.post(CREATE).mock(
        side_effect=lambda req: respx.MockResponse(200, json=next(replies))
    )
    body = (
        _client(idmc, idmc_http)
        .post(
            "/api/b360/entities/zlv_guest/records",
            json={"source_system": "zlv_ttf", "records": _rows(2)},
        )
        .json()
    )
    assert body["created"] == 2
    assert [r["business_id"] for r in body["results"]] == ["B1", "B2"]
    assert [r["approval_required"] for r in body["results"]] == [False, True]
    first = route.calls[0].request
    assert first.url.params["sourceSystem"] == "zlv_ttf"
    assert first.url.params["sourcePKey"] == "T-0"
    assert json.loads(first.content) == {"first_name": "A0", "clns_first_name": "A0"}


def test_create_stops_on_429_and_keeps_going_on_400(
    idmc: respx.MockRouter, idmc_http: IdmcHttp
) -> None:
    codes = iter([200, 400, 429, 200])
    route = idmc.post(CREATE).mock(
        side_effect=lambda req: respx.MockResponse(next(codes), json={"businessId": "B"})
    )
    body = (
        _client(idmc, idmc_http)
        .post(
            "/api/b360/entities/zlv_guest/records",
            json={"source_system": "zlv_ttf", "records": _rows(5)},
        )
        .json()
    )
    assert [r["outcome"] for r in body["results"]] == [
        "CREATED",
        "FAILED",
        "NOT_SENT",
        "NOT_SENT",
        "NOT_SENT",
    ]
    assert "429" in body["stopped_reason"]
    assert route.call_count == 3  # never retried, nothing after the 429


def test_create_stops_on_403(idmc: respx.MockRouter, idmc_http: IdmcHttp) -> None:
    route = idmc.post(CREATE).respond(403, json={"message": "no"})
    body = (
        _client(idmc, idmc_http)
        .post(
            "/api/b360/entities/zlv_guest/records",
            json={"source_system": "zlv_eci", "records": _rows(3)},
        )
        .json()
    )
    assert [r["outcome"] for r in body["results"]] == ["FAILED", "NOT_SENT", "NOT_SENT"]
    assert route.call_count == 1
