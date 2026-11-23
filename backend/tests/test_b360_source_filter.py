"""0.9.12.3: source-specific Records (S) / Metadata (S). Fake IDMC (zlv_ttf + zlv_eci xrefs)."""

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
    fake_idmc._CREATED.clear()
    fake_idmc._XREF_EDITS.clear()
    app = create_app()
    app.dependency_overrides[get_b360_data_service] = lambda: B360DataService(idmc_http, MDM)
    yield TestClient(app), calls


def test_default_is_the_toml_default_only(api: tuple[TestClient, list[str]]) -> None:
    client, calls = api
    page = client.get(f"{BASE}/source-records").json()
    assert page["source_systems"] == ["zlv_ttf"]
    assert page["records"] and {r["source_system"] for r in page["records"]} == {"zlv_ttf"}
    assert page["skipped_other_systems"] == len(page["masters_read"])  # one zlv_eci each
    assert not any("/entity-xref/zlv_guest/zlv_eci/" in c for c in calls)  # never read
    assert "after the IDMC read" in page["filter_note"]


def test_two_systems_flat_table(api: tuple[TestClient, list[str]]) -> None:
    client, _ = api
    page = client.get(
        f"{BASE}/source-records",
        params=[("source_systems", "zlv_ttf"), ("source_systems", "zlv_eci")],
    ).json()
    systems = {r["source_system"] for r in page["records"]}
    assert systems == {"zlv_ttf", "zlv_eci"}
    assert len(page["records"]) == 2 * len(page["masters_read"])
    assert all(r["business_id"] in page["masters_read"] for r in page["records"])


def test_not_allowed_source_is_400(api: tuple[TestClient, list[str]]) -> None:
    client, calls = api
    reply = client.get(f"{BASE}/source-records", params={"source_systems": "salesforce"})
    assert reply.status_code == 400 and "salesforce" in reply.json()["detail"]
    assert calls == []
    meta = client.get(f"{BASE}/source-metadata/by-system", params={"source_systems": "nope"})
    assert meta.status_code == 400


def test_source_metadata_once_for_all_picked(api: tuple[TestClient, list[str]]) -> None:
    client, _ = api
    meta = client.get(
        f"{BASE}/source-metadata/by-system",
        params=[("source_systems", "zlv_eci"), ("source_systems", "c360.default.system")],
    ).json()
    assert meta["source_systems"] == ["zlv_eci", "c360.default.system"]
    assert meta["same_for_all"] is True and "zlv_eci" in meta["note"]
    assert any(g["name"] == "_meta" for g in meta["entity"]["system_field_groups"])
