"""CDI monitoring: running jobs + recent history, normalized for the Monitor tab.

Sources (IICS REST API Reference, platform v2, header icSessionId, host = baseApiUrl as-is):
- Running jobs:  GET /api/v2/activity/activityMonitor?details=true
  fields used: taskId, taskName, objectName (source object, NOT the task), type, runId,
  startTimeUtc, executionState (QUEUED / INITIALIZED / RUNNING / STOPPING / FAILED),
  success/failed source/target rows, errorMsg, startedBy, runContextType, entries (children).
- Finished jobs: GET /api/v2/activity/activityLog?rowLimit=N
  fields used: objectId (task id), objectName (task name), type, runId, startTimeUtc,
  endTimeUtc, state (1 success, 2 completed with errors, 3 failed, 4 not started - children
  only), isStopped, success/failed source/target rows, errorMsg, startedBy, runContextType,
  entries (children).

Field names VERIFIED against the published IICS REST API Reference (Nov 2025 copy in
internal-docs/CDI_job_API_reference.md, re-checked against the July 2025 and July 2021 PDFs).
UNVERIFIED on Vamsi's org:
- whether advanced taskflows (type TASKFLOW) appear in activityMonitor / activityLog at all,
  and with which `type` value. Their mapping-task steps do appear as MTT rows.
- whether child `entries` carry useful names for taskflow steps.
Everything here is pure translation and is unit tested.
"""

from datetime import UTC, datetime
from typing import Any

from pydantic import BaseModel, Field

from app.common.runs import RunCounts, RunStatus, RunView

# executionState from activityMonitor (job still listed as running)
MONITOR_STATES: dict[str, RunStatus] = {
    "QUEUED": RunStatus.QUEUED,
    "INITIALIZED": RunStatus.RUNNING,
    "RUNNING": RunStatus.RUNNING,
    "STOPPING": RunStatus.RUNNING,
    "FAILED": RunStatus.FAILED,  # only for linear-taskflow subtasks
    "COMPLETE": RunStatus.SUCCESS,  # seen in the doc's XML sample
}

# state from activityLog (finished job)
LOG_STATES: dict[int, tuple[RunStatus, str]] = {
    1: (RunStatus.SUCCESS, "SUCCESS"),
    2: (RunStatus.WARNING, "COMPLETED_WITH_ERRORS"),
    3: (RunStatus.FAILED, "FAILED"),
    4: (RunStatus.UNKNOWN, "NOT_STARTED"),
}


class MonitorEntry(BaseModel):
    """One job run (or one child step of a taskflow) as the Monitor tab shows it."""

    task_name: str
    task_type: str = Field(description="IDMC type code, e.g. MTT, WORKFLOW, TASKFLOW.")
    run_id: str | None = None
    status: RunStatus
    state_text: str = Field(description="IDMC's own state word, e.g. RUNNING, FAILED.")
    started_at: datetime | None = None
    ended_at: datetime | None = None
    elapsed_minutes: float | None = Field(
        default=None,
        description="Running: start -> now. Finished: start -> end. Rounded to 0.1.",
    )
    counts: RunCounts = Field(default_factory=RunCounts)
    error: str = ""
    started_by: str = ""
    run_context: str = Field(default="", description="UI, SCHEDULER, REST-API, ...")
    in_my_tasks: bool = Field(
        default=False, description="True when task_name is in the org task list."
    )
    children: list["MonitorEntry"] = Field(default_factory=list)


class MonitorSnapshot(BaseModel):
    as_of: datetime
    running: list[MonitorEntry]
    recent: list[MonitorEntry]
    app_runs: list[RunView] = Field(description="CDI runs started from this backend.")
    my_task_count: int = Field(description="How many tasks are in the org task list.")
    notes: list[str] = Field(
        default_factory=list, description="Partial problems, e.g. history call failed."
    )


# ---- helpers ---------------------------------------------------------------------------------


def parse_time(value: Any) -> datetime | None:
    """IDMC *Utc fields look like 2026-11-22T12:05:56.000Z. Anything unparsable -> None."""
    if not value or not isinstance(value, str):
        return None
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None
    return parsed if parsed.tzinfo is not None else parsed.replace(tzinfo=UTC)


