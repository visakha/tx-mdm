"""Advanced taskflow runs looked up by IDMC run id: status, summary per child task, session log.

Sources (all read-only):
- Taskflow status: GET {pod}/active-bpel/services/tf/status/{runId}?subtaskDetails=Yes
  header INFA-SESSION-ID, Accept application/json.
  VERIFIED field names (Informatica "Monitoring taskflow status with the status resource",
  developer.informatica.com, updated 2025-09-30): assetName, assetType, duration (seconds),
  startTime, endTime, updateTime (UTC), errorMessage, location, runId, startedBy, status
  (RUNNING / SUCCESS / FAILED / SUSPENDED), subtasks (count), and
  subtaskDetails.details.tasks[] with assetName, assetType (MTT / DSS / ...), duration,
  startTime, endTime, errorMessage, errorRows, rowsProcessed, successRows, runId, location,
  startedBy, status (QUEUED / STARTING / RUNNING / COMPLETED / STOPPED / WARNING / FAILED).
  Numbers in tasks[] are often strings ("7"); we parse both.
  VERIFIED: since the April 2026 release subtask details come back only with
  subtaskDetails=Yes (Informatica KB "Change in behavior for Taskflow Status API").
  VERIFIED: purged runs answer {"status": "No status available."} with HTTP 200.
- Source / target row split per child task: GET {baseApiUrl}/api/v2/activity/activityLog?rowLimit=N
  (fields successSourceRows, failedSourceRows, successTargetRows, failedTargetRows, id, runId,
  objectName, entries[]). The activity log does NOT list advanced taskflows themselves
  (Informatica Network answer), but it does list their mapping-task steps.
  UNVERIFIED on Vamsi's org: that a tf-status subtask runId equals the activityLog runId of
  the same mapping task. We match on (task name, run id) and leave the split empty if no row
  matches.
- Session log: GET {baseApiUrl}/api/v2/activity/activityLog/{id}/sessionLog (VERIFIED path,
  IICS REST API Reference, activityLog resource). It can be a ZIP for linear taskflows; we
  unpack text members.
"""

import io
import json
import zipfile
from datetime import datetime
from typing import Any

from pydantic import BaseModel, Field

from app.cdi.monitor import minutes_between, parse_time
from app.common.runs import RunStatus

# Taskflow-level status words (VERIFIED list).
TASKFLOW_STATES: dict[str, RunStatus] = {
    "RUNNING": RunStatus.RUNNING,
    "SUCCESS": RunStatus.SUCCESS,
    "FAILED": RunStatus.FAILED,
    "SUSPENDED": RunStatus.STOPPED,
}

# Subtask status words (VERIFIED list).
SUBTASK_STATES: dict[str, RunStatus] = {
    "QUEUED": RunStatus.QUEUED,
    "STARTING": RunStatus.STARTING,
    "RUNNING": RunStatus.RUNNING,
    "COMPLETED": RunStatus.SUCCESS,
    "SUCCESS": RunStatus.SUCCESS,
    "STOPPED": RunStatus.STOPPED,
    "WARNING": RunStatus.WARNING,
    "FAILED": RunStatus.FAILED,
}

PURGED_TEXT = "no status available."


class RowSplit(BaseModel):
    """Source / target split from the activity log. None = not reported / not matched."""

    source_success: int | None = None
    source_failed: int | None = None
    target_success: int | None = None
    target_failed: int | None = None


class SubtaskRun(BaseModel):
    """One child task of the taskflow run (usually a mapping task)."""

    name: str
    type: str = Field(description="IDMC assetType, e.g. MTT.")
    run_id: str | None = None
    status: RunStatus
    state_text: str = Field(description="IDMC's own word, e.g. COMPLETED, FAILED.")
    started_at: datetime | None = None
    ended_at: datetime | None = None
    elapsed_minutes: float | None = None
    rows_processed: int | None = None
    success_rows: int | None = None
    error_rows: int | None = None
    rows: RowSplit = Field(default_factory=RowSplit, description="From the activity log.")
    error: str = ""
    location: str = ""
    log_entry_id: str | None = Field(
        default=None, description="activityLog id; set when a session log can be fetched."
    )


class RunTotals(BaseModel):
    rows_processed: int = 0
    success_rows: int = 0
    error_rows: int = 0
    source_success: int = 0
    source_failed: int = 0
    target_success: int = 0
    target_failed: int = 0


