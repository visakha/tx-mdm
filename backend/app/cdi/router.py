"""HTTP routes for CDI. Mounted at /api/cdi."""

from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query
from fastapi.responses import PlainTextResponse

from app.cdi.models import CdiRunRequest, CdiTask, CdiTaskType
from app.cdi.monitor import MonitorSnapshot
from app.cdi.runtime_env import (
    MappingTaskRuntime,
    RuntimeChangeResult,
    RuntimeEnvironmentChange,
    RuntimeEnvironmentService,
    RuntimeNotVerifiedError,
    TaskIdKind,
)
from app.cdi.service import (
    CdiService,
    SessionLogNotFoundError,
    TaskflowNotFoundError,
    TaskflowParameterError,
    TaskflowStartError,
    TerminateError,
)
from app.cdi.taskflow_history import TaskflowHistory
from app.cdi.taskflow_runs import (
    TaskflowRunRequest,
    TaskflowRunStatus,
    TaskflowStartResult,
    TerminateRequest,
    TerminateResult,
)
from app.common.runs import RunView
from app.dependencies import get_cdi_service, get_runtime_env_service

router = APIRouter(prefix="/api/cdi", tags=["cdi"])

Service = Annotated[CdiService, Depends(get_cdi_service)]
RuntimeService = Annotated[RuntimeEnvironmentService, Depends(get_runtime_env_service)]


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
    try:
        return service.start(request)
    except TaskflowParameterError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


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
    'IDMC\'s run id. Body (optional): {"parameters": {"jobInstanceId": "<id>"}} - '
    "Start-step input fields, exact names. MDM taskflows (tf_MDM_*, *_EGR, *_IGR) MUST send "
    "jobInstanceId; CDI taskflows (e.g. tf_Ldg_*, tf_Stg_*) must NOT - else 400, IDMC not "
    "called. 404 unknown name. Several runs of one taskflow "
    "may be started in parallel (no 409 from this backend); IDMC's own "
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
    except TaskflowParameterError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except TaskflowStartError as exc:
        code = exc.status_code if 400 <= exc.status_code < 500 else 502
        raise HTTPException(status_code=code, detail=str(exc)) from exc


@router.get(
    "/taskflows/{name}/history",
    operation_id="cdi_taskflow_history",
    summary="Run history of one taskflow: running first, then recent finished",
    description="Read-only, never retried. Rows: runs of this taskflow started from this "
    "backend (IDMC run id, taskflow status), plus activityMonitor / activityLog rows named "
    "after the taskflow or one of its child tasks. Seen live 2026-11-23: IDMC lists only the "
    "child mapping tasks there, not the taskflow; child rows carry IDMC's per-task run number, "
    "which is not a taskflow run id (trackable=false). Poll every 15 s; a 429 is a hard stop.",
)
def taskflow_history(
    name: str,
    service: Service,
    row_limit: Annotated[int, Query(ge=1, le=1000)] = 100,
) -> TaskflowHistory:
    return service.taskflow_history(name, row_limit)


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


@router.post(
    "/taskflows/runs/{run_id}/terminate",
    operation_id="cdi_terminate_taskflow",
    summary="Terminate (abort) a taskflow run by IDMC run id",
    description='Calls PUT {pod}/active-bpel/services/tf/terminate {"runid": [...]}. Optional '
    'body {"run_ids": [...]} adds more ids to the same call (max 200). 204 from IDMC -> '
    "terminated=true. A 500 from IDMC (invalid / not active id) is returned as 502 with its text. "
    "Never retried. SIDE EFFECT: stops a live run.",
)
def terminate_taskflow(
    run_id: str, service: Service, request: TerminateRequest | None = None
) -> TerminateResult:
    extra = request.run_ids if request else []
    try:
        return service.terminate_taskflows([run_id, *extra])
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except TerminateError as exc:
        code = exc.status_code if 400 <= exc.status_code < 500 else 502
        raise HTTPException(status_code=code, detail=str(exc)) from exc


@router.get(
    "/mapping-tasks/{task_id}/runtime-environment",
    operation_id="cdi_mapping_task_runtime",
    summary="Which runtime environment one mapping task uses (name + id)",
    description="v2 GET mttask/<id> (id_kind=v2) or mttask/frs/<id> (id_kind=frs), plus the v2 "
    "runtimeEnvironment list for the name. Read-only.",
)
def mapping_task_runtime(
    task_id: str, service: RuntimeService, id_kind: TaskIdKind = TaskIdKind.V2
) -> MappingTaskRuntime:
    return service.current(task_id, id_kind)


@router.put(
    "/mapping-tasks/{task_id}/runtime-environment",
    operation_id="cdi_set_mapping_task_runtime",
    summary="Move ONE mapping task to another runtime environment (read back + verified)",
    description="Resolves the name (or id) from the v2 runtimeEnvironment list, reads the task, "
    "POSTs only runtimeEnvironmentId with Update-Mode: PARTIAL (IDMC REST API Reference July 2026 "
    "pp. 19, 486), reads it back. 409 if the read-back does not match. One task per call. "
    "SIDE EFFECT: changes the task in IDMC.",
)
def set_mapping_task_runtime(
    task_id: str,
    body: RuntimeEnvironmentChange,
    service: RuntimeService,
    id_kind: TaskIdKind = TaskIdKind.V2,
) -> RuntimeChangeResult:
    try:
        return service.change(task_id, id_kind, body.runtime_environment)
    except RuntimeNotVerifiedError as exc:
        raise HTTPException(status_code=409, detail=str(exc)) from exc
