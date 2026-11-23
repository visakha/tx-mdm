"""0.9.12.2: field lengths - config (cntry_cd 3, ph_num exactly 10), derived for lookup codes.

Fake IDMC only, never his org.
"""

from collections.abc import Iterator

import httpx
import pytest
import respx
from fastapi.testclient import TestClient
from pydantic import ValidationError

from app.b360data import forms, scope, wire
from app.b360data.models import FieldLength, LengthOrigin
from app.b360data.service import B360DataService
from app.common.idmc_session import IdmcHttp
from app.dependencies import get_b360_data_service
from app.main import create_app
from dev import fake_idmc
from tests.conftest import MDM

FAKE = TestClient(fake_idmc.app)
BASE = "/api/b360/entities/zlv_guest"


@pytest.fixture
def api(idmc: respx.MockRouter, idmc_http: IdmcHttp) -> Iterator[TestClient]:
    def forward(request: httpx.Request) -> httpx.Response:
        reply = FAKE.request(
            request.method,
            request.url.path,
            params=dict(request.url.params),
            content=request.content,
            headers={"content-type": "application/json"},
        )
        return httpx.Response(reply.status_code, content=reply.content)

    idmc.route(url__startswith=MDM).mock(side_effect=forward)
    app = create_app()
    app.dependency_overrides[get_b360_data_service] = lambda: B360DataService(idmc_http, MDM)
    yield TestClient(app)


def _phone(meta: dict[str, object]) -> dict[str, dict[str, object]]:
    groups = meta["field_groups"]
    assert isinstance(groups, list)
    group = next(g for g in groups if g["name"] == "x_phone")
    return {f["name"]: f for f in group["fields"]}


def test_metadata_carries_config_and_derived_lengths(api: TestClient) -> None:
    phone = _phone(api.get(f"{BASE}/metadata").json())
    assert phone["cntry_cd"]["length"] == {
        "max": 3, "exact": False, "origin": "CONFIG", "metadata_max": None,
    }  # fmt: skip
    assert phone["ph_num"]["length"]["max"] == 10 and phone["ph_num"]["length"]["exact"] is True
    # longest live Code: "Contaminated" = 12 (the fake rdm Code field declares no length)
    assert phone["ph_typ"]["length"]["max"] == 12
    assert phone["ph_typ"]["length"]["origin"] == "LONGEST_CODE"


def test_generate_fills_root_and_groups_within_lengths(api: TestClient) -> None:
    rows = api.post(f"{BASE}/records/generate", json={"count": 8, "seed": 11}).json()
    phones = 0
    for row in rows["rows"]:
        assert row["values"]["first_name"]  # root fields in the same go
        group = next(g for g in row["groups"] if g["group"] == "x_phone")
        for r in group["rows"]:
            phones += 1
            assert 1 <= r["values"]["cntry_cd"] <= 999
            assert len(str(r["values"]["ph_num"])) == 10
            assert r["values"]["ph_typ"] in fake_idmc._RDM_PHONETYPE_CODES
    assert phones >= 8


def test_models_and_typed_spec_enforce_bounds(api: TestClient) -> None:
    spec = api.get("/openapi-typed.json").json()
    row = spec["components"]["schemas"]["Row_zlv_guest_x_phone"]["properties"]
    assert row["cntry_cd"]["maximum"] == 999 and row["cntry_cd"]["minimum"] == 0
    assert row["ph_num"]["minimum"] == 1_000_000_000 and row["ph_num"]["maximum"] == 9_999_999_999
    assert row["ph_typ"]["maxLength"] == 12
    schema = api.get(f"{BASE}/form-schema").json()
    group = next(g for g in schema["groups"] if g["name"] == "x_phone")
    assert next(f for f in group["fields"] if f["name"] == "ph_num")["length"]["max"] == 10


def test_group_model_rejects_too_long() -> None:
    entity = wire.business_entity_from_metadata(fake_idmc._B360_ENTITIES["zlv_guest"], "zlv_guest")
    entity = scope.apply_lengths(entity, scope.focus_config().entity_config("zlv_guest"))
    group = next(g for g in entity.field_groups if g.name == "x_phone")
    model = forms.group_model(entity, group)
    ok = {"cntry_cd": 1, "ph_num": 5125550101, "ph_typ": "Mobile", "no_mrkt_calls": False}
    model.model_validate(ok)
    with pytest.raises(ValidationError):
        model.model_validate({**ok, "ph_num": 512555010})  # 9 digits
    with pytest.raises(ValidationError):
        model.model_validate({**ok, "cntry_cd": 1000})


def test_config_larger_than_metadata_warns() -> None:
    raw = {
        "eClass": "x#//BusinessEntity",
        "guid": "e1",
        "name": "e1",
        "field": [{"eClass": "x#//TextField", "name": "code", "maxLength": 5}],
    }
    entity = wire.business_entity_from_metadata(raw, "e1")
    assert entity.fields[0].length == FieldLength(
        max=5, origin=LengthOrigin.METADATA, metadata_max=5
    )
    cfg = scope.FocusEntity(name="e1", lengths={"code": 8, "nope": 2})
    fixed = scope.apply_lengths(entity, cfg)
    assert fixed.fields[0].length is not None and fixed.fields[0].length.max == 8
    assert any("config 8 > metadata 5" in w for w in fixed.length_warnings)
    assert any("nope" in w for w in fixed.length_warnings)
