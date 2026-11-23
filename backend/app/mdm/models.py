"""Typed models for the MDM (Business 360) module."""

from datetime import datetime
from enum import StrEnum

from pydantic import BaseModel, Field


class MdmJobKind(StrEnum):
    INGRESS = "Ingress"
    EGRESS = "Egress"
    MATCH_MERGE = "MatchMerge"
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
