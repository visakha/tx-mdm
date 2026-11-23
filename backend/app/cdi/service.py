"""CdiService: ties the client to the run registry. Polling is driven by the UI's GET calls."""

from app.cdi.client import CdiClient
from app.cdi.models import CdiRunHandle, CdiRunRequest, CdiTask, CdiTaskType
from app.common.idmc_session import IdmcError
from app.common.runs import RunRegistry, RunStatus, RunView


class CdiService:
    def __init__(self, client: CdiClient, registry: RunRegistry) -> None:
        self._client = client
        self._registry = registry
        self._handles: dict[str, CdiRunHandle] = {}

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
        for error in snapshot.errors:
            if error not in run.errors:
                run.errors.append(error)
        self._registry.update_status(run, snapshot.status, snapshot.note)
        if snapshot.ended_at is not None and snapshot.status.is_terminal:
            run.ended_at = snapshot.ended_at
        return run

    def list_runs(self) -> list[RunView]:
        return self._registry.list_runs()
