"""HTTP routes for MDM (Business 360). Mounted at /api/mdm."""

from typing import Annotated

from fastapi import APIRouter, Depends, Path, Query

from app.common.naming import Identifier64
from app.common.runs import RunView
from app.dependencies import get_mdm_monitor, get_mdm_service
from app.mdm.models import MdmJob, MdmRunRequest, PublishRunRequest, PublishRunStarted
from app.mdm.monitor import MAX_ROW_LIMIT, MdmJobInstanceView, MdmMonitor, MdmMonitorSnapshot
from app.mdm.service import MdmService

router = APIRouter(prefix="/api/mdm", tags=["mdm"])

Service = Annotated[MdmService, Depends(get_mdm_service)]
Monitor = Annotated[MdmMonitor, Depends(get_mdm_monitor)]


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


@router.get(
    "/monitor",
    operation_id="mdm_monitor",
    summary="Currently running B360 jobs in the org (any starter) + recent finished",
    description="Read-only. B360 job search: running = status RUNNING or QUEUED, recent = one "
    "page of `row_limit`. Only jobTypes starting with b360. or c360. are listed. Includes jobs "
    "started from the portal, another machine or another user, not only from this backend. "
    "Poll every 15 s. A 429 from IDMC is returned as 429 and never retried.",
)
def mdm_monitor(
    monitor: Monitor, row_limit: Annotated[int, Query(ge=1, le=MAX_ROW_LIMIT)] = 25
) -> MdmMonitorSnapshot:
    return monitor.snapshot(row_limit)


@router.get(
    "/job-instances/{instance_id}",
    operation_id="mdm_lookup_job_instance",
    summary="Look up any B360 job instance by its full id",
    description="Read-only GET jobInstance/{id}?details=true. Works for jobs started anywhere "
    "(portal, other machines), not only runs this backend started.",
)
def lookup_job_instance(
    monitor: Monitor,
    instance_id: Annotated[Identifier64, Path(min_length=1, max_length=64)],
) -> MdmJobInstanceView:
    return monitor.lookup(instance_id)


@router.post(
    "/publish-events/runs",
    operation_id="mdm_start_publish_events",
    summary="Start the Publish Business Events job (default mdm_zlv_guest_pub_evts_001)",
    description="0.10.1. Finds the job by name in the B360 job list (kind Publish, jobType "
    "b360.businessevents.publish), then POST jobInstance/{kind} with its jobDefinitionId. The "
    "{kind} segment for publish comes from settings mdm_publish_run_kind (UNVERIFIED, not in "
    "the Oct 2026 reference). 400 if the job is unknown or did not start, 409 if this backend "
    "already has a run of it in progress. Never retried.",
)
def start_publish_events(
    service: Service, request: PublishRunRequest | None = None
) -> PublishRunStarted:
    return service.start_publish(request or PublishRunRequest())


@router.get(
    "/publish-events/runs/{instance_id}",
    operation_id="mdm_get_publish_events_run",
    summary="Status of one Publish Business Events run by job instance id",
    description="0.10.1. Read-only GET jobInstance/{id}?details=true: status, start/end, "
    "counts, errors, portal link. Poll every few seconds until SUCCESS, WARNING, FAILED or "
    "STOPPED.",
)
def get_publish_events_run(
    service: Service,
    instance_id: Annotated[Identifier64, Path(min_length=1, max_length=64)],
) -> MdmJobInstanceView:
    return service.publish_status(instance_id)
