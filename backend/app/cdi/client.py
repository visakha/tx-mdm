"""CdiClient: every Informatica call the CDI side makes. No state beyond its session."""

from dataclasses import dataclass, field
from datetime import datetime
from typing import Any

from app.cdi import endpoints as ep
from app.cdi.models import CdiRunHandle, CdiTask, CdiTaskType
from app.common.idmc_session import IdmcHttp
from app.common.runs import RunCounts, RunStatus


@dataclass
class CdiRunSnapshot:
    """One look at a run, already translated to our RunStatus."""

    status: RunStatus
    note: str
    counts: RunCounts = field(default_factory=RunCounts)
    errors: list[str] = field(default_factory=list)
    started_at: datetime | None = None
    ended_at: datetime | None = None


class CdiClient:
    def __init__(self, http: IdmcHttp, platform_url_override: str = "") -> None:
        self._http = http
        self._platform_url_override = platform_url_override.rstrip("/")

    # ---- hosts -------------------------------------------------------------------------------

    def platform_url(self) -> str:
        """baseApiUrl from the v3 login, e.g. https://usw1.dm1-us.informaticacloud.com/saas.

        UNVERIFIED on Vamsi's org: that the same URL serves the v2 /api/v2 calls.
        """
        return self._platform_url_override or self._http.session.current().base_api_url.rstrip("/")

    def pod_url(self) -> str:
        url = self.platform_url()
        return url[: -len("/saas")] if url.endswith("/saas") else url

    # ---- list --------------------------------------------------------------------------------

    def list_tasks(self, task_types: list[CdiTaskType]) -> list[CdiTask]:
        tasks: list[CdiTask] = []
        for task_type in task_types:
            tasks.extend(self._list_type(task_type))
        return sorted(tasks, key=lambda t: t.path.lower())

    def _list_type(self, task_type: CdiTaskType) -> list[CdiTask]:
        found: list[CdiTask] = []
        skip = 0
        while True:
            body = self._http.request(
                "GET",
                self.platform_url() + ep.OBJECTS,
                ep.V3_HEADERS,
                params={"q": f"type=='{task_type.value}'", "limit": ep.PAGE_SIZE, "skip": skip},
            )
            objects = (body or {}).get("objects", [])
            found.extend(to_cdi_task(obj, task_type) for obj in objects)
            # `count` can lag by up to 90s on big orgs, so page until a short page instead.
            if len(objects) < ep.PAGE_SIZE:
                return found
            skip += ep.PAGE_SIZE

    # ---- run ---------------------------------------------------------------------------------

    def start(self, task_id: str, task_type: CdiTaskType, api_name: str | None) -> CdiRunHandle:
        match task_type:
            case CdiTaskType.MTT | CdiTaskType.WORKFLOW:
                body = self._http.request(
                    "POST",
                    self.platform_url() + ep.JOB_RUN,
                    ep.V2_HEADERS,
                    json={"@type": "job", "taskFederatedId": task_id, "taskType": task_type.value},
                )
                return CdiRunHandle(
                    task_type=task_type, run_id=str(body["runId"]), v2_task_id=body.get("taskId")
                )
            case CdiTaskType.TASKFLOW:
                if not api_name:
                    raise ValueError("advanced taskflow needs its published API name")
                body = self._http.request(
                    "POST",
                    self.pod_url() + ep.TASKFLOW_RUN.format(api_name=api_name),
                    ep.V3_HEADERS,
                    json={},
                )
                # UNVERIFIED: exact casing of the run id field in the rt response.
                run_id = body.get("RunId") or body.get("runId")
                if run_id is None:
                    raise ValueError("taskflow run response had no run id")
                return CdiRunHandle(task_type=task_type, run_id=str(run_id))

    # ---- monitor -----------------------------------------------------------------------------

    def check(self, handle: CdiRunHandle) -> CdiRunSnapshot:
        match handle.task_type:
            case CdiTaskType.MTT | CdiTaskType.WORKFLOW:
                return self._check_v2(handle)
            case CdiTaskType.TASKFLOW:
                body = self._http.request(
                    "GET",
                    self.pod_url() + ep.TASKFLOW_STATUS.format(run_id=handle.run_id),
                    ep.V3_HEADERS,
                )
                return snapshot_from_taskflow_status(body or {})

    def _check_v2(self, handle: CdiRunHandle) -> CdiRunSnapshot:
        monitor = self._http.request(
            "GET",
            self.platform_url() + ep.ACTIVITY_MONITOR,
            ep.V2_HEADERS,
            params={"details": "false"},
        )
        running = find_monitor_entry(monitor or [], handle.run_id, handle.v2_task_id)
        if running is not None:
            return snapshot_from_monitor(running)
        if handle.v2_task_id is None:
            return CdiRunSnapshot(RunStatus.UNKNOWN, "No taskId returned by the run call")
        log = self._http.request(
            "GET",
            self.platform_url() + ep.ACTIVITY_LOG,
            ep.V2_HEADERS,
            params={"runId": handle.run_id, "taskId": handle.v2_task_id},
        )
        entries = log if isinstance(log, list) else []
        if not entries:
            return CdiRunSnapshot(RunStatus.RUNNING, "Left the monitor; waiting for activity log")
        return snapshot_from_activity_log(entries[0])


