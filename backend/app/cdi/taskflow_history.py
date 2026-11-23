"""Run history of one taskflow for the Run tab's detail pane (0.9.1). Pure functions, tested.

Seen live 2026-11-23 (read-only, his org): activityMonitor / activityLog list the taskflow's
child mapping tasks (e.g. mt_m_MDM_ZLV_TTF_Guest_Basic_EGR) but NOT the taskflow itself. So
the history is built from:
  1. runs of this taskflow started from this backend - IDMC taskflow run id + live status
     (trackable: clicking opens Track run id);
  2. monitor rows whose task name IS the taskflow (trackable; none seen live so far);
  3. monitor rows of its child tasks (NOT trackable: their run_id is IDMC's per-task run
     number, not a taskflow run id). Child names come from taskflow statuses this backend
     has read; else (0.9.15) from IDMC's v3 references of the taskflow (refType=Uses, the
     documented dependency call, MTT rows); only when that call fails or lists no mapping
     task is the tf_ -> mt_m_ naming in his org used as a GUESS, and the pane says so.
"""

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field

from app.cdi.monitor import MonitorEntry, MonitorSnapshot, minutes_between
from app.cdi.taskflow_runs import TaskflowRunStatus
from app.common.runs import RunStatus, RunView

ACTIVE = {RunStatus.STARTING, RunStatus.QUEUED, RunStatus.RUNNING}


class HistoryRow(BaseModel):
    run_id: str | None = Field(description="Taskflow run id (trackable) or child run number.")
    level: Literal["taskflow", "child"]
    task_name: str
    task_type: str
    source: Literal["app", "monitor"] = Field(
        description="app = started from this backend; monitor = IDMC activity monitor / log."
    )
    trackable: bool = Field(description="True when run_id is a taskflow run id.")
    status: RunStatus
    state_text: str
    is_running: bool
    started_at: datetime | None = None
    ended_at: datetime | None = None
    elapsed_minutes: float | None = None
    rows_ok: int | None = Field(default=None, description="Source rows ok.")
    rows_failed: int | None = Field(default=None, description="Source + target rows failed.")
    error: str = ""
    started_by: str = ""
    portal_url: str | None = Field(
        default=None,
        description='0.9.15: taskflow rows only - IDMC portal page of the run ("Go to IDMC"): '
        "{cdi_pod_host}/diUI/products/integrationDesign/main/processinstance/{run_id}/"
        "{name}-{run_id}%7B%7D. UNVERIFIED-DOC (his browser). Built by app/common/portal.py.",
    )


class TaskflowHistory(BaseModel):
    taskflow_name: str
    as_of: datetime
    rows: list[HistoryRow]
    child_tasks: list[str] = Field(description="Child task names used to match monitor rows.")
    child_names_guessed: bool = Field(
        description="True when no taskflow status named the children and tf_ -> mt_m_ was used."
    )
    child_names_source: Literal["tracked run", "references", "guess", "none"] = Field(
        default="none",
        description="0.9.15: where child_tasks came from (references = v3 objects/<id>/references)",
    )
    taskflow_in_monitor: bool = Field(
        description="True when IDMC's monitor / log listed a row under the taskflow's own name."
    )
    notes: list[str] = Field(default_factory=list)


def guess_child(name: str) -> str | None:
    """His org's naming: tf_X runs mapping task mt_m_X. A guess, labelled as such."""
    return "mt_m_" + name.removeprefix("tf_") if name.startswith("tf_") else None


def _failed(entry: MonitorEntry) -> int | None:
    parts = [entry.counts.source_failed, entry.counts.target_failed]
    known = [p for p in parts if p is not None]
    return sum(known) if known else None


