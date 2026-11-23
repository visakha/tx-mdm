"""0.9.10: source (xref) records, Edit records (S), field groups in Generate / form / create.

Every MDM call is forwarded to the fake IDMC app (dev/fake_idmc.py). Never his org.
"""

import json
from collections.abc import Iterator

import httpx
import pytest
import respx
from fastapi.testclient import TestClient

from app.b360data import forms
from app.b360data.models import NewGroupRow, NewGroupRows, NewRecord, PatchOperation
from app.b360data.service import B360DataService
from app.b360data.wire import business_entity_from_metadata
from app.common.idmc_session import IdmcHttp
from app.dependencies import get_b360_data_service
from app.main import create_app
from dev import fake_idmc
from tests.conftest import MDM

FAKE = TestClient(fake_idmc.app)
BASE = "/api/b360/entities/zlv_guest"
BID5 = "300000000000000000000000005"


@pytest.fixture
def api(idmc: respx.MockRouter, idmc_http: IdmcHttp) -> Iterator[tuple[TestClient, list[str]]]:
    calls: list[str] = []

    def forward(request: httpx.Request) -> httpx.Response:
        calls.append(f"{request.method} {request.url.path}")
        reply = FAKE.request(
            request.method,
            request.url.path,
            params=dict(request.url.params),
            content=request.content,
            headers={"content-type": "application/json"},
        )
        return httpx.Response(reply.status_code, content=reply.content)

    idmc.route(url__startswith=MDM).mock(side_effect=forward)
    fake_idmc._XREF_EDITS.clear()
    fake_idmc.PATCHES.clear()
    fake_idmc._CREATED.clear()
    app = create_app()
    app.dependency_overrides[get_b360_data_service] = lambda: B360DataService(idmc_http, MDM)
    yield TestClient(app), calls


def test_form_schema_has_groups_and_reference_360_picklist(
    api: tuple[TestClient, list[str]],
) -> None:
    client, calls = api
    schema = client.get(f"{BASE}/form-schema").json()
    assert schema["skipped_groups"] == []
    phone = next(g for g in schema["groups"] if g["name"] == "x_phone")
    assert phone["cardinality"] == "MANY"
    typ = next(f for f in phone["fields"] if f["name"] == "ph_typ")
    # 0.9.12: from the Reference 360 entity the metadata points to, not from records
    assert [o["code"] for o in typ["options"]] == fake_idmc._RDM_PHONETYPE_CODES
    assert typ["options_source"] == "REFERENCE_360"
    assert next(f for f in phone["fields"] if f["name"] == "no_mrkt_calls")["input"] == "CHECKBOX"
    assert any(c.startswith("POST /search") for c in calls)


def test_picklist_without_observations_is_left_empty() -> None:
    entity = business_entity_from_metadata(fake_idmc._B360_ENTITIES["zlv_guest"], "zlv_guest")
    schema = forms.form_schema(entity)
    phone = next(g for g in schema.groups if g.name == "x_phone")
    typ = next(f for f in phone.fields if f.name == "ph_typ")
    assert typ.options == [] and typ.options_source is not None
    assert typ.options_source.value == "NONE"


def test_generate_fills_every_group(api: tuple[TestClient, list[str]]) -> None:
    client, _ = api
    rows = client.post(f"{BASE}/records/generate", json={"count": 6, "seed": 7}).json()
    for row in rows["rows"]:
        phone = next(g for g in row["groups"] if g["group"] == "x_phone")
        assert 1 <= len(phone["rows"]) <= 2
        for r in phone["rows"]:
            assert r["values"]["cntry_cd"] == 1
            assert len(str(r["values"]["ph_num"])) == 10
            assert r["values"]["ph_typ"] in fake_idmc._RDM_PHONETYPE_CODES
            assert isinstance(r["values"]["no_mrkt_calls"], bool)
        assert len(next(g for g in row["groups"] if g["group"] == "Stay")["rows"]) in (1, 2)
    assert any(r["field"] == "x_phone.ph_typ" for r in rows["rules"])


def test_create_sends_groups_in_reference_shape(api: tuple[TestClient, list[str]]) -> None:
    client, _ = api
    record = {
        "source_pkey": "T-1",
        "values": {"guestId": "G1", "first_name": "Ann"},
        "groups": [
            {
                "group": "x_phone",
                "rows": [{"values": {"cntry_cd": 1, "ph_num": 5125550101, "ph_typ": "MOB"}}],
            }
        ],
    }
    reply = client.post(
        f"{BASE}/records", json={"source_system": "zlv_ttf", "records": [record]}
    ).json()
    assert reply["created"] == 1
    stored = fake_idmc._CREATED["zlv_guest"][0]["zlv_guest.x_phone"]
    assert stored[0]["ph_typ"] == {"Code": "MOB"}
    assert len(stored[0]["_id"]) == 32


