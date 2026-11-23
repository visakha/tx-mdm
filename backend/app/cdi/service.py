"""CdiService: ties the client to the run registry. Polling is driven by the UI's GET calls."""

import time

from app.cdi.client import CdiClient
from app.cdi.models import CdiRunHandle, CdiRunRequest, CdiTask, CdiTaskType
from app.cdi.monitor import (
    MonitorEntry,
    MonitorSnapshot,
    entry_from_log,
    entry_from_monitor,
    keep,
)
from app.common.idmc_session import IdmcError, IdmcRateLimitedError
from app.common.runs import RunRegistry, RunStatus, RunView, now_utc

TASK_NAME_CACHE_SECONDS = 300  # the Monitor tab refreshes often; the task list rarely changes


class CdiService:
    def __init__(self, client: CdiClient, registry: RunRegistry) -> None:
        self._client = client
        self._registry = registry
        self._handles: dict[str, CdiRunHandle] = {}
        self._task_names: set[str] = set()
        self._task_names_at = 0.0

    def list_tasks(self, task_types: list[CdiTaskType]) -> list[CdiTask]:
        return self._client.list_tasks(task_types)

    def start(self, request: CdiRunRequest) -> RunView:
        run = self._registry.reserve(request.task_id, request.task_name, request.task_type.value)
        api_name = request.api_name or request.task_name
        try:
            handle = self._client.start(request.task_id, request.task_type, api_name)
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
