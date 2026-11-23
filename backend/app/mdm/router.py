"""HTTP routes for MDM (Business 360). Mounted at /api/mdm."""

from typing import Annotated

from fastapi import APIRouter, Depends

from app.common.runs import RunView
from app.dependencies import get_mdm_service
from app.mdm.models import MdmJob, MdmRunRequest
from app.mdm.service import MdmService

router = APIRouter(prefix="/api/mdm", tags=["mdm"])

Service = Annotated[MdmService, Depends(get_mdm_service)]


@router.get("/jobs")
def list_jobs(service: Service) -> list[MdmJob]:
    return service.list_jobs()


@router.post("/runs")
def start_run(request: MdmRunRequest, service: Service) -> RunView:
    return service.start(request)


@router.get("/runs")
def list_runs(service: Service) -> list[RunView]:
    return service.list_runs()


@router.get("/runs/{run_key}")
def get_run(run_key: str, service: Service) -> RunView:
    return service.refresh(run_key)