def test_bad_group_row_is_422_nothing_sent(api: tuple[TestClient, list[str]]) -> None:
    client, calls = api
    record = {
        "values": {"guestId": "G1"},
        "groups": [{"group": "x_phone", "rows": [{"values": {"ph_num": "not-a-number"}}]}],
    }
    reply = client.post(f"{BASE}/records", json={"source_system": "zlv_ttf", "records": [record]})
    assert reply.status_code == 422
    assert not any(c.startswith("POST /business-entity") for c in calls)


def test_master_sources_and_source_record(api: tuple[TestClient, list[str]]) -> None:
    client, calls = api
    page = client.get(f"{BASE}/records/{BID5}/sources").json()
    assert [(m["source_system"], m["source_pkey"]) for m in page["members"]] == [
        ("zlv_ttf", "TTF-05"),
        ("zlv_eci", "ECI-05"),
    ]
    first = page["records"][0]
    assert first["business_id"] == BID5 and first["xref_type"] == "DATA"
    assert first["values"]["first_name"] == "Carla5"
    phone = next(g for g in first["groups"] if g["group"] == "x_phone")
    assert phone["rows"][0]["row_id"] == "ph005"
    assert phone["rows"][0]["values"]["ph_typ"] == "MOB"  # the Code, editable
    assert first["states"]["consolidation"] == "CONSOLIDATED"
    assert any("/entity-member/zlv_guest/" in c for c in calls)
    one = client.get(f"{BASE}/sources/zlv_eci/ECI-05").json()
    assert one["source_pkey"] == "ECI-05"
    assert client.get(f"{BASE}/sources/zlv_eci/NOPE").status_code == 404
    assert client.get(f"{BASE}/records/NOPE/sources").json()["members"] == []


def test_source_metadata_has_xref_system_fields(api: tuple[TestClient, list[str]]) -> None:
    client, _ = api
    meta = client.get(f"{BASE}/source-metadata").json()
    group = next(g for g in meta["system_field_groups"] if g["name"] == "_meta")
    names = {f["name"] for f in group["fields"]}
    assert {"sourceSystem", "sourcePrimaryKey", "xrefType", "sourceLastUpdatedDate"} <= names
    assert group["origin"] == "SYSTEM" and group["origin_source"] == "DOCUMENTED"
    assert [f["name"] for f in meta["fields"]][:2] == ["guestId", "fullName"]


def _edit(client: TestClient) -> tuple[dict[str, object], dict[str, object]]:
    loaded = client.get(f"{BASE}/sources/zlv_ttf/TTF-05").json()
    original = {"values": loaded["values"], "groups": loaded["groups"]}
    updated = json.loads(json.dumps(original))
    updated["values"]["first_name"] = "Carlota"
    phone = next(g for g in updated["groups"] if g["group"] == "x_phone")
    phone["rows"][0]["values"]["ph_num"] = 5125559999
    phone["rows"].append({"values": {"cntry_cd": 1, "ph_num": 5125550000, "ph_typ": "HOME"}})
    return original, updated


def test_update_dry_run_sends_nothing(api: tuple[TestClient, list[str]]) -> None:
    client, calls = api
    original, updated = _edit(client)
    url = f"{BASE}/sources/zlv_ttf/TTF-05/update"
    reply = client.post(url, json={"original": original, "updated": updated}).json()
    assert reply["sent"] is False
    ops = {(o["op"], o["path"]): o for o in reply["ops"]}
    assert ops[("replace", "first_name")]["old"] == "Carla5"
    assert ops[("replace", "first_name")]["new"] == "Carlota"
    assert ops[("replace", "first_name")]["verified"] is True
    assert ops[("replace", "x_phone[ph005].ph_num")]["value"] == 5125559999
    assert ops[("add", "x_phone")]["verified"] is False
    assert len(reply["ops"]) == 3
    assert fake_idmc.PATCHES == []
    assert not any(c.startswith("PATCH") for c in calls)


