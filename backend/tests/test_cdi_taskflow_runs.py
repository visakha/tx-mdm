"""Taskflows by name / by IDMC run id: start, status + summary, session log (respx fake IDMC)."""

import io
import json
import zipfile
from datetime import UTC, datetime

import respx
from fastapi.testclient import TestClient

from app.cdi.client import CdiClient
from app.cdi.service import CdiService
from app.cdi.taskflow_runs import find_log_entry, log_text, status_from_body
from app.common.idmc_session import IdmcHttp
from app.common.runs import RunRegistry, RunStatus
from app.dependencies import get_cdi_service
from app.main import create_app
from tests.conftest import PLATFORM

POD = PLATFORM.removesuffix("/saas")
NOW = datetime(2026, 11, 23, 5, 0, tzinfo=UTC)
RUN = "1309380263289049088"

SUSPENDED = {
    "assetName": "tf_MDM_ZLV_TTF_Guest_Basic",
    "assetType": "TASKFLOW",
    "runId": int(RUN),
    "status": "SUSPENDED",
    "startTime": "2026-11-23T04:49:42Z",
    "endTime": "2026-11-23T04:52:12Z",
    "startedBy": "VVamsi-idmcdev",
    "errorMessage": "[FATAL] Invalid/Default JobInstanceId is passed as runtime parameter",
    "subtasks": 1,
    "subtaskDetails": {
        "details": {
            "tasks": [
                {
                    "assetName": "mt_m_MDM_ZLV_TTF_Guest_Basic",
                    "assetType": "MTT",
                    "runId": "5",
                    "status": "FAILED",
                    "startTime": "2026-11-23T04:49:50Z",
                    "endTime": "2026-11-23T04:52:10Z",
                    "rowsProcessed": "0",
                    "successRows": "0",
                    "errorRows": "0",
                    "errorMessage": "[FATAL] Invalid/Default JobInstanceId is passed",
                }
            ]
        }
    },
}

LOG_ROWS = [
    {
        "id": "0000ABC",
        "objectName": "tf_parent_is_not_here",
        "runId": 9,
        "entries": [
            {
                "id": "0000DEF",
                "objectName": "mt_m_MDM_ZLV_TTF_Guest_Basic",
                "runId": 5,
                "successSourceRows": 10,
                "failedSourceRows": 1,
                "successTargetRows": 9,
                "failedTargetRows": 2,
            }
        ],
    }
]


def _app(idmc_http: IdmcHttp) -> TestClient:
    service = CdiService(CdiClient(idmc_http), RunRegistry("cdi"))
    app = create_app()
    app.dependency_overrides[get_cdi_service] = lambda: service
    return TestClient(app)


def test_status_body_maps_suspended_run_and_children():
    status = status_from_body(RUN, SUSPENDED, NOW)
    assert status.status is RunStatus.STOPPED
    assert status.state_text == "SUSPENDED"
    assert status.is_final
    assert status.elapsed_minutes == 2.5
    child = status.subtasks[0]
    assert child.status is RunStatus.FAILED
    assert child.rows_processed == 0
    assert "JobInstanceId" in child.error


def test_purged_or_unknown_run_is_unknown_with_note():
    status = status_from_body("1", {"status": "No status available."}, NOW)
    assert status.status is RunStatus.UNKNOWN
    assert not status.is_final
    assert status.notes


def test_log_entry_found_in_children_by_name_and_run():
    assert find_log_entry(LOG_ROWS, "mt_m_MDM_ZLV_TTF_Guest_Basic", "5")["id"] == "0000DEF"
    assert find_log_entry(LOG_ROWS, "mt_m_MDM_ZLV_TTF_Guest_Basic", "6") is None


def test_zip_session_log_is_unpacked():
    buffer = io.BytesIO()
    with zipfile.ZipFile(buffer, "w") as archive:
        archive.writestr("a.log", "line one")
    text = log_text("application/zip", buffer.getvalue())
    assert "===== a.log =====" in text and "line one" in text


