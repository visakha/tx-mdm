"""Typed models for the CDI module."""

from datetime import datetime
from enum import StrEnum

from pydantic import BaseModel


class CdiTaskType(StrEnum):
    MTT = "MTT"  # mapping task, run through /api/v2/job
    WORKFLOW = "WORKFLOW"  # linear taskflow, run through /api/v2/job
    TASKFLOW = "TASKFLOW"  # advanced taskflow, run through its published /active-bpel/rt URL


class CdiTask(BaseModel):
    """One runnable asset from the v3 objects query. `id` is the taskFederatedId."""

    id: str
    name: str
    path: str
    type: CdiTaskType
    description: str = ""
    updated_at: datetime | None = None


class CdiRunRequest(BaseModel):
    task_id: str
    task_type: CdiTaskType
    task_name: str
    # Advanced taskflows only: the published API name. Defaults to task_name (UNVERIFIED).
    api_name: str | None = None


class CdiRunHandle(BaseModel):
    """What we keep to check on a run later."""

    task_type: CdiTaskType
    run_id: str
    v2_task_id: str | None = None  # needed by activityLog for MTT/WORKFLOW
