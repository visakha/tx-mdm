"""HTTP routes for CDI. Mounted at /api/cdi."""

from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query
from fastapi.responses import PlainTextResponse

from app.cdi.models import CdiRunRequest, CdiTask, CdiTaskType
from app.cdi.monitor import MonitorSnapshot
from app.cdi.service import (
    CdiService,
    SessionLogNotFoundError,
    TaskflowNotFoundError,
    TaskflowStartError,
)
from app.cdi.taskflow_runs import TaskflowRunRequest, TaskflowRunStatus, TaskflowStartResult
from app.common.runs import RunView
from app.dependencies import get_cdi_service

router = APIRouter(prefix="/api/cdi", tags=["cdi"])

Service = Annotated[CdiService, Depends(get_cdi_service)]


@router.get(
    "/tasks",
    operation_id="cdi_list_tasks",
    summary="List runnable CDI tasks",
    description="Mapping tasks (MTT), linear taskflows (WORKFLOW) and advanced taskflows "
    "(TASKFLOW) from the IDMC v3 objects query. `id` is the taskFederatedId used to run.",
)
def list_tasks(
    service: Service,
    types: Annotated[list[CdiTaskType] | None, Query()] = None,
) -> list[CdiTask]:
    return service.list_tasks(types or list(CdiTaskType))


@router.post(
    "/runs",
    operation_id="cdi_start_run",
    summary="Start one CDI task",
    description="Starts the task once. 409 if this task already has a run in progress. "
    "A failed start is returned as a FAILED run and is never retried.",
)
def start_run(request: CdiRunRequest, service: Service) -> RunView:
    return service.start(request)


@router.get(
    "/runs",
    operation_id="cdi_list_runs",
    summary="CDI runs started from this backend (newest first)",
)
def list_runs(service: Service) -> list[RunView]:
    return service.list_runs()


@router.get(
    "/runs/{run_key}",
    operation_id="cdi_get_run",
    summary="Refresh and return one CDI run",
    description="Checks IDMC (activity monitor, then activity log) and returns the run. "
    "Poll every few seconds until `status` is SUCCESS, WARNING, FAILED or STOPPED.",
)
def get_run(run_key: str, service: Service) -> RunView:
    return service.refresh(run_key)


@router.get(
    "/monitor",
    operation_id="cdi_monitor",
    summary="Monitor CDI jobs: running now + recent history",
    description="Read-only. Running jobs from IDMC activityMonitor (details=true, with child "
    "steps) and the newest finished jobs from activityLog. `elapsed_minutes` is start -> now "
    "for running jobs and start -> end for finished ones. With only_my_tasks=true (default) "
    "only jobs whose name is in the org task list (GET /api/cdi/tasks) are kept. Also returns "
    "the CDI runs started from this backend. Poll every 10-15 s; a 429 is a hard stop.",
)
def monitor(
    service: Service,
    row_limit: Annotated[int, Query(ge=1, le=1000)] = 50,
    only_my_tasks: bool = True,
) -> MonitorSnapshot:
    return service.monitor(row_limit, only_my_tasks)


@router.post(
    "/taskflows/{name}/run",
    operation_id="cdi_run_taskflow_by_name",
    summary="Start an advanced taskflow by its name",
    description="Looks the name up in the org task list (exact, case-sensitive), calls its "
    "published URL /active-bpel/rt/{api_name} (api_name defaults to the name) and returns "
    'IDMC\'s run id. Body (optional): {"parameters": {"jobInstanceId": "ABC123"}} - '
    "Start-step input fields, exact names. 404 unknown name; 409 already running from this "
    "backend; IDMC's own "
    "status (e.g. 403 Allowed Users) on a refused start. Never retried.",
)
def run_taskflow_by_name(
    name: str, service: Service, request: TaskflowRunRequest | None = None
) -> TaskflowStartResult:
    try:
        return service.start_taskflow_by_name(
            name,
            request.api_name if request else None,
            request.parameters if request else None,
        )
    except TaskflowNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except TaskflowStartError as exc:
        code = exc.status_code if 400 <= exc.status_code < 500 else 502
        raise HTTPException(status_code=code, detail=str(exc)) from exc


@router.get(
    "/taskflows/runs/{run_id}",
    operation_id="cdi_taskflow_run_status",
    summary="Status + summary of a taskflow run by IDMC run id",
    description="Read-only. Works for any taskflow run id (started here, in IDMC, or before a "
    "restart). status is RUNNING until final (SUCCESS, FAILED, STOPPED = suspended). Each "
    "child task carries rows processed / success / error and, once final, the source/target "
    "split and log_entry_id from the activity log. Poll every 10-15 s while not is_final.",
)
def taskflow_run_status(run_id: str, service: Service, details: bool = True) -> TaskflowRunStatus:
    return service.taskflow_run_status(run_id, details)


@router.get(
    "/taskflows/runs/{run_id}/session-log",
    operation_id="cdi_taskflow_session_log",
    summary="Session log of one child task of a taskflow run (plain text)",
    description="subtask = child task name (default: the last child that has a log). "
    "404 if the child has no activity log entry yet.",
    response_class=PlainTextResponse,
)
def taskflow_session_log(run_id: str, service: Service, subtask: str | None = None) -> str:
    try:
        name, text = service.taskflow_session_log(run_id, subtask)
    except SessionLogNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    return f"# session log: {name} (taskflow run {run_id})\n{text}"
