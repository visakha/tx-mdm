import respx

from app.cdi.client import (
    CdiClient,
    snapshot_from_activity_log,
    snapshot_from_taskflow_status,
)
from app.cdi.models import CdiRunRequest, CdiTaskType
from app.cdi.service import CdiService
from app.common.idmc_session import IdmcHttp
from app.common.runs import RunRegistry, RunStatus
from tests.conftest import PLATFORM


def test_lists_tasks_pages_until_a_short_page(idmc: respx.MockRouter, idmc_http: IdmcHttp):
    full_page = [{"id": f"id{i}", "path": f"Proj/Folder/task{i}"} for i in range(200)]
    route = idmc.get(f"{PLATFORM}/public/core/v3/objects")
    route.side_effect = [
        respx.MockResponse(200, json={"objects": full_page}),
        respx.MockResponse(200, json={"objects": [{"id": "last", "path": "Proj/z_last"}]}),
    ]

    tasks = CdiClient(idmc_http).list_tasks([CdiTaskType.MTT])

    assert len(tasks) == 201
    assert route.calls[1].request.url.params["skip"] == "200"
    assert tasks[-1].name == "z_last"


def test_activity_log_states_map_to_run_status():
    assert snapshot_from_activity_log({"state": 1}).status is RunStatus.SUCCESS
    assert snapshot_from_activity_log({"state": 2}).status is RunStatus.WARNING
    failed = snapshot_from_activity_log(
        {"state": 3, "errorMsg": "Target table missing", "successSourceRows": 10}
    )
    assert failed.status is RunStatus.FAILED
    assert failed.errors == ["Target table missing"]
    assert failed.counts.source_success == 10


def test_taskflow_status_maps():
    assert snapshot_from_taskflow_status({"status": "RUNNING"}).status is RunStatus.RUNNING
    assert snapshot_from_taskflow_status({"status": "SUSPENDED"}).status is RunStatus.STOPPED


def test_mapping_task_run_then_finish(idmc: respx.MockRouter, idmc_http: IdmcHttp):
    idmc.post(f"{PLATFORM}/api/v2/job").respond(200, json={"runId": 59, "taskId": "T1"})
    idmc.get(f"{PLATFORM}/api/v2/activity/activityMonitor").respond(200, json=[])
    idmc.get(f"{PLATFORM}/api/v2/activity/activityLog").respond(
        200, json=[{"state": 1, "successTargetRows": 42, "endTimeUtc": "2026-11-22T10:00:00Z"}]
    )
    service = CdiService(CdiClient(idmc_http), RunRegistry("cdi"))

    run = service.start(
        CdiRunRequest(task_id="FED1", task_type=CdiTaskType.MTT, task_name="mt_load")
    )
    assert run.status is RunStatus.QUEUED

    run = service.refresh(run.run_key)
    assert run.status is RunStatus.SUCCESS
    assert run.counts.target_success == 42
    assert run.ended_at is not None


def test_failed_start_is_recorded_not_retried(idmc: respx.MockRouter, idmc_http: IdmcHttp):
    route = idmc.post(f"{PLATFORM}/api/v2/job").respond(500, text="boom")
    service = CdiService(CdiClient(idmc_http), RunRegistry("cdi"))

    run = service.start(CdiRunRequest(task_id="F", task_type=CdiTaskType.MTT, task_name="mt"))

    assert run.status is RunStatus.FAILED
    assert route.call_count == 1
