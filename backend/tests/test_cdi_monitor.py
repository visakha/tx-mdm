"""Monitor tab: pure translation of activityMonitor / activityLog rows, plus the service."""

from datetime import UTC, datetime

import respx
from fastapi.testclient import TestClient

from app.cdi.client import CdiClient
from app.cdi.monitor import entry_from_log, entry_from_monitor, minutes_between, parse_time
from app.cdi.service import CdiService
from app.common.idmc_session import IdmcHttp
from app.common.runs import RunRegistry, RunStatus
from app.dependencies import get_cdi_service
from app.main import create_app
from tests.conftest import PLATFORM

NOW = datetime(2026, 11, 22, 12, 30, tzinfo=UTC)
MINE = {"mt_load_customers", "tf_load_all"}


def test_parse_time_and_minutes():
    start = parse_time("2026-11-22T12:00:00.000Z")
    assert start == datetime(2026, 11, 22, 12, 0, tzinfo=UTC)
    assert minutes_between(start, NOW) == 30.0
    assert parse_time("not a time") is None
    assert minutes_between(None, NOW) is None


def test_running_row_uses_task_name_and_elapsed_to_now():
    row = {
        "taskName": "tf_load_all",
        "objectName": "SRC_CUSTOMERS",  # source object, not the task
        "type": "WORKFLOW",
        "runId": 41,
        "startTimeUtc": "2026-11-22T12:15:00.000Z",
        "executionState": "RUNNING",
        "runContextType": "REST-API",
        "entries": [{"taskName": "mt_load_customers", "executionState": "QUEUED"}],
    }
    entry = entry_from_monitor(row, NOW, MINE)
    assert entry.task_name == "tf_load_all"
    assert entry.status is RunStatus.RUNNING
    assert entry.elapsed_minutes == 15.0
    assert entry.in_my_tasks
    assert entry.children[0].status is RunStatus.QUEUED


def test_log_rows_map_states_counts_and_errors():
    ok = entry_from_log(
        {
            "objectName": "mt_load_customers",
            "state": 1,
            "startTimeUtc": "2026-11-22T10:00:00.000Z",
            "endTimeUtc": "2026-11-22T10:12:30.000Z",
            "successSourceRows": 100,
            "failedTargetRows": 2,
            "errorMsg": "No errors encountered.",
        },
        MINE,
    )
    assert ok.status is RunStatus.SUCCESS
    assert ok.elapsed_minutes == 12.5
    assert ok.counts.source_success == 100
    assert ok.counts.target_failed == 2
    assert ok.error == ""

    assert entry_from_log({"state": 2}, MINE).state_text == "COMPLETED_WITH_ERRORS"
    failed = entry_from_log({"state": 3, "errorMsg": "Target table missing"}, MINE)
    assert failed.status is RunStatus.FAILED
    assert failed.error == "Target table missing"
    assert entry_from_log({"state": 3, "isStopped": True}, MINE).status is RunStatus.STOPPED
    assert entry_from_log({"state": 4}, MINE).state_text == "NOT_STARTED"


def _service(idmc: respx.MockRouter, idmc_http: IdmcHttp) -> CdiService:
    idmc.get(f"{PLATFORM}/public/core/v3/objects").respond(
        200, json={"objects": [{"id": "F1", "path": "P/mt_load_customers"}]}
    )
    return CdiService(CdiClient(idmc_http), RunRegistry("cdi"))


def test_service_filters_to_my_tasks(idmc: respx.MockRouter, idmc_http: IdmcHttp):
    monitor = idmc.get(f"{PLATFORM}/api/v2/activity/activityMonitor").respond(
        200,
        json=[
            {"taskName": "mt_load_customers", "executionState": "RUNNING"},
            {"taskName": "other_team_task", "executionState": "RUNNING"},
        ],
    )
    log = idmc.get(f"{PLATFORM}/api/v2/activity/activityLog").respond(
        200, json=[{"objectName": "other_team_task", "state": 1}]
    )
    service = _service(idmc, idmc_http)

    mine = service.monitor(row_limit=25, only_my_tasks=True)
    assert [e.task_name for e in mine.running] == ["mt_load_customers"]
    assert mine.recent == []
    assert mine.my_task_count == 1
    assert monitor.calls[0].request.url.params["details"] == "true"
    assert log.calls[0].request.url.params["rowLimit"] == "25"

    everything = service.monitor(row_limit=25, only_my_tasks=False)
    assert len(everything.running) == 2
    assert len(everything.recent) == 1


def test_history_error_is_a_note_not_a_crash(idmc: respx.MockRouter, idmc_http: IdmcHttp):
    idmc.get(f"{PLATFORM}/api/v2/activity/activityMonitor").respond(200, json=[])
    idmc.get(f"{PLATFORM}/api/v2/activity/activityLog").respond(500, text="boom")
    snapshot = _service(idmc, idmc_http).monitor(row_limit=10, only_my_tasks=True)
    assert snapshot.recent == []
    assert snapshot.notes and snapshot.notes[0].startswith("Job history unavailable")


def test_rate_limit_is_a_hard_stop_on_the_route(idmc: respx.MockRouter, idmc_http: IdmcHttp):
    idmc.get(f"{PLATFORM}/api/v2/activity/activityMonitor").respond(429)
    service = _service(idmc, idmc_http)
    app = create_app()
    app.dependency_overrides[get_cdi_service] = lambda: service
    response = TestClient(app).get("/api/cdi/monitor")
    assert response.status_code == 429
