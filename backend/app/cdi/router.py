"""HTTP routes for CDI. Mounted at /api/cdi."""

from typing import Annotated

from fastapi import APIRouter, Depends, Query

from app.cdi.models import CdiRunRequest, CdiTask, CdiTaskType
from app.cdi.service import CdiService
from app.common.runs import RunView
from app.dependencies import get_cdi_service

router = APIRouter(prefix="/api/cdi", tags=["cdi"])

Service = Annotated[CdiService, Depends(get_cdi_service)]


@router.get("/tasks")
def list_tasks(
    service: Service,
    types: Annotated[list[CdiTaskType] | None, Query()] = None,
) -> list[CdiTask]:
    return service.list_tasks(types or list(CdiTaskType))


@router.post("/runs")
def start_run(request: CdiRunRequest, service: Service) -> RunView:
    return service.start(request)


@router.get("/runs")
def list_runs(service: Service) -> list[RunView]:
    return service.list_runs()


@router.get("/runs/{run_key}")
def get_run(run_key: str, service: Service) -> RunView:
    return service.refresh(run_key)