# ---- pure translation functions (unit tested) ------------------------------------------------


def to_cdi_task(obj: dict[str, Any], task_type: CdiTaskType) -> CdiTask:
    path = str(obj.get("path", ""))
    name = path.rsplit("/", 1)[-1] if path else str(obj.get("id"))
    return CdiTask(
        id=str(obj["id"]),
        name=name,
        path=path,
        type=task_type,
        description=str(obj.get("description") or ""),
        updated_at=obj.get("updateTime"),
    )


def find_monitor_entry(
    entries: list[dict[str, Any]], run_id: str, task_id: str | None
) -> dict[str, Any] | None:
    for entry in entries:
        same_run = str(entry.get("runId")) == run_id
        same_task = task_id is None or entry.get("taskId") == task_id
        if same_run and same_task:
            return entry
    return None


MONITOR_STATES: dict[str, RunStatus] = {
    "QUEUED": RunStatus.QUEUED,
    "INITIALIZED": RunStatus.RUNNING,
    "RUNNING": RunStatus.RUNNING,
    "STOPPING": RunStatus.RUNNING,
}

ACTIVITY_LOG_STATES: dict[int, RunStatus] = {
    1: RunStatus.SUCCESS,
    2: RunStatus.WARNING,  # completed with errors
    3: RunStatus.FAILED,
}

TASKFLOW_STATES: dict[str, RunStatus] = {
    "RUNNING": RunStatus.RUNNING,
    "SUCCESS": RunStatus.SUCCESS,
    "FAILED": RunStatus.FAILED,
    "SUSPENDED": RunStatus.STOPPED,
}


def _counts(entry: dict[str, Any]) -> RunCounts:
    return RunCounts(
        source_success=entry.get("successSourceRows"),
        source_failed=entry.get("failedSourceRows"),
        target_success=entry.get("successTargetRows"),
        target_failed=entry.get("failedTargetRows"),
    )


def snapshot_from_monitor(entry: dict[str, Any]) -> CdiRunSnapshot:
    state = str(entry.get("executionState", ""))
    return CdiRunSnapshot(
        status=MONITOR_STATES.get(state, RunStatus.RUNNING),
        note=f"Activity monitor: {state or 'running'}",
        counts=_counts(entry),
        started_at=entry.get("startTimeUtc") or None,
    )


def snapshot_from_activity_log(entry: dict[str, Any]) -> CdiRunSnapshot:
    status = ACTIVITY_LOG_STATES.get(int(entry.get("state", 0)), RunStatus.UNKNOWN)
    if entry.get("isStopped"):
        status = RunStatus.STOPPED
    error = str(entry.get("errorMsg") or "")
    return CdiRunSnapshot(
        status=status,
        note=f"Activity log: {status.value}",
        counts=_counts(entry),
        errors=[error] if error else [],
        started_at=entry.get("startTimeUtc") or None,
        ended_at=entry.get("endTimeUtc"),
    )


def snapshot_from_taskflow_status(body: dict[str, Any]) -> CdiRunSnapshot:
    state = str(body.get("status", ""))
    error = str(body.get("errorMessage") or "")
    return CdiRunSnapshot(
        status=TASKFLOW_STATES.get(state, RunStatus.UNKNOWN),
        note=f"Taskflow status: {state or 'unknown'}",
        errors=[error] if error else [],
        ended_at=body.get("endTime") or None,
    )