def test_update_sends_one_patch(api: tuple[TestClient, list[str]]) -> None:
    client, calls = api
    original, updated = _edit(client)
    url = f"{BASE}/sources/zlv_ttf/TTF-05/update"
    body = {"original": original, "updated": updated, "dry_run": False}
    reply = client.post(url, json=body).json()
    assert reply["sent"] is True and reply["approval_required"] is False
    assert sum(1 for c in calls if c.startswith("PATCH")) == 1
    sent = fake_idmc.PATCHES[0]
    assert {"op": "replace", "path": "first_name", "value": "Carlota"} in sent
    added = next(o for o in sent if o["op"] == "add")
    assert added["value"][0]["ph_typ"] == {"Code": "HOME"} and "old" not in added
    after = client.get(f"{BASE}/sources/zlv_ttf/TTF-05").json()
    assert after["values"]["first_name"] == "Carlota"
    assert len(next(g for g in after["groups"] if g["group"] == "x_phone")["rows"]) == 2


def test_update_refuses_not_allowed_source(api: tuple[TestClient, list[str]]) -> None:
    client, calls = api
    body = {"original": {"values": {}}, "updated": {"values": {}}, "dry_run": False}
    reply = client.post(f"{BASE}/sources/salesforce/X1/update", json=body)
    assert reply.status_code == 400
    assert not any(c.startswith("PATCH") for c in calls)


def test_update_429_passed_through_once(api: tuple[TestClient, list[str]]) -> None:
    client, calls = api
    body = {
        "original": {"values": {"first_name": "A"}},
        "updated": {"values": {"first_name": "B"}},
        "dry_run": False,
    }
    reply = client.post(f"{BASE}/sources/zlv_ttf/RATE429/update", json=body)
    assert reply.status_code == 429
    assert sum(1 for c in calls if c.startswith("PATCH")) == 1


def test_patch_ops_remove_row_and_field_unverified() -> None:
    entity = business_entity_from_metadata(fake_idmc._B360_ENTITIES["zlv_guest"], "zlv_guest")
    original = NewRecord(
        values={"first_name": "A", "last_name": "B"},
        groups=[
            NewGroupRows(
                group="x_phone", rows=[NewGroupRow(row_id="r1", values={"ph_num": 5125550000})]
            )
        ],
    )
    ops = forms.patch_ops(
        entity, original, {"first_name": "A"}, [NewGroupRows(group="x_phone", rows=[])]
    )
    assert [(o.op, o.path, o.verified) for o in ops] == [
        (PatchOperation.REMOVE, "last_name", False),
        (PatchOperation.REMOVE, "x_phone[r1]", False),
    ]


def test_system_values_only_what_the_reply_carried(api: tuple[TestClient, list[str]]) -> None:
    client, _ = api
    page = client.get("/api/b360/entities/zlv_guest/records").json()
    names = [c["name"] for c in page["system_columns"]]
    assert names == ["businessId", "businessEntity", "status", "lastUpdateDate", "updatedBy"]
    assert all(c["origin"] == "SYSTEM" for c in page["system_columns"])
    first = {v["name"]: v["value"] for v in page["records"][0]["system_values"]}
    assert first["lastUpdateDate"].startswith("2026-11-01T12:00:00")
    sources = client.get(f"{BASE}/records/{BID5}/sources").json()
    xref = [c["name"] for c in sources["system_columns"]]
    assert "sourcePrimaryKey" in xref and "states.consolidation" in xref
    assert "createdBy" not in xref  # the fake reply has none: never invented


def test_create_body_carries_every_filled_field(api: tuple[TestClient, list[str]]) -> None:
    """0.9.10 data check (his live ffr_first_name / ffr_last_name came back NULL in the master):
    every root field the generated preview filled must be in the Create body, by its metadata
    name. If this passes, tx-mdm sends them and the NULLs come from IDMC (survivorship / trust)."""
    client, _ = api
    rows = client.post(f"{BASE}/records/generate", json={"count": 3, "seed": 11}).json()["rows"]
    reply = client.post(
        f"{BASE}/records", json={"source_system": "zlv_ttf", "records": rows}
    ).json()
    assert reply["created"] == 3
    for sent, stored in zip(rows, fake_idmc._CREATED["zlv_guest"], strict=True):
        filled = {k for k, v in sent["values"].items() if v not in (None, "")}
        assert filled, "the preview filled nothing"
        assert {f"zlv_guest.{k}" for k in filled} <= set(stored)
        for k in filled:
            assert stored[f"zlv_guest.{k}"] is not None