def test_run_by_name_returns_idmc_run_id(idmc: respx.MockRouter, idmc_http: IdmcHttp):
    idmc.get(f"{PLATFORM}/public/core/v3/objects").respond(
        200, json={"objects": [{"id": "FED9", "path": "ZL_Vamsi/tf_MDM_ZLV_TTF_Guest_Basic"}]}
    )
    rt = idmc.post(f"{POD}/active-bpel/rt/tf_MDM_ZLV_TTF_Guest_Basic").respond(
        200, json={"RunId": RUN}
    )
    client = _app(idmc_http)
    response = client.post(
        "/api/cdi/taskflows/tf_MDM_ZLV_TTF_Guest_Basic/run",
        json={"parameters": {"jobInstanceId": "ABC123"}},
    )
    assert response.status_code == 200
    body = response.json()
    assert json.loads(rt.calls.last.request.content) == {"jobInstanceId": "ABC123"}
    assert body["parameters"] == {"jobInstanceId": "ABC123"}
    assert body["run_id"] == RUN
    assert body["status_path"] == f"/api/cdi/taskflows/runs/{RUN}"
    assert rt.call_count == 1


def test_run_by_unknown_name_is_404_with_suggestion(idmc: respx.MockRouter, idmc_http: IdmcHttp):
    idmc.get(f"{PLATFORM}/public/core/v3/objects").respond(
        200, json={"objects": [{"id": "FED9", "path": "ZL_Vamsi/tf_Good"}]}
    )
    response = _app(idmc_http).post("/api/cdi/taskflows/TF_GOOD/run")
    assert response.status_code == 404
    assert "Did you mean tf_Good" in response.json()["detail"]


def test_run_refused_403_is_passed_through_with_hint(idmc: respx.MockRouter, idmc_http: IdmcHttp):
    idmc.get(f"{PLATFORM}/public/core/v3/objects").respond(
        200, json={"objects": [{"id": "FED9", "path": "ZL_Vamsi/tf_Good"}]}
    )
    idmc.post(f"{POD}/active-bpel/rt/tf_Good").respond(
        403, json={"message": "User VVamsi-idmcdev not authorized to access service x/tf_Good"}
    )
    response = _app(idmc_http).post("/api/cdi/taskflows/tf_Good/run")
    assert response.status_code == 403
    assert "Allowed Users" in response.json()["detail"]


def test_status_and_session_log_by_run_id(idmc: respx.MockRouter, idmc_http: IdmcHttp):
    tf = idmc.get(f"{POD}/active-bpel/services/tf/status/{RUN}").respond(200, json=SUSPENDED)
    idmc.get(f"{PLATFORM}/api/v2/activity/activityLog").respond(200, json=LOG_ROWS)
    idmc.get(f"{PLATFORM}/api/v2/activity/activityLog/0000DEF/sessionLog").respond(
        200, text="WRITER> rejected 2 rows", headers={"content-type": "text/plain"}
    )
    client = _app(idmc_http)
    body = client.get(f"/api/cdi/taskflows/runs/{RUN}").json()
    assert body["status"] == "STOPPED"
    child = body["subtasks"][0]
    assert child["log_entry_id"] == "0000DEF"
    assert child["rows"]["target_failed"] == 2
    assert body["totals"]["source_success"] == 10
    assert tf.calls.last.request.url.params["subtaskDetails"] == "Yes"

    # final answers are cached: a second poll makes no IDMC call
    client.get(f"/api/cdi/taskflows/runs/{RUN}")
    assert tf.call_count == 1

    log = client.get(f"/api/cdi/taskflows/runs/{RUN}/session-log")
    assert log.status_code == 200
    assert log.headers["content-type"].startswith("text/plain")
    assert "rejected 2 rows" in log.text

    missing = client.get(f"/api/cdi/taskflows/runs/{RUN}/session-log?subtask=nope")
    assert missing.status_code == 404


def test_parallel_starts_of_one_taskflow_are_allowed(idmc: respx.MockRouter, idmc_http: IdmcHttp):
    idmc.get(f"{PLATFORM}/public/core/v3/objects").respond(
        200, json={"objects": [{"id": "FED9", "path": "ZL_Vamsi/tf_MDM_ZLV_TTF_Guest_Basic"}]}
    )
    idmc.post(f"{POD}/active-bpel/rt/tf_MDM_ZLV_TTF_Guest_Basic").respond(200, json={"RunId": RUN})
    idmc.get(f"{POD}/active-bpel/services/tf/status/{RUN}").respond(200, json=SUSPENDED)
    idmc.get(f"{PLATFORM}/api/v2/activity/activityLog").respond(200, json=LOG_ROWS)
    client = _app(idmc_http)
    url = "/api/cdi/taskflows/tf_MDM_ZLV_TTF_Guest_Basic/run"
    assert client.post(url).status_code == 200
    # 0.9.1: he starts runs in parallel; this backend no longer answers 409 (IDMC decides).
    assert client.post(url).status_code == 200
    client.get(f"/api/cdi/taskflows/runs/{RUN}")
    assert client.post(url).status_code == 200
    # same run id again (cached final status) must close the new local run too
    client.get(f"/api/cdi/taskflows/runs/{RUN}")
    assert client.post(url).status_code == 200


