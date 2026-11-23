"""0.9.12.4: Merge history (M) / (S) from content meta, and Copy IDMC curl (fake IDMC only)."""

import subprocess
from collections.abc import Iterator

import httpx
import pytest
import respx
from fastapi.testclient import TestClient

from app.b360data import history
from app.b360data.service import B360DataService
from app.common.idmc_session import IdmcHttp
from app.dependencies import get_b360_data_service
from app.main import create_app
from dev import fake_idmc
from tests.conftest import MDM
from tests.test_b360_merge import A, B

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
    fake_idmc._CREATED.clear()
    fake_idmc._XREF_EDITS.clear()
    fake_idmc.MERGES.clear()
    fake_idmc.MASTER_PATCHES.clear()
    fake_idmc._MERGED_INTO.clear()
    fake_idmc._MASTER_EDITS.clear()
    history.clear()
    app = create_app()
    app.dependency_overrides[get_b360_data_service] = lambda: B360DataService(idmc_http, MDM)
    yield TestClient(app)


def test_master_history_from_content_meta(api: TestClient) -> None:
    body = api.get(f"{BASE}/records/{A}/merge-history").json()
    assert body["business_id"] == A
    by_field = {f["field"]: f for f in body["fields"]}
    assert by_field["last_name"]["winner"]["source_system"] == "zlv_eci"
    assert by_field["first_name"]["winner"]["field_ref"] == "/"  # record-wide entry
    assert by_field["first_name"]["winner"]["trust_rule"] == "SourceRanking"
    assert {c["source_system"] for c in body["contributors"]} == {"zlv_ttf", "zlv_eci"}
    assert "no merge-event log" in body["note"]
    assert body["app_events"] == []


def test_merge_from_this_app_is_listed(api: TestClient) -> None:
    api.post(f"{BASE}/merge", json={"business_ids": [A, B], "winners": {}})
    events = api.get(f"{BASE}/records/{A}/merge-history").json()["app_events"]
    assert len(events) == 1 and events[0]["kind"] == "MERGE"
    assert events[0]["business_ids"] == [A, B]


def test_source_history_and_won(api: TestClient) -> None:
    n = A[-2:]
    body = api.get(f"{BASE}/sources/zlv_ttf/TTF-{n}/merge-history").json()
    assert body["business_id"] == A
    assert body["trust"][0]["trust_score"] == 0.9
    first = next(f for f in body["fields"] if f["field"] == "first_name")
    assert first["won"] is True  # fake xref copies the master values
    assert api.get(f"{BASE}/sources/zlv_ttf/NOPE-1/merge-history").status_code == 404


def test_echo_is_runnable_and_has_no_secret(api: TestClient) -> None:
    reply = api.get(f"{BASE}/records/{A}/merge-history")
    echo_id = reply.headers["X-Idmc-Echo-Id"]
    echo = api.get(f"/api/idmc/echo/{echo_id}")
    assert echo.status_code == 200
    raw = echo.text
    assert "not-a-real-password" not in raw
    assert "IDS-SESSION-ID: S1" not in raw and '"S1"' not in raw
    data = echo.json()
    read = next(c for c in data["calls"] if "_showContentMeta=true" in c["url"])
    assert read["url"].endswith(f"/entity/zlv_guest/{A}?_showContentMeta=true")
    assert read["session_headers"] == ["IDS-SESSION-ID"]
    assert data["login"]["username"] == "tester"
    assert "IDS-SESSION-ID: $sid" in data["powershell"]
    assert "$env:IDMC_PASSWORD" in data["powershell"]
    assert "IDS-SESSION-ID: $SID" in data["bash"]
    assert raw.isascii()
    syntax = subprocess.run(["bash", "-n"], input=data["bash"], text=True, capture_output=True)
    assert syntax.returncode == 0, syntax.stderr


def test_write_echo_shows_body(api: TestClient) -> None:
    reply = api.post(f"{BASE}/merge", json={"business_ids": [A, B], "winners": {}})
    assert reply.status_code == 200, reply.text
    data = api.get(f"/api/idmc/echo/{reply.headers['X-Idmc-Echo-Id']}").json()
    assert data["writes"] is True, [c["method"] + " " + c["url"] for c in data["calls"]]
    post = next(c for c in data["calls"] if c["method"] == "POST")
    assert '"businessId"' in (post["body"] or "")
    assert "--data-binary" in data["bash"] and "body.json" in data["powershell"]
    syntax = subprocess.run(["bash", "-n"], input=data["bash"], text=True, capture_output=True)
    assert syntax.returncode == 0, syntax.stderr


def test_unknown_echo_404(api: TestClient) -> None:
    assert api.get("/api/idmc/echo/nope").status_code == 404
