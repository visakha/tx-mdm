"""Typed models for the CDI module."""

from datetime import datetime
from enum import StrEnum

from pydantic import BaseModel, Field

from app.cdi.taskflow_kind import TaskDomain


class CdiTaskType(StrEnum):
    MTT = "MTT"  # mapping task, run through /api/v2/job
    WORKFLOW = "WORKFLOW"  # linear taskflow, run through /api/v2/job
    TASKFLOW = "TASKFLOW"  # advanced taskflow, run through its published /active-bpel/rt URL


class CdiTask(BaseModel):
    """One runnable asset from the v3 objects query. `id` is the taskFederatedId."""

    id: str = Field(description="taskFederatedId; pass it as task_id to start a run.")
    name: str
    path: str = Field(description="Project/folder path as shown in IDMC.")
    type: CdiTaskType
    description: str = ""
    updated_at: datetime | None = None
    domain: TaskDomain = Field(
        default=TaskDomain.CDI,
        description="mdm = Business 360 taskflow (tf_MDM_*, *_EGR, *_IGR; needs jobInstanceId) or "
        "its child mapping task (mt_m_MDM_*, *_EGR, *_IGR; runs via its taskflow only), else "
        "cdi. See app/cdi/taskflow_kind.py.",
    )


class CdiRunRequest(BaseModel):
    task_id: str = Field(description="CdiTask.id (taskFederatedId).")
    task_type: CdiTaskType
    task_name: str = Field(
        description="CdiTask.name, used for display and as the default API name."
    )
    # Advanced taskflows only: the published API name. Defaults to task_name (verified live
    # 2026-11-22: tf_MDM_ZLV_TTF_Guest_Basic's service URL ends in its task name).
    api_name: str | None = None
    # Advanced taskflows only: Start-step input fields, sent as the JSON body of the rt call.
    parameters: dict[str, str] | None = Field(
        default=None,
        description='Taskflow input fields, exact names, e.g. {"jobInstanceId": "<id>"} '
        "(MDM taskflows only).",
    )


class CdiRunHandle(BaseModel):
    """What we keep to check on a run later."""

    task_type: CdiTaskType
    run_id: str
    v2_task_id: str | None = None  # needed by activityLog for MTT/WORKFLOW
