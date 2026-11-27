"""Typed models for the MDM (Business 360) module."""

from datetime import datetime
from enum import StrEnum

from pydantic import BaseModel, Field


class MdmJobKind(StrEnum):
    INGRESS = "Ingress"
    EGRESS = "Egress"
    MATCH_MERGE = "MatchMerge"
    PUBLISH_EVENTS = "Publish"  # display name; the run path segment comes from settings
    UNKNOWN = "Unknown"


class MdmJobAsset(BaseModel):
    """A job definition as listed by the platform v3 objects query (no internal id, no type)."""

    asset_id: str
    name: str
    path: str
    description: str = ""
    updated_at: datetime | None = None


class ResolvedDefinition(BaseModel):
    job_definition_id: str  # the id the jobInstance run calls need
    job_type: str  # as returned by the org, e.g. c360.ingress.load
    kind: MdmJobKind


class MdmJob(BaseModel):
    """What the picker shows. Runnable only when resolved and the kind is known."""

    asset_id: str
    name: str
    path: str
    description: str = ""
    updated_at: datetime | None = None
    job_definition_id: str | None = None
    job_type: str | None = None
    kind: MdmJobKind = MdmJobKind.UNKNOWN
    runnable: bool = Field(default=False, description="True when the id and kind are resolved.")
    note: str = Field(default="", description="Why a job is not runnable, if it is not.")


class MdmRunRequest(BaseModel):
    asset_id: str = Field(description="MdmJob.asset_id of a runnable job.")


class PublishRunRequest(BaseModel):
    """0.10.1: start the Publish Business Events job by its name (default from settings)."""

    job_name: str | None = Field(
        default=None,
        min_length=1,
        max_length=255,
        description="Job name as in the B360 Console. Empty = settings mdm_publish_job_name.",
    )


class PublishRunStarted(BaseModel):
    """What POST /api/mdm/publish-events/runs returns."""

    instance_id: str = Field(description="B360 job instance id; poll GET .../runs/{instance_id}.")
    run_key: str = Field(description="This backend's run key (also in GET /api/mdm/runs).")
    job_name: str
    job_definition_id: str
    job_type: str
    run_path_kind: str = Field(description="The {kind} segment used in jobInstance/{kind}.")
    started_at: datetime
    portal_url: str | None = None
