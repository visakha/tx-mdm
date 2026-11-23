"""0.9.12: Merge (M) with per-field winners, and Unmerge.

Every MDM call is forwarded to the fake IDMC app (dev/fake_idmc.py). Never his org.
Mirrors Vamsi's ask (2026-11-23 02:21 CST): merge two records, first name from the first wins,
last name from the second wins.
"""

from collections.abc import Iterator

import httpx
import pytest
import respx
from fastapi.testclient import TestClient

from app.b360data.service import B360DataService
from app.common.idmc_session import IdmcHttp
from app.dependencies import get_b360_data_service
from app.main import create_app
from dev import fake_idmc
from tests.conftest import MDM

FAKE = TestClient(fake_idmc.app)
BASE = "/api/b360/entities/zlv_guest"
A = "300000000000000000000000001"  # Ben1 Smith
B = "300000000000000000000000002"  # Carla2 Jones


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
    fake_idmc.reset_merge_state()
    app = create_app()
    app.dependency_overrides[get_b360_data_service] = lambda: B360DataService(idmc_http, MDM)
    yield TestClient(app), calls
    fake_idmc.reset_merge_state()


def _writes(calls: list[str]) -> list[str]:
    return [c for c in calls if not c.startswith("GET")]


def test_preview_is_read_only_side_by_side(api: tuple[TestClient, list[str]]) -> None:
    client, calls = api
    reply = client.post(f"{BASE}/merge/preview", json={"business_ids": [A, B]})
    assert reply.status_code == 200
    body = reply.json()
    first = next(r for r in body["rows"] if r["field"] == "first_name")
    assert first["values"] == {A: "Ben1", B: "Carla2"}
    assert first["differs"] is True
    twin = next(r for r in body["rows"] if r["field"] == "clns_first_name")
    assert twin["follows"] == "first_name"
    assert _writes(calls) == []


def test_merge_with_field_winners_like_vamsi_asked(api: tuple[TestClient, list[str]]) -> None:
    client, calls = api
    reply = client.post(
        f"{BASE}/merge",
        json={"business_ids": [A, B], "winners": {"first_name": A, "last_name": B}},
    )
    assert reply.status_code == 200, reply.text
    body = reply.json()
    assert body["surviving_business_id"] == A
    assert [s["status"] for s in body["steps"]] == ["OK", "OK", "OK", "OK"]
    assert fake_idmc.MERGES == [[{"businessId": A}, {"businessId": B}]]
    patch = fake_idmc.MASTER_PATCHES[0]
    assert patch["sourceSystem"] == "zlv_ttf"  # [sources] default
    assert {(o["path"], o["value"]) for o in patch["body"]} == {
        ("first_name", "Ben1"),
        ("clns_first_name", "BEN1"),
        ("last_name", "Jones"),
        ("clns_last_name", "JONES"),
    }
    assert body["after"]["values"]["first_name"] == "Ben1"
    assert body["after"]["values"]["last_name"] == "Jones"
    assert body["after"]["values"]["clns_last_name"] == "JONES"
    assert all(o["stuck"] for o in body["overrides"])
    carried = {o["field"]: o["carried_with"] for o in body["overrides"]}
    assert carried["clns_last_name"] == "last_name"
    # write order: merge, then one patch
    assert _writes(calls) == [
        "POST /business-entity/public/api/v1/entity-group/zlv_guest",
        f"PATCH /business-entity/public/api/v1/entity/zlv_guest/{A}",
    ]
    # the merged-away record is gone from search
    assert B not in {
        r["business_id"] for r in client.get(f"{BASE}/records?limit=50").json()["records"]
    }


def test_merge_without_winners_sends_no_patch(api: tuple[TestClient, list[str]]) -> None:
    client, _ = api
    body = client.post(f"{BASE}/merge", json={"business_ids": [A, B]}).json()
    assert body["steps"][2] == {
        "step": "OVERRIDE",
        "status": "SKIPPED",
        "detail": "no field winners picked; IDMC survivorship decides every field",
    }
    assert fake_idmc.MASTER_PATCHES == []


def test_approval_required_skips_overrides(api: tuple[TestClient, list[str]]) -> None:
    client, _ = api
    fake_idmc.APPROVAL_REQUIRED["merge"] = True
    body = client.post(
        f"{BASE}/merge", json={"business_ids": [A, B], "winners": {"first_name": A}}
    ).json()
    assert body["approval_required"] is True
    assert body["steps"][2]["status"] == "SKIPPED"
    assert fake_idmc.MASTER_PATCHES == []


@pytest.mark.parametrize(
    ("payload", "needle"),
    [
        ({"business_ids": [A, A]}, "listed twice"),
        ({"business_ids": [A, B], "winners": {"first_name": "999"}}, "not one of the merged"),
        ({"business_ids": [A, B], "winners": {"nope": A}}, "not a root field"),
        (
            {"business_ids": [A, B], "winners": {"first_name": A}, "override_source_system": "X"},
            "not in",
        ),
    ],
)
def test_bad_requests_send_nothing(
    api: tuple[TestClient, list[str]], payload: dict[str, object], needle: str
) -> None:
    client, calls = api
    reply = client.post(f"{BASE}/merge", json=payload)
    assert reply.status_code == 400
    assert needle in reply.json()["detail"]
    assert calls == [] or all(c.startswith("GET /metadata") for c in calls)


def test_missing_record_stops_before_merge(api: tuple[TestClient, list[str]]) -> None:
    client, _ = api
    body = client.post(f"{BASE}/merge", json={"business_ids": [A, "NOPE1"]}).json()
    assert body["steps"][0]["status"] == "FAILED"
    assert body["surviving_business_id"] is None
    assert fake_idmc.MERGES == []


def test_entity_not_in_focus_is_refused(api: tuple[TestClient, list[str]]) -> None:
    client, _ = api
    reply = client.post("/api/b360/entities/c360.person/merge", json={"business_ids": [A, B]})
    assert reply.status_code == 400
    assert "focus" in reply.json()["detail"]


def test_unmerge_sends_source_keys_with_business_id_rels(api: tuple[TestClient, list[str]]) -> None:
    client, _ = api
    client.post(f"{BASE}/merge", json={"business_ids": [A, B]})
    reply = client.post(
        f"{BASE}/records/{A}/unmerge",
        json={"sources": [{"source_system": "zlv_ttf", "source_pkey": "TTF-02"}]},
    )
    assert reply.status_code == 200
    assert reply.json()["approval_required"] is False
    sent = fake_idmc.UNMERGES[0]
    assert sent["keepRelsWith"] == "BUSINESS_ID"
    assert sent["allowMergeBack"] == "NEVER_MERGE"
    assert sent["body"] == [{"sourcePKey": "TTF-02", "sourceSystem": "zlv_ttf"}]