def minutes_between(start: datetime | None, end: datetime | None) -> float | None:
    if start is None or end is None:
        return None
    return round(max((end - start).total_seconds(), 0.0) / 60.0, 1)


def _int_or_none(value: Any) -> int | None:
    try:
        return None if value is None else int(value)
    except (TypeError, ValueError):
        return None


def _counts(entry: dict[str, Any]) -> RunCounts:
    return RunCounts(
        source_success=_int_or_none(entry.get("successSourceRows")),
        source_failed=_int_or_none(entry.get("failedSourceRows")),
        target_success=_int_or_none(entry.get("successTargetRows")),
        target_failed=_int_or_none(entry.get("failedTargetRows")),
    )


def _text(entry: dict[str, Any], key: str) -> str:
    value = entry.get(key)
    return "" if value is None else str(value)


def _error(entry: dict[str, Any]) -> str:
    message = _text(entry, "errorMsg").strip()
    # IDMC fills errorMsg with this on clean runs; it is not an error.
    return "" if message.lower() in {"", "no errors encountered."} else message


def _children(entry: dict[str, Any]) -> list[dict[str, Any]]:
    raw = entry.get("entries")
    return [c for c in raw if isinstance(c, dict)] if isinstance(raw, list) else []


# ---- translation -----------------------------------------------------------------------------


def entry_from_monitor(entry: dict[str, Any], now: datetime, my_tasks: set[str]) -> MonitorEntry:
    """activityMonitor row -> MonitorEntry. The task name is taskName (objectName is the source)."""
    state = _text(entry, "executionState").upper()
    started = parse_time(entry.get("startTimeUtc"))
    status = MONITOR_STATES.get(state, RunStatus.RUNNING)
    ended = parse_time(entry.get("endTimeUtc")) if status.is_terminal else None
    name = _text(entry, "taskName") or _text(entry, "objectName") or "(unnamed)"
    return MonitorEntry(
        task_name=name,
        task_type=_text(entry, "type"),
        run_id=_text(entry, "runId") or None,
        status=status,
        state_text=state or "RUNNING",
        started_at=started,
        ended_at=ended,
        elapsed_minutes=minutes_between(started, ended or now),
        counts=_counts(entry),
        error=_error(entry),
        started_by=_text(entry, "startedBy"),
        run_context=_text(entry, "runContextType"),
        in_my_tasks=name in my_tasks,
        children=[entry_from_monitor(c, now, my_tasks) for c in _children(entry)],
    )


def entry_from_log(entry: dict[str, Any], my_tasks: set[str]) -> MonitorEntry:
    """activityLog row -> MonitorEntry. Here objectName IS the task name."""
    status, state_text = LOG_STATES.get(
        _int_or_none(entry.get("state")) or 0, (RunStatus.UNKNOWN, "UNKNOWN")
    )
    if entry.get("isStopped") is True:
        status, state_text = RunStatus.STOPPED, "STOPPED"
    started = parse_time(entry.get("startTimeUtc"))
    ended = parse_time(entry.get("endTimeUtc"))
    name = _text(entry, "objectName") or _text(entry, "taskName") or "(unnamed)"
    return MonitorEntry(
        task_name=name,
        task_type=_text(entry, "type"),
        run_id=_text(entry, "runId") or None,
        status=status,
        state_text=state_text,
        started_at=started,
        ended_at=ended,
        elapsed_minutes=minutes_between(started, ended),
        counts=_counts(entry),
        error=_error(entry),
        started_by=_text(entry, "startedBy"),
        run_context=_text(entry, "runContextType"),
        in_my_tasks=name in my_tasks,
        children=[entry_from_log(c, my_tasks) for c in _children(entry)],
    )


def keep(entry: MonitorEntry, only_my_tasks: bool) -> bool:
    """With only_my_tasks, keep a row if it or any child step is one of the org's tasks."""
    if not only_my_tasks:
        return True
    return entry.in_my_tasks or any(keep(c, True) for c in entry.children)