def _from_monitor(entry: MonitorEntry, level: Literal["taskflow", "child"]) -> HistoryRow:
    return HistoryRow(
        run_id=entry.run_id,
        level=level,
        task_name=entry.task_name,
        task_type=entry.task_type,
        source="monitor",
        trackable=level == "taskflow" and entry.run_id is not None,
        status=entry.status,
        state_text=entry.state_text,
        is_running=entry.status in ACTIVE,
        started_at=entry.started_at,
        ended_at=entry.ended_at,
        elapsed_minutes=entry.elapsed_minutes,
        rows_ok=entry.counts.source_success,
        rows_failed=_failed(entry),
        error=entry.error,
        started_by=entry.started_by,
    )


def _from_app(
    run_id: str, run: RunView, status: TaskflowRunStatus | None, now: datetime
) -> HistoryRow:
    if status is None:
        started = run.idmc_started_at or run.started_at
        end = run.ended_at
        return HistoryRow(
            run_id=run_id,
            level="taskflow",
            task_name=run.job_name,
            task_type="TASKFLOW",
            source="app",
            trackable=True,
            status=run.status,
            state_text=run.status.value,
            is_running=run.status in ACTIVE,
            started_at=started,
            ended_at=end,
            elapsed_minutes=minutes_between(started, end or now),
            error="; ".join(run.errors),
        )
    totals = status.totals
    has_rows = bool(status.subtasks)
    return HistoryRow(
        run_id=run_id,
        level="taskflow",
        task_name=status.taskflow_name or run.job_name,
        task_type="TASKFLOW",
        source="app",
        trackable=True,
        status=status.status,
        state_text="ABORTED" if status.aborted else status.state_text,
        is_running=not status.is_final,
        started_at=status.started_at or run.started_at,
        ended_at=status.ended_at,
        elapsed_minutes=status.elapsed_minutes,
        rows_ok=totals.source_success if has_rows else None,
        rows_failed=(totals.source_failed + totals.target_failed) if has_rows else None,
        error=status.error,
        started_by=status.started_by,
    )


def _sort_key(row: HistoryRow) -> tuple[int, float]:
    started = row.started_at.timestamp() if row.started_at is not None else 0.0
    return (0 if row.is_running else 1, -started)


def build_history(
    name: str,
    snapshot: MonitorSnapshot,
    app_runs: list[tuple[str, RunView, TaskflowRunStatus | None]],
    known_children: set[str],
    notes: list[str],
    now: datetime,
    referenced_children: set[str] | None = None,
) -> TaskflowHistory:
    children = set(known_children)
    guessed = False
    source: Literal["tracked run", "references", "guess", "none"] = "none"
    if children:
        source = "tracked run"
    elif referenced_children:
        children = set(referenced_children)
        source = "references"
    else:
        guess = guess_child(name)
        if guess is not None:
            children = {guess}
            guessed = True
            source = "guess"
    rows = [_from_app(run_id, run, status, now) for run_id, run, status in app_runs]
    seen_ids = {r.run_id for r in rows}
    in_monitor = False
    for entry in [*snapshot.running, *snapshot.recent]:
        if entry.task_name == name:
            in_monitor = True
            if entry.run_id not in seen_ids:
                rows.append(_from_monitor(entry, "taskflow"))
                seen_ids.add(entry.run_id)
        elif entry.task_name in children:
            rows.append(_from_monitor(entry, "child"))
    out_notes = list(notes) + list(snapshot.notes)
    if not in_monitor:
        out_notes.append(
            "IDMC's activity monitor / log list this taskflow's child tasks, not the taskflow "
            "itself. Taskflow rows (clickable) are runs started from this app; child task rows "
            "show the mapping task's own run number and cannot be tracked as a taskflow run."
        )
    if guessed:
        out_notes.append(
            f"Child task {sorted(children)[0]} is a guess from the tf_ -> mt_m_ naming (IDMC's "
            "references call gave no mapping task); it is confirmed once a run of this "
            "taskflow has been tracked here."
        )
    return TaskflowHistory(
        taskflow_name=name,
        as_of=now,
        rows=sorted(rows, key=_sort_key),
        child_tasks=sorted(children),
        child_names_guessed=guessed,
        child_names_source=source,
        taskflow_in_monitor=in_monitor,
        notes=out_notes,
    )
