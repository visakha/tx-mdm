"""CdiService: ties the client to the run registry. Polling is driven by the UI's GET calls."""

import time

from app.cdi.client import CdiClient
from app.cdi.endpoints import TERMINATE_MAX_IDS
from app.cdi.models import CdiRunHandle, CdiRunRequest, CdiTask, CdiTaskType
from app.cdi.monitor import (
    MonitorEntry,
    MonitorSnapshot,
    entry_from_log,
    entry_from_monitor,
    keep,
)
from app.cdi.taskflow_runs import (
    SubtaskRun,
    TaskflowRunStatus,
    TaskflowStartResult,
    TerminateResult,
    find_log_entry,
    log_text,
    status_from_body,
    totals_of,
    with_log_details,
)
from app.common.idmc_session import IdmcError, IdmcRateLimitedError
from app.common.runs import RunRegistry, RunStatus, RunView, now_utc

TASK_NAME_CACHE_SECONDS = 300  # the Monitor tab refreshes often; the task list rarely changes
LOG_LOOKUP_ROWS = 200  # activityLog rows searched for a child task's entry (max 1000)


class TaskflowNotFoundError(Exception):
    """No advanced taskflow with that exact name in the org task list."""


class TaskflowStartError(Exception):
    """IDMC refused the start call. status_code is IDMC's (e.g. 403)."""

    def __init__(self, status_code: int, message: str) -> None:
        super().__init__(message)
        self.status_code = status_code


class TerminateError(Exception):
    """IDMC refused the terminate call (500 = a run id is not valid / not running)."""

    def __init__(self, status_code: int, message: str) -> None:
        super().__init__(message)
        self.status_code = status_code


class SessionLogNotFoundError(Exception):
    """No activity log entry (yet) for the requested child task."""


ALLOWED_USERS_HINT = (
    " Hint: add the user to the taskflow Start step > Allowed Users EXACTLY as IDMC spells it "
    "in this message (case-sensitive), save, publish again."
)