def test_live_suspended_shape_no_end_time_and_json_error():
    """Shape seen live 2026-11-22 for run 1309380263289049088."""
    body = dict(SUSPENDED)
    del body["endTime"]
    body["updateTime"] = "2026-11-23T04:51:05Z"
    body["errorMessage"] = (
        '{"reason":"[FATAL] Invalid\\/Default JobInstanceId is passed as runtime parameter",'
        '"code":"error","details":"011EWBC1"}'
    )
    status = status_from_body(RUN, body, NOW)
    assert status.ended_at is not None and status.elapsed_minutes == 1.4
    assert status.error == "[FATAL] Invalid/Default JobInstanceId is passed as runtime parameter"


def test_terminate_sends_runid_list_and_closes_local_run(
    idmc: respx.MockRouter, idmc_http: IdmcHttp
):
    idmc.get(f"{PLATFORM}/public/core/v3/objects").respond(
        200, json={"objects": [{"id": "FED9", "path": "ZL_Vamsi/tf_MDM_ZLV_TTF_Guest_Basic"}]}
    )
    idmc.post(f"{POD}/active-bpel/rt/tf_MDM_ZLV_TTF_Guest_Basic").respond(200, json={"RunId": RUN})
    put = idmc.put(f"{POD}/active-bpel/services/tf/terminate").respond(204)
    client = _app(idmc_http)
    url = "/api/cdi/taskflows/tf_MDM_ZLV_TTF_Guest_Basic/run"
    assert client.post(url).status_code == 200
    response = client.post(f"/api/cdi/taskflows/runs/{RUN}/terminate")
    assert response.status_code == 200
    assert response.json()["terminated"] is True
    assert json.loads(put.calls.last.request.content) == {"runid": [RUN]}
    assert put.calls.last.request.headers["INFA-SESSION-ID"]
    assert client.post(url).status_code == 200  # local run closed -> no 409


def test_terminate_invalid_id_500_is_502_with_text(idmc: respx.MockRouter, idmc_http: IdmcHttp):
    idmc.put(f"{POD}/active-bpel/services/tf/terminate").respond(
        500, json={"error": "Invalid run id"}
    )
    response = _app(idmc_http).post("/api/cdi/taskflows/runs/123/terminate")
    assert response.status_code == 502
    assert "not valid" in response.json()["detail"]


def test_terminate_more_than_200_ids_is_400(idmc_http: IdmcHttp):
    extra = [str(i) for i in range(1000, 1200)]
    response = _app(idmc_http).post("/api/cdi/taskflows/runs/1/terminate", json={"run_ids": extra})
    assert response.status_code == 400


def test_terminate_429_is_hard_stop(idmc: respx.MockRouter, idmc_http: IdmcHttp):
    idmc.put(f"{POD}/active-bpel/services/tf/terminate").respond(429)
    assert _app(idmc_http).post("/api/cdi/taskflows/runs/1/terminate").status_code == 429


def test_live_aborted_shape_is_failed_with_aborted_flag_and_clean_reason():
    """Shape seen live 2026-11-22 23:21 CST for run 1309386379683184640, aborted in the portal."""
    body = dict(SUSPENDED)
    body["status"] = "FAILED"
    body["endTime"] = "2026-11-23T05:21:37Z"
    body["errorMessage"] = (
        '{"reason":"\\"Manual Process Termination\\"","code":"processManuallyTerminated",'
        '"details":""}'
    )
    status = status_from_body(RUN, body, NOW)
    assert status.status.value == "FAILED" and status.is_final
    assert status.aborted is True
    assert status.error == "Manual Process Termination"


def test_ordinary_failure_is_not_aborted():
    body = dict(SUSPENDED)
    body["errorMessage"] = '{"reason":"boom","code":"error","details":""}'
    assert status_from_body(RUN, body, NOW).aborted is False
