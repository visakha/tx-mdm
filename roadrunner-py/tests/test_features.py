"""Step definitions for features/*.feature - the BDD scenarios ARE the runner's tests."""

from pathlib import Path

import pytest
from pytest_bdd import given, parsers, scenarios, then, when

from roadrunner.api import TestApi
from roadrunner.handshake import Pauses, load_answers
from roadrunner.runner import ANSWERS, FILLED, CaseRunner, Outcome, case_dir

scenarios("ttf.feature", "mdm.feature")


@given("the tx-mdm backend is reachable")
def reachable(api: TestApi) -> None:
    assert api.health(), f"backend not reachable at {api.http.base_url}"


@given(
    parsers.parse("a test-case folder for {group} {use_case}, generated template if it has none"),
    target_fixture="folder",
)
def folder(api: TestApi, pauses: Pauses, work: Path, group: str, use_case: str) -> Path:
    path = case_dir(work, group, use_case)
    if not (path / FILLED).is_file():
        CaseRunner(api, pauses, work).init(group, use_case, generated=True, rows=None)
    return path


@when(parsers.parse("the runner runs {group} {use_case}"), target_fixture="outcome")
def run_case(
    api: TestApi, pauses: Pauses, work: Path, folder: Path, group: str, use_case: str
) -> Outcome:
    pauses.answers = load_answers(folder / ANSWERS)
    return CaseRunner(api, pauses, work).run(group, use_case)


@then(parsers.parse("the run state is {state}"))
def run_state(outcome: Outcome, state: str) -> None:
    assert outcome.run is not None, "the run never started (see the run log)"
    assert outcome.run.state == state, outcome.run.message


@then("every comparison check passed")
def all_checks(api: TestApi, outcome: Outcome) -> None:
    assert outcome.run is not None
    cmp = api.comparison(outcome.run)
    if cmp is None:
        pytest.fail("no comparison: the compare step did not run")
    bad = [
        f"{r.check} {r.clientcode} {r.field}: {r.expected} != {r.actual}"
        for r in cmp.rows
        if not r.passed
    ]
    assert cmp.passed, "; ".join(bad)


@then("the result workbook and the run log are in the test-case folder")
def files_written(outcome: Outcome) -> None:
    assert outcome.run is not None
    assert list(outcome.folder.glob(f"*_result_{outcome.run.run_id}.xlsx"))
    assert (outcome.folder / f"run_{outcome.run.run_id}.log").is_file()