class CdiService:
    def __init__(self, client: CdiClient, registry: RunRegistry) -> None:
        self._client = client
        self._registry = registry
        self._handles: dict[str, CdiRunHandle] = {}
        self._task_names: set[str] = set()
        self._task_names_at = 0.0
        self._final_status: dict[str, TaskflowRunStatus] = {}  # final runs never change

    def list_tasks(self, task_types: list[CdiTaskType]) -> list[CdiTask]:
        return self._client.list_tasks(task_types)

    def start(self, request: CdiRunRequest) -> RunView:
        run = self._registry.reserve(request.task_id, request.task_name, request.task_type.value)
        api_name = request.api_name or request.task_name
        try:
            handle = self._client.start(
                request.task_id, request.task_type, api_name, request.parameters
            )
        except (IdmcError, ValueError, KeyError) as exc:
            # The run did not start. We record the failure and do NOT retry.
            self._registry.fail(run, str(exc))
            return run
        self._handles[run.run_key] = handle
        note = f"Accepted by IDMC, runId {handle.run_id}"
        self._registry.update_status(run, RunStatus.QUEUED, note)
        return run

    def refresh(self, run_key: str) -> RunView:
        run = self._registry.get(run_key)
        handle = self._handles.get(run_key)
        if handle is None or run.status.is_terminal:
            return run
        snapshot = self._client.check(handle)
        run.counts = snapshot.counts
        if snapshot.started_at is not None:
            run.idmc_started_at = snapshot.started_at
        for error in snapshot.errors:
            if error not in run.errors:
                run.errors.append(error)
        self._registry.update_status(run, snapshot.status, snapshot.note)
        if snapshot.ended_at is not None and snapshot.status.is_terminal:
            run.ended_at = snapshot.ended_at
        return run

    def list_runs(self) -> list[RunView]:
        return self._registry.list_runs()

    # ---- Monitor tab -------------------------------------------------------------------------

    def monitor(self, row_limit: int, only_my_tasks: bool) -> MonitorSnapshot:
        """Running + recent CDI jobs. Read-only: never starts, stops or retries anything.

        A 429 is a hard stop and propagates. Any other IDMC error in one section is reported
        in `notes` so the other section still shows.
        """
        notes: list[str] = []
        names = self._my_task_names(notes)
        now = now_utc()

        running: list[MonitorEntry] = []
        try:
            running = [entry_from_monitor(e, now, names) for e in self._client.running_jobs()]
        except IdmcRateLimitedError:
            raise
        except IdmcError as exc:
            notes.append(f"Running jobs unavailable: {exc}")

        recent: list[MonitorEntry] = []
        try:
            recent = [entry_from_log(e, names) for e in self._client.recent_jobs(row_limit)]
        except IdmcRateLimitedError:
            raise
        except IdmcError as exc:
            notes.append(f"Job history unavailable: {exc}")

        # If the task list could not be loaded, filtering would hide everything: show all.
        only_mine = only_my_tasks and bool(names)
        return MonitorSnapshot(
            as_of=now,
            running=[e for e in running if keep(e, only_mine)],
            recent=[e for e in recent if keep(e, only_mine)],
            app_runs=self._registry.list_runs(),
            my_task_count=len(names),
            notes=notes,
        )

    def _my_task_names(self, notes: list[str]) -> set[str]:
        fresh = time.monotonic() - self._task_names_at < TASK_NAME_CACHE_SECONDS
        if self._task_names and fresh:
            return self._task_names
        try:
            tasks = self._client.list_tasks(list(CdiTaskType))
        except IdmcRateLimitedError:
            raise
        except IdmcError as exc:
            notes.append(f"Task list unavailable, showing all jobs: {exc}")
            return self._task_names
        self._task_names = {t.name for t in tasks}
        self._task_names_at = time.monotonic()
        return self._task_names

    # ---- taskflows by name / by IDMC run id ----------------------------------------------------

    def start_taskflow_by_name(
        self, name: str, api_name: str | None, parameters: dict[str, str] | None = None
    ) -> TaskflowStartResult:
        """Start one advanced taskflow by its exact name. Never retries a failed start."""
        taskflows = self._client.list_tasks([CdiTaskType.TASKFLOW])
        task = next((t for t in taskflows if t.name == name), None)
        if task is None:
            close = [t.name for t in taskflows if t.name.lower() == name.lower()]
            hint = f" Did you mean {close[0]}?" if close else ""
            known = ", ".join(sorted(t.name for t in taskflows)[:20])
            raise TaskflowNotFoundError(f"No taskflow named {name}.{hint} Known: {known}")
        api = api_name or task.name
        run = self._registry.reserve(task.id, task.name, CdiTaskType.TASKFLOW.value)
        try:
            handle = self._client.start(task.id, CdiTaskType.TASKFLOW, api, parameters)
        except IdmcRateLimitedError:
            self._registry.fail(run, "rate limited by Informatica")
            raise
        except IdmcError as exc:
            self._registry.fail(run, str(exc))
            hint = ALLOWED_USERS_HINT if exc.status_code == 403 else ""
            raise TaskflowStartError(exc.status_code, str(exc) + hint) from exc
        except (ValueError, KeyError) as exc:
            self._registry.fail(run, str(exc))
            raise TaskflowStartError(502, str(exc)) from exc
        self._handles[run.run_key] = handle
        self._registry.update_status(
            run, RunStatus.QUEUED, f"Accepted by IDMC, runId {handle.run_id}"
        )
        return TaskflowStartResult(
            run_id=handle.run_id,
            taskflow_name=task.name,
            task_id=task.id,
            api_name=api,
            run_key=run.run_key,
            requested_at=run.started_at,
            status_path=f"/api/cdi/taskflows/runs/{handle.run_id}",
            parameters=dict(parameters or {}),
        )

    def taskflow_run_status(self, run_id: str, details: bool) -> TaskflowRunStatus:
        """Status of any taskflow run by IDMC run id (works after a backend restart too).

        details=True adds, once the run is final, the source/target row split and the
        activity log id (for the session log) of each child task: one extra activityLog call.
        Final answers are cached, so polling a finished run costs no IDMC calls.
        """
        cached = self._final_status.get(run_id)
        if cached is not None and (cached.notes or not details or _has_details(cached)):
            self._close_registry_run(cached)
            return cached
        status = status_from_body(run_id, self._client.taskflow_status(run_id), now_utc())
        if status.is_final and details and status.subtasks:
            status = self._add_log_details(status)
        if status.is_final:
            self._final_status[run_id] = status
            self._close_registry_run(status)
        return status

    def terminate_taskflows(self, run_ids: list[str]) -> TerminateResult:
        """Abort taskflow runs by IDMC run id. One call, never retried."""
        ids = list(dict.fromkeys(i.strip() for i in run_ids if i.strip()))
        if not ids:
            raise ValueError("No run id given.")
        if len(ids) > TERMINATE_MAX_IDS:
            raise ValueError(f"At most {TERMINATE_MAX_IDS} run ids per call (got {len(ids)}).")
        try:
            self._client.terminate_taskflows(ids)
        except IdmcRateLimitedError:
            raise
        except IdmcError as exc:
            hint = (
                " IDMC answers 500 when a run id is not valid or the run is no longer active."
                if exc.status_code == 500
                else ""
            )
            raise TerminateError(exc.status_code, f"Terminate refused: {exc}{hint}") from exc
        for run_id in ids:
            self._final_status.pop(run_id, None)
            for run_key, handle in self._handles.items():
                if handle.run_id != run_id:
                    continue
                run = self._registry.get(run_key)
                if not run.status.is_terminal:
                    self._registry.update_status(run, RunStatus.STOPPED, "Terminated via API")
        return TerminateResult(
            run_ids=ids,
            terminated=True,
            note="IDMC accepted the terminate (204). Poll the status to see it go final.",
        )

    def _close_registry_run(self, status: TaskflowRunStatus) -> None:
        """A run started here stays 'active' (409 on a second start) until it is seen final."""
        for run_key, handle in self._handles.items():
            if handle.run_id != status.run_id:
                continue
            run = self._registry.get(run_key)
            if not run.status.is_terminal:
                if status.error and status.error not in run.errors:
                    run.errors.append(status.error)
                run.ended_at = status.ended_at
                self._registry.update_status(run, status.status, f"IDMC: {status.state_text}")

    def _add_log_details(self, status: TaskflowRunStatus) -> TaskflowRunStatus:
        try:
            rows = self._client.recent_jobs(LOG_LOOKUP_ROWS)
        except IdmcRateLimitedError:
            raise
        except IdmcError as exc:
            return status.model_copy(update={"notes": [f"Activity log unavailable: {exc}"]})
        subtasks: list[SubtaskRun] = [
            with_log_details(s, find_log_entry(rows, s.name, s.run_id)) for s in status.subtasks
        ]
        notes = [
            f"{s.name}: no activity log row matched (name + run id {s.run_id}); "
            "source/target split and session log unavailable."
            for s in subtasks
            if s.log_entry_id is None
        ]
        return status.model_copy(
            update={"subtasks": subtasks, "totals": totals_of(subtasks), "notes": notes}
        )

    def taskflow_session_log(self, run_id: str, subtask: str | None) -> tuple[str, str]:
        """(child task name, session log text) for one child task of a finished taskflow run."""
        status = self.taskflow_run_status(run_id, details=True)
        candidates = [s for s in status.subtasks if subtask is None or s.name == subtask]
        if not candidates:
            names = ", ".join(s.name for s in status.subtasks) or "none"
            raise SessionLogNotFoundError(
                f"No child task {subtask} in run {run_id}. Children: {names}"
            )
        with_log = [s for s in candidates if s.log_entry_id is not None]
        if not with_log:
            raise SessionLogNotFoundError(
                f"No activity log entry yet for {candidates[0].name} in run {run_id} "
                "(still running, or not in the latest activity log rows)."
            )
        chosen = with_log[-1]
        content_type, content = self._client.session_log(str(chosen.log_entry_id))
        return chosen.name, log_text(content_type, content)


def _has_details(status: TaskflowRunStatus) -> bool:
    return all(s.log_entry_id is not None for s in status.subtasks)