class TaskflowRunStatus(BaseModel):
    """Answer of GET /api/cdi/taskflows/runs/{run_id}."""

    run_id: str
    taskflow_name: str
    location: str = ""
    status: RunStatus = Field(description="RUNNING until final: SUCCESS, FAILED or STOPPED.")
    state_text: str = Field(description="IDMC's own word, e.g. RUNNING, SUSPENDED.")
    is_final: bool
    started_at: datetime | None = None
    ended_at: datetime | None = None
    updated_at: datetime | None = None
    elapsed_minutes: float | None = Field(
        default=None, description="Running: start -> now. Final: start -> end."
    )
    started_by: str = ""
    error: str = ""
    aborted: bool = Field(
        default=False,
        description="True when IDMC says the run was terminated by a person (code "
        "processManuallyTerminated). IDMC then reports status FAILED, not STOPPED.",
    )
    subtask_count: int | None = None
    subtasks: list[SubtaskRun] = Field(default_factory=list)
    totals: RunTotals = Field(default_factory=RunTotals)
    notes: list[str] = Field(default_factory=list)


class TaskflowStartResult(BaseModel):
    """Answer of POST /api/cdi/taskflows/{name}/run."""

    run_id: str = Field(description="IDMC run id. Pass it to GET /api/cdi/taskflows/runs/{run_id}.")
    taskflow_name: str
    task_id: str
    api_name: str
    run_key: str = Field(description="This backend's run key (also shown on the Monitor tab).")
    requested_at: datetime | None = None
    status_path: str
    parameters: dict[str, str] = Field(
        default_factory=dict, description="Input fields sent to the taskflow."
    )


class TaskflowRunRequest(BaseModel):
    api_name: str | None = Field(
        default=None, description="Published API name; defaults to the taskflow name."
    )
    parameters: dict[str, str] | None = Field(
        default=None,
        description="Start-step input fields, exact (case-sensitive) names, sent as the JSON "
        'body of the rt call. Example: {"jobInstanceId": "ABC123"}.',
        examples=[{"jobInstanceId": "ABC123"}],
    )


# ---- helpers ---------------------------------------------------------------------------------


def _int(value: Any) -> int | None:
    try:
        return None if value is None or value == "" else int(value)
    except (TypeError, ValueError):
        return None


def _text(entry: dict[str, Any], key: str) -> str:
    value = entry.get(key)
    return "" if value is None else str(value).strip()


def _subtask_rows(body: dict[str, Any]) -> list[dict[str, Any]]:
    details = body.get("subtaskDetails")
    inner = details.get("details") if isinstance(details, dict) else None
    tasks = inner.get("tasks") if isinstance(inner, dict) else None
    return [t for t in tasks if isinstance(t, dict)] if isinstance(tasks, list) else []


def _error(entry: dict[str, Any], key: str) -> str:
    message = _text(entry, key)
    if message.lower() in {"", "no errors encountered."}:
        return ""
    return _reason_of(message)


def _reason_of(message: str) -> str:
    """Seen live 2026-11-22: a SUSPENDED taskflow's errorMessage is a JSON string
    {"reason": "...", "code": "error", "details": "<packed ids>"}. Show only the reason."""
    if not message.startswith("{"):
        return message
    try:
        parsed = json.loads(message)
    except ValueError:
        return message
    reason = parsed.get("reason") if isinstance(parsed, dict) else None
    if not isinstance(reason, str):
        return message
    # Live abort reason arrives wrapped in its own quotes: "\"Manual Process Termination\"".
    reason = reason.strip().strip('"').strip()
    return reason if reason != "" else message


ABORTED_CODE = "processManuallyTerminated"


def _code_of(message: str) -> str:
    """The "code" of a JSON errorMessage, or "" when the message is plain text.

    Seen live 2026-11-22 23:21 CST after a terminate from the portal Monitor: reason
    "Manual Process Termination" (in extra quotes), code "processManuallyTerminated".
    """
    if not message.startswith("{"):
        return ""
    try:
        parsed = json.loads(message)
    except ValueError:
        return ""
    code = parsed.get("code") if isinstance(parsed, dict) else None
    return code if isinstance(code, str) else ""


# ---- translation (pure, unit tested) ---------------------------------------------------------


def subtask_from_status(entry: dict[str, Any], now: datetime) -> SubtaskRun:
    state = _text(entry, "status").upper()
    status = SUBTASK_STATES.get(state, RunStatus.UNKNOWN)
    started = parse_time(entry.get("startTime"))
    ended = parse_time(entry.get("endTime")) if status.is_terminal else None
    return SubtaskRun(
        name=_text(entry, "assetName") or "(unnamed)",
        type=_text(entry, "assetType"),
        run_id=_text(entry, "runId") or None,
        status=status,
        state_text=state or "UNKNOWN",
        started_at=started,
        ended_at=ended,
        elapsed_minutes=minutes_between(started, ended or now),
        rows_processed=_int(entry.get("rowsProcessed")),
        success_rows=_int(entry.get("successRows")),
        error_rows=_int(entry.get("errorRows")),
        error=_error(entry, "errorMessage"),
        location=_text(entry, "location"),
    )


