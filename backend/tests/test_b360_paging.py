"""0.9.9: Records paging, first/last name filters, Business ID lookup, Last updated sort,
and system fields in the metadata (Vamsi, voice 2026-11-23 ~01:30 CST). Fake IDMC only."""

import json

import httpx
import respx
from fastapi.testclient import TestClient

from app.b360data.models import FieldOrigin, OriginSource
from app.b360data.service import B360DataService
from app.b360data.wire import business_entity_from_metadata
from app.common.idmc_session import IdmcHttp
from app.dependencies import get_b360_data_service
from app.main import create_app
from dev import fake_idmc
from tests.conftest import MDM

GUEST = fake_idmc._B360_ENTITIES["zlv_guest"]
SEARCH = f"{MDM}/search/public/api/v1/search"


def _client(idmc: respx.MockRouter, idmc_http: IdmcHttp) -> tuple[TestClient, respx.Route]:
    idmc.get(f"{MDM}/metadata/api/v2/objects/businessEntity/zlv_guest").respond(200, json=GUEST)

    def search(request: httpx.Request) -> httpx.Response:
        return httpx.Response(200, json=fake_idmc.be_search(json.loads(request.content)))

    route = idmc.post(SEARCH).mock(side_effect=search)

    def read(request: httpx.Request) -> httpx.Response:
        bid = request.url.path.rsplit("/", 1)[-1]
        reply = fake_idmc.read_master_record("zlv_guest", bid)
        if isinstance(reply, dict):
            return httpx.Response(200, json=reply)
        return httpx.Response(reply.status_code, content=reply.body)

    idmc.get(url__regex=rf"{MDM}/business-entity/public/api/v1/entity/zlv_guest/.+").mock(
        side_effect=read
    )
    app = create_app()
    app.dependency_overrides[get_b360_data_service] = lambda: B360DataService(idmc_http, MDM)
    return TestClient(app), route


URL = "/api/b360/entities/zlv_guest/records"


def test_paging_and_newest_first(idmc: respx.MockRouter, idmc_http: IdmcHttp) -> None:
    client, route = _client(idmc, idmc_http)
    first = client.get(URL).json()
    assert first["hits"] == 12 and first["total_pages"] == 2 and first["page"] == 1
    assert len(first["records"]) == 10
    assert first["records"][0]["business_id"].endswith("00012")  # newest first by default
    assert first["records"][0]["last_updated"].startswith("2026-11-01T12:00:00")
    assert first["records"][0]["updated_by"] == "fake.loader"
    sent = json.loads(route.calls.last.request.content)
    assert sent["recordOffset"] == 0 and sent["recordsToReturn"] == 10 and sent["pageSize"] == 10
    assert sent["sort"] == [{"fieldName": "_meta.lastUpdateDate", "order": "DESCENDING"}]
    second = client.get(URL + "?page=2").json()
    assert [r["business_id"][-2:] for r in second["records"]] == ["02", "01"]
    assert json.loads(route.calls.last.request.content)["recordOffset"] == 10
    oldest = client.get(URL + "?sort=OLDEST_FIRST").json()
    assert oldest["records"][0]["business_id"].endswith("00001")
    assert json.loads(route.calls.last.request.content)["sort"][0]["order"] == "ASCENDING"
    assert client.get(URL + "?sort=FIRST_NAME").status_code == 422  # only Last updated sorts


def test_first_and_last_name_filters(idmc: respx.MockRouter, idmc_http: IdmcHttp) -> None:
    client, route = _client(idmc, idmc_http)
    client.get(URL)  # learns the key prefix the search reply uses
    page = client.get(URL + "?first_name=ann&last_name=Smith").json()
    sent = json.loads(route.calls.last.request.content)
    assert sent["filters"]["filter"] == [
        {"fieldName": "zlv_guest.first_name", "comparator": "STARTS_WITH", "fieldValue": "ann"},
        {"fieldName": "zlv_guest.last_name", "comparator": "STARTS_WITH", "fieldValue": "Smith"},
    ]
    assert page["hits"] == 2  # Anna3, Anna9 (odd i -> Smith)
    assert {f["label"] for f in page["filters"]} == {"First name", "Last name"}
    assert sent["recordOffset"] == 0


def test_business_id_lookup(idmc: respx.MockRouter, idmc_http: IdmcHttp) -> None:
    client, route = _client(idmc, idmc_http)
    bid = "300000000000000000000000005"
    page = client.get(URL + f"?business_id={bid}").json()
    assert page["mode"] == "BUSINESS_ID" and page["hits"] == 1
    assert page["records"][0]["business_id"] == bid
    assert page["records"][0]["values"]["first_name"] == "Carla5"
    assert route.call_count == 0  # Read Master Record, not search
    missing = client.get(URL + "?business_id=NOPE").json()
    assert missing["hits"] == 0 and "NOPE" in missing["note"]


def test_name_filter_without_field_is_400(idmc: respx.MockRouter, idmc_http: IdmcHttp) -> None:
    person = fake_idmc._B360_ENTITIES["c360.organization"]
    idmc.get(f"{MDM}/metadata/api/v2/objects/businessEntity/c360.organization").respond(
        200, json=person
    )
    app = create_app()
    app.dependency_overrides[get_b360_data_service] = lambda: B360DataService(idmc_http, MDM)
    reply = TestClient(app).get("/api/b360/entities/c360.organization/records?first_name=x")
    assert reply.status_code == 400


def test_search_429_passed_through(idmc: respx.MockRouter, idmc_http: IdmcHttp) -> None:
    idmc.get(f"{MDM}/metadata/api/v2/objects/businessEntity/zlv_guest").respond(200, json=GUEST)
    route = idmc.post(SEARCH).respond(429)
    app = create_app()
    app.dependency_overrides[get_b360_data_service] = lambda: B360DataService(idmc_http, MDM)
    assert TestClient(app).get(URL + "?page=2").status_code == 429
    assert route.call_count == 1


def test_system_fields_and_groups_typed() -> None:
    body = {
        **GUEST,
        "field": [
            *GUEST["field"],
            {"eClass": "x#//TextField", "name": "_sysStamp", "label": {"en": "Stamp"}},
            {"eClass": "x#//TextField", "name": "srcFlag", "systemField": True},
        ],
    }
    meta = business_entity_from_metadata(body, "zlv_guest")
    assert all(f.origin is FieldOrigin.CONFIGURED for f in meta.fields)
    assert "_sysStamp" not in {f.name for f in meta.fields}
    sys_names = [f.name for f in meta.system_fields]
    assert sys_names[:2] == ["_sysStamp", "srcFlag"]
    assert meta.system_fields[0].origin_source is OriginSource.METADATA
    assert "recordStateIndicator" in sys_names
    meta_group = next(g for g in meta.system_field_groups if g.name == "_meta")
    assert meta_group.origin is FieldOrigin.SYSTEM
    assert meta_group.origin_source is OriginSource.DOCUMENTED
    assert "lastUpdateDate" in {f.name for f in meta_group.fields}
    assert all(f.origin is FieldOrigin.SYSTEM for f in meta_group.fields)
