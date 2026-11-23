import json
from datetime import UTC, datetime

import httpx
import respx
from fastapi.testclient import TestClient

from app.common.idmc_session import IdmcHttp
from app.common.runs import RunStatus
from app.dependencies import get_mdm_monitor
from app.main import create_app
from app.mdm.client import MdmClient
from app.mdm.models import MdmJobKind
from app.mdm.monitor import MdmMonitor, build_snapshot, is_b360_type, view_from_instance
from tests.conftest import MDM, PLATFORM

NOW = datetime(2026, 11, 23, 6, 0, tzinfo=UTC)
NOW_MS = int(NOW.timestamp() * 1000)

PORTAL = {
    "id": "1309395637279657984",
    "name": "zlv_ingr_guest_basic",
    "jobType": "b360.ingress.load",
    "jobDefinition": {"id": "zlv_ingr_guest_basic"},
    "_meta": {"state": "RUNNING", "startedAt": NOW_MS - 9 * 60_000, "startedBy": "someone.else"},
}
EGRESS_DONE = {
    "id": "1309392734552862720",
    "name": "Egress ZLV Guest basic Src_TTF",
    "jobType": "c360.egress.etl",
    "jobDefinition": {"id": "egress_zlv_guest_basic_src_ttf"},
    "jobLevelMetrics": [{"id": "NUM_OF_INCOMING_RECORDS", "value": 21}],
    "_meta": {
        "state": "FAILED",
        "startedAt": NOW_MS - 20 * 60_000,
        "completedAt": NOW_MS - 18 * 60_000,
        "startedBy": "vvamsi-idmcdev",
    },
}
CONSOLE = {
    "id": "555",
    "jobType": "internal.c360.ingress.fileImportJob",
    "_meta": {"state": "RUNNING", "startedAt": NOW_MS},
}


def test_b360_types_are_b360_and_c360_prefixes():
    assert is_b360_type("b360.ingress.load")
    assert is_b360_type("c360.egress.etl")
    assert is_b360_type("C360.be.matchmerge")
    assert not is_b360_type("internal.c360.ingress.fileImportJob")


def test_view_keeps_full_id_and_computes_elapsed():
    view = view_from_instance(PORTAL, NOW)
    assert view.instance_id == "1309395637279657984"
    assert view.status is RunStatus.RUNNING
    assert view.kind is MdmJobKind.INGRESS
    assert view.started_by == "someone.else"
    assert view.elapsed_minutes == 9.0
    assert view.ended_at is None


def test_snapshot_merges_dedupes_and_hides_other_types():
    snap = build_snapshot([PORTAL, CONSOLE], [EGRESS_DONE, PORTAL, CONSOLE], 25, NOW)
    assert [v.instance_id for v in snap.running] == ["1309395637279657984"]
    assert [v.instance_id for v in snap.recent] == ["1309392734552862720"]
    assert snap.recent[0].elapsed_minutes == 2.0
    assert snap.recent[0].counts.source_success == 21
    assert snap.other_types_hidden == 1


def test_running_job_found_only_in_recent_page_is_still_running():
    snap = build_snapshot([], [PORTAL], 25, NOW)
    assert [v.instance_id for v in snap.running] == ["1309395637279657984"]


def test_monitor_sends_documented_search_bodies(idmc, idmc_http: IdmcHttp):
    route = idmc.post(f"{MDM}/job/public/api/v1/search").mock(
        side_effect=[
            httpx.Response(200, json={"totalPages": 1, "jobInstances": [PORTAL]}),
            httpx.Response(200, json={"totalPages": 1, "jobInstances": [EGRESS_DONE, PORTAL]}),
        ]
    )
    monitor = MdmMonitor(MdmClient(idmc_http, MDM, PLATFORM))
    snap = monitor.snapshot(10)
    first = json.loads(route.calls[0].request.content)
    second = json.loads(route.calls[1].request.content)
    assert first["filters"]["filter"] == [
        {"fieldName": "status", "fieldValue": "RUNNING"},
        {"fieldName": "status", "fieldValue": "QUEUED"},
    ]
    assert second == {"search": "*", "pageSize": 10, "pageOffset": 0}
    assert route.calls[0].request.headers["IDS-SESSION-ID"] == "S1"
    assert len(snap.running) == 1 and len(snap.recent) == 1


def _client(idmc_http: IdmcHttp) -> TestClient:
    app = create_app()
    app.dependency_overrides[get_mdm_monitor] = lambda: MdmMonitor(
        MdmClient(idmc_http, MDM, PLATFORM)
    )
    return TestClient(app)


def test_lookup_endpoint_reads_any_instance(idmc: respx.MockRouter, idmc_http: IdmcHttp):
    route = idmc.get(f"{MDM}/job/public/api/v1/jobInstance/1309395637279657984").respond(
        200, json=PORTAL
    )
    body = _client(idmc_http).get("/api/mdm/job-instances/1309395637279657984").json()
    assert body["instance_id"] == "1309395637279657984"
    assert body["status"] == "RUNNING"
    assert route.calls.last.request.url.params["details"] == "true"


def test_lookup_rejects_odd_ids(idmc_http: IdmcHttp):
    assert _client(idmc_http).get("/api/mdm/job-instances/a%20b").status_code == 422


def test_monitor_passes_429_through_without_retry(idmc: respx.MockRouter, idmc_http: IdmcHttp):
    route = idmc.post(f"{MDM}/job/public/api/v1/search").respond(429, text="slow down")
    response = _client(idmc_http).get("/api/mdm/monitor")
    assert response.status_code == 429
    assert route.call_count == 1
