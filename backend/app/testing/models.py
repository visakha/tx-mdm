"""Typed models for the testing harness API (/api/test/...). One shape for mock and real paths."""

from datetime import datetime
from enum import StrEnum

from pydantic import BaseModel, Field


class RunPath(StrEnum):
    MOCK = "mock"
    REAL = "real"


class Group(StrEnum):
    TTF = "TTF"
    MDM = "MDM"


class Step(StrEnum):
    LOAD = "load"
    LDG = "ldg"
    STG = "stg"
    INGRESS = "ingress"
    MATCH_MERGE = "match-merge"
    EGRESS = "egress"
    MDM_JOB = "mdm-job"
    READ = "read"
    COMPARE = "compare"


GROUP_STEPS: dict[Group, tuple[Step, ...]] = {
    Group.TTF: (
        Step.LOAD,
        Step.LDG,
        Step.STG,
        Step.INGRESS,
        Step.MATCH_MERGE,
        Step.EGRESS,
        Step.READ,
        Step.COMPARE,
    ),
    Group.MDM: (Step.LOAD, Step.MDM_JOB, Step.READ, Step.COMPARE),
}


class StepStatus(StrEnum):
    PENDING = "PENDING"
    WAITING = "WAITING"  # a manual step: the tester runs it, then calls .../continue
    SUCCESS = "SUCCESS"
    FAILED = "FAILED"
    SKIPPED = "SKIPPED"
    ABORTED = "ABORTED"


class RunState(StrEnum):
    RUNNING = "RUNNING"
    WAITING = "WAITING"
    PASSED = "PASSED"
    FAILED = "FAILED"
    ABORTED = "ABORTED"
    NOT_CONFIGURED = "NOT_CONFIGURED"

    @property
    def is_terminal(self) -> bool:
        return self not in {RunState.RUNNING, RunState.WAITING}


class Answer(StrEnum):
    DONE = "done"
    RETRY = "retry"
    SKIP = "skip"
    ABORT = "abort"


class TemplateMode(StrEnum):
    EMPTY = "empty"
    GENERATED = "generated"


class UseCaseSummary(BaseModel):
    group: Group
    use_case: str = Field(description="e.g. use-case-1")
    title: str
    template_version: str
    sheets: list[str] = Field(description="Sheets the tester fills, in workbook order.")
    manual_steps: list[Step] = Field(description="Steps where the runner pauses for the tester.")
    default_rows: int


class Issue(BaseModel):
    sheet: str
    row: int | None = Field(default=None, description="Excel row number, 1-based.")
    column: str | None = None
    message: str


class PreflightReport(BaseModel):
    ok: bool
    template_version: str | None
    rows_per_sheet: dict[str, int]
    issues: list[Issue]


class StepView(BaseModel):
    step: Step
    status: StepStatus = StepStatus.PENDING
    manual: bool = False
    started_at: datetime | None = None
    ended_at: datetime | None = None
    rows_in: int | None = None
    rows_out: int | None = None
    message: str = ""
    errors: list[str] = Field(default_factory=list)


class Handshake(BaseModel):
    """One pause in the desktop runner: what was asked, what the tester (or script) answered."""

    title: str
    answer: Answer
    source: str = Field(description="human | scripted | auto")
    at: datetime
    verified: str = Field(default="", description="Result of the API check after the answer.")


class RunView(BaseModel):
    run_id: str
    path: RunPath
    group: Group
    use_case: str
    state: RunState
    created_at: datetime
    updated_at: datetime
    message: str = ""
    steps: list[StepView]
    handshakes: list[Handshake] = Field(default_factory=list)


class ContinueRequest(BaseModel):
    step: Step
    answer: Answer = Answer.DONE


class CompareRow(BaseModel):
    check: str = Field(description="member | field | master_group | phone")
    clientcode: str
    field: str = ""
    expected: str
    actual: str
    passed: bool


class Comparison(BaseModel):
    run_id: str
    passed: bool
    checked: int
    failed: int
    rows: list[CompareRow]
