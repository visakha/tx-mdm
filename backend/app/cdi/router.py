"""HTTP routes for CDI. Mounted at /api/cdi."""

from typing import Annotated

from fastapi import APIRouter, Depends, Query

from app.cdi.models import CdiRunRequest, CdiTask, CdiTaskType
from app.cdi.service import CdiService
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
