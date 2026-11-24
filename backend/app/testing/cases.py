"""Load test_cases/: the placeholder config TOML and one combined TOML per use case.

Human sections are kept as labelled text blocks for the Home sheet and never interpreted.
Only the [mock] section is parsed into a typed script.
"""

import os
import tomllib
from functools import lru_cache
from pathlib import Path
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

from app.testing.models import Group, Step, StepStatus

CASES_DIR = Path(os.environ.get("TXMDM_TEST_CASES_DIR", Path(__file__).parents[2] / "test_cases"))


class Strict(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)


class SourceDb(Strict):
    kind: Literal["oracle", "snowflake", "sqlite"]
    schema_name: str = Field(alias="schema")
    tables: list[str]


class Egress(Strict):
    table: str
    columns: list[str]
    phone_table: str
    phone_columns: list[str]


class ExpectedSheet(Strict):
    columns: list[str]
    phone_columns: list[str]


class Pipeline(Strict):
    entity: str
    source: str
    manual_steps: list[Step]
    ldg_taskflow: str = ""
    stg_taskflow: str = ""
    ingress_job: str = ""
    egress_job: str = ""


class MatchMergeJob(Strict):
    job_definition_id: str
    match_model_id: str
    match_model_version: int


class Validation(Strict):
    reason_field: str


class MockDefaults(Strict):
    phone_types: list[str]
    country_code: str


class HarnessConfig(Strict):
    source_db: SourceDb
    egress: Egress
    expected_sheet: ExpectedSheet
    pipeline: dict[Group, Pipeline]
    match_merge: dict[str, MatchMergeJob]
    validation: Validation
    mock: MockDefaults


class StepScript(Strict):
    status: StepStatus = StepStatus.SUCCESS
    message: str = ""


class PhoneVerdict(Strict):
    ph_num: str
    state: str
    reason: str


class MockScript(Strict):
    shape: str
    match_rule: Literal["name_dob", "none"] = "name_dob"
    action: Literal["match_merge", "reset_matched", "index", "purge"] | None = None
    default_rows: int = 2
    steps: dict[Step, StepScript] = Field(default_factory=dict)
    phone_validation: list[PhoneVerdict] = Field(default_factory=list)


class HomeBlock(BaseModel):
    label: str
    lines: list[str]


class UseCase(BaseModel):
    group: Group
    use_case: str
    title: str
    template_version: str
    home: list[HomeBlock]
    mock: MockScript


def _blocks(label: str, value: object) -> list[HomeBlock]:
    match value:
        case dict():
            lines = [f"{k}: {v}" for k, v in value.items() if not isinstance(v, dict | list)]
            lines += [f"{k}: {item}" for k, v in value.items() if isinstance(v, list) for item in v]
            own = [HomeBlock(label=label, lines=lines)] if lines else []
            nested = [b for k, v in value.items() if isinstance(v, dict) for b in _blocks(k, v)]
            return own + [HomeBlock(label=f"{label}.{b.label}", lines=b.lines) for b in nested]
        case _:
            return [HomeBlock(label=label, lines=[str(value)])]


def _load_case(group: Group, path: Path) -> UseCase:
    data = tomllib.loads(path.read_text(encoding="ascii"))
    head = data["use_case"]
    home = [b for k, v in data.items() if k != "mock" for b in _blocks(k, v)]
    return UseCase(
        group=group,
        use_case=str(head["id"]),
        title=str(head["title"]),
        template_version=str(head["template_version"]),
        home=home,
        mock=MockScript.model_validate(data["mock"]),
    )


def _case_number(case: UseCase) -> int:
    return int(case.use_case.removeprefix("use-case-"))


@lru_cache
def load_config() -> HarnessConfig:
    data = tomllib.loads((CASES_DIR / "test_config.toml").read_text(encoding="ascii"))
    return HarnessConfig.model_validate(data)


@lru_cache
def use_cases(group: Group) -> tuple[UseCase, ...]:
    cases = [_load_case(group, p) for p in (CASES_DIR / group.value).glob("use-case-*.toml")]
    return tuple(sorted(cases, key=_case_number))


def find_case(group: Group, use_case: str) -> UseCase:
    for case in use_cases(group):
        if case.use_case == use_case:
            return case
    raise LookupError(f"unknown use case {group.value}/{use_case}")