def status_from_body(run_id: str, body: dict[str, Any], now: datetime) -> TaskflowRunStatus:
    state = _text(body, "status").upper()
    if state.lower() == PURGED_TEXT:
        return TaskflowRunStatus(
            run_id=run_id,
            taskflow_name="",
            status=RunStatus.UNKNOWN,
            state_text="NO_STATUS",
            is_final=False,
            notes=["IDMC has no status for this run id (unknown id, or its logs were purged)."],
        )
    status = TASKFLOW_STATES.get(state, RunStatus.UNKNOWN)
    started = parse_time(body.get("startTime"))
    updated = parse_time(body.get("updateTime"))
    ended = parse_time(body.get("endTime")) if status.is_terminal else None
    if status.is_terminal and ended is None:
        # Seen live 2026-11-22: a SUSPENDED run has no endTime; updateTime is when it stopped.
        ended = updated
    subtasks = [subtask_from_status(t, now) for t in _subtask_rows(body)]
    return TaskflowRunStatus(
        run_id=_text(body, "runId") or run_id,
        taskflow_name=_text(body, "assetName"),
        location=_text(body, "location"),
        status=status,
        state_text=state or "UNKNOWN",
        is_final=status.is_terminal,
        started_at=started,
        ended_at=ended,
        updated_at=updated,
        elapsed_minutes=minutes_between(started, ended or now),
        started_by=_text(body, "startedBy"),
        error=_error(body, "errorMessage"),
        aborted=_code_of(_text(body, "errorMessage")) == ABORTED_CODE,
        subtask_count=_int(body.get("subtasks")),
        subtasks=subtasks,
        totals=totals_of(subtasks),
    )


def find_log_entry(
    rows: list[dict[str, Any]], name: str, run_id: str | None
) -> dict[str, Any] | None:
    """Depth-first search of activityLog rows (and their child entries) for one task run."""
    for row in rows:
        same_name = _text(row, "objectName") == name or _text(row, "taskName") == name
        same_run = run_id is None or _text(row, "runId") == run_id
        if same_name and same_run and _text(row, "id"):
            return row
        children = row.get("entries")
        if isinstance(children, list):
            found = find_log_entry([c for c in children if isinstance(c, dict)], name, run_id)
            if found is not None:
                return found
    return None


def with_log_details(subtask: SubtaskRun, row: dict[str, Any] | None) -> SubtaskRun:
    if row is None:
        return subtask
    return subtask.model_copy(
        update={
            "log_entry_id": _text(row, "id") or None,
            "rows": RowSplit(
                source_success=_int(row.get("successSourceRows")),
                source_failed=_int(row.get("failedSourceRows")),
                target_success=_int(row.get("successTargetRows")),
                target_failed=_int(row.get("failedTargetRows")),
            ),
        }
    )


def totals_of(subtasks: list[SubtaskRun]) -> RunTotals:
    def total(values: list[int | None]) -> int:
        return sum(v for v in values if v is not None)

    return RunTotals(
        rows_processed=total([s.rows_processed for s in subtasks]),
        success_rows=total([s.success_rows for s in subtasks]),
        error_rows=total([s.error_rows for s in subtasks]),
        source_success=total([s.rows.source_success for s in subtasks]),
        source_failed=total([s.rows.source_failed for s in subtasks]),
        target_success=total([s.rows.target_success for s in subtasks]),
        target_failed=total([s.rows.target_failed for s in subtasks]),
    )


def log_text(content_type: str, content: bytes) -> str:
    """Session log bytes -> text. A ZIP (linear taskflows) is unpacked member by member."""
    if "zip" in content_type.lower() or content[:4] == b"PK\x03\x04":
        parts: list[str] = []
        with zipfile.ZipFile(io.BytesIO(content)) as archive:
            for member in archive.namelist():
                text = archive.read(member).decode("utf-8", errors="replace")
                parts.append(f"===== {member} =====\n{text}")
        return "\n".join(parts)
    return content.decode("utf-8", errors="replace")


class TerminateRequest(BaseModel):
    run_ids: list[str] = Field(
        default_factory=list, description="Extra run ids to terminate in the same call (max 200)."
    )


class TerminateResult(BaseModel):
    run_ids: list[str]
    terminated: bool
    note: str = ""
