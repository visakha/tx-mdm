"""Run history of one taskflow (Run tab detail pane, 0.9.1)."""

from datetime import UTC, datetime

from app.cdi.monitor import MonitorEntry, MonitorSnapshot
from app.cdi.taskflow_history import build_history, guess_child
from app.cdi.taskflow_runs import RunTotals, SubtaskRun, TaskflowRunStatus
from app.common.runs import RunCounts, RunStatus, RunView

NOW = datetime(2026, 11, 23, 6, 20, tzinfo=UTC)
TF = "tf_MDM_ZLV_TTF_Guest_Basic_EGR"
CHILD = "mt_m_MDM_ZLV_TTF_Guest_Basic_EGR"


def _entry(name: str, run_id: str, status: RunStatus, minute: int) -> MonitorEntry:
    return MonitorEntry(
        task_name=name,
        task_type="MTT",
        run_id=run_id,
        status=status,
        state_text=status.value,
        started_at=datetime(2026, 11, 23, 5, minute, tzinfo=UTC),
        counts=RunCounts(source_success=20, source_failed=0, target_success=0, target_failed=1),
    )


def _snapshot(running: list[MonitorEntry], recent: list[MonitorEntry]) -> MonitorSnapshot:
    return MonitorSnapshot(as_of=NOW, running=running, recent=recent, app_runs=[], my_task_count=15)


def test_guess_child_uses_tf_to_mt_m_naming():
    assert guess_child(TF) == CHILD
    assert guess_child("other") is None


def test_live_shape_child_rows_only_running_first_and_notes():
    """Seen live 2026-11-23: the monitor lists the child mapping task, not the taskflow."""
    snap = _snapshot(
        [_entry(CHILD, "9", RunStatus.RUNNING, 12)],
        [_entry(CHILD, "8", RunStatus.FAILED, 39), _entry("mt_other", "3", RunStatus.SUCCESS, 1)],
    )
    history = build_history(TF, snap, [], set(), [], NOW)
    assert [r.run_id for r in history.rows] == ["9", "8"]
    assert history.rows[0].is_running and not history.rows[0].trackable
    assert history.rows[1].rows_failed == 1
    assert history.child_names_guessed and not history.taskflow_in_monitor
    assert any("child tasks, not the taskflow" in n for n in history.notes)


def test_app_runs_are_trackable_and_use_taskflow_status():
    run = RunView(
        run_key="k1",
        service="cdi",
        job_name=TF,
        job_kind="TASKFLOW",
        status=RunStatus.QUEUED,
        started_at=datetime(2026, 11, 23, 6, 12, tzinfo=UTC),
    )
    status = TaskflowRunStatus(
        run_id="1309401025769136128",
        taskflow_name=TF,
        status=RunStatus.RUNNING,
        state_text="RUNNING",
        is_final=False,
        started_at=datetime(2026, 11, 23, 6, 12, tzinfo=UTC),
        elapsed_minutes=8.0,
        subtasks=[
            SubtaskRun(name=CHILD, type="MTT", status=RunStatus.RUNNING, state_text="RUNNING")
        ],
        totals=RunTotals(source_success=5),
    )
    snap = _snapshot([], [_entry(CHILD, "8", RunStatus.FAILED, 39)])
    history = build_history(TF, snap, [("1309401025769136128", run, status)], {CHILD}, [], NOW)
    top = history.rows[0]
    assert top.run_id == "1309401025769136128" and top.trackable and top.is_running
    assert top.source == "app" and top.rows_ok == 5
    assert not history.child_names_guessed
    assert history.rows[1].level == "child"


def test_history_endpoint_lists_parallel_app_runs(idmc, idmc_http):  # type: ignore[no-untyped-def]
    from tests.conftest import PLATFORM
    from tests.test_cdi_taskflow_runs import POD, RUN, SUSPENDED, _app

    idmc.get(f"{PLATFORM}/public/core/v3/objects").respond(
        200, json={"objects": [{"id": "FED9", "path": "ZL_Vamsi/tf_MDM_ZLV_TTF_Guest_Basic"}]}
    )
    idmc.post(f"{POD}/active-bpel/rt/tf_MDM_ZLV_TTF_Guest_Basic").respond(200, json={"RunId": RUN})
    idmc.get(f"{POD}/active-bpel/services/tf/status/{RUN}").respond(200, json=SUSPENDED)
    idmc.get(f"{PLATFORM}/api/v2/activity/activityMonitor").respond(200, json=[])
    idmc.get(f"{PLATFORM}/api/v2/activity/activityLog").respond(200, json=[])
    client = _app(idmc_http)
    assert (
        client.post(
            "/api/cdi/taskflows/tf_MDM_ZLV_TTF_Guest_Basic/run",
            json={"parameters": {"jobInstanceId": "J1"}},
        ).status_code
        == 200
    )
    body = client.get("/api/cdi/taskflows/tf_MDM_ZLV_TTF_Guest_Basic/history").json()
    assert body["rows"][0]["run_id"] == RUN
    assert body["rows"][0]["trackable"] is True
    assert body["child_tasks"] == ["mt_m_MDM_ZLV_TTF_Guest_Basic"]
    assert body["child_names_guessed"] is False
