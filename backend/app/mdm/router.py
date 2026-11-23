"""HTTP routes for MDM (Business 360). Mounted at /api/mdm."""

from typing import Annotated

from fastapi import APIRouter, Depends

from app.common.runs import RunView
from app.dependencies import get_mdm_service
from app.mdm.models import MdmJob, MdmRunRequest
from app.mdm.service import MdmService

router = APIRouter(prefix="/api/mdm", tags=["mdm"])

Service = Annotated[MdmService, Depends(get_mdm_service)]


@router.get(
    "/jobs",
    operation_id="mdm_list_jobs",
    summary="List Business 360 job definitions",
    description="Job definitions from the IDMC v3 objects query (MDM_JOB_DEFINITION), with "
    "the internal jobDefinitionId and kind filled in by the resolver where known. Only "
    "`runnable` jobs can be started.",
)
def list_jobs(service: Service) -> list[MdmJob]:
    return service.list_jobs()


@router.post(
    "/runs",
    operation_id="mdm_start_run",
    summary="Start one ingress / egress / match-merge job",
    description="400 if the job is not runnable, 409 if it already has a run in progress. "
    "A failed start is returned as a FAILED run and is never retried.",
)
def start_run(request: MdmRunRequest, service: Service) -> RunView:
    return service.start(request)


@router.get(
    "/runs",
    operation_id="mdm_list_runs",
    summary="MDM runs started from this backend (newest first)",
)
def list_runs(service: Service) -> list[RunView]:
    return service.list_runs()


@router.get(
    "/runs/{run_key}",
    operation_id="mdm_get_run",
    summary="Refresh and return one MDM run",
    description="Reads the B360 job instance and returns the run. Poll every few seconds "
    "until `status` is SUCCESS, WARNING, FAILED or STOPPED.",
)
def get_run(run_key: str, service: Service) -> RunView:
    return service.refresh(run_key)
