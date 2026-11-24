"""Test runs: state on the server (memory + one folder per run on disk, so a run can be resumed
by run_id after the runner or the backend restarts), the step machine, and the real-path lock.
"""

import os
import threading
import uuid
from datetime import UTC, datetime
from pathlib import Path

from app.common.runs import RunNotFoundError
from app.testing import workbooks
from app.testing.cases import UseCase, find_case, load_config
from app.testing.compare import compare
from app.testing.mock import MockPipeline
from app.testing.models import (
    GROUP_STEPS,
    Answer,
    Comparison,
    ContinueRequest,
    Group,
    Handshake,
    PreflightReport,
    RunPath,
    RunState,
    RunView,
    Step,
    StepStatus,
    StepView,
)
from app.testing.sheets import Row, Workbook, read_workbook

RUNS_DIR = Path(os.environ.get("TXMDM_TEST_RUNS_DIR", Path(__file__).parents[2] / ".test_runs"))


class PreflightFailedError(Exception):
    def __init__(self, report: PreflightReport) -> None:
        super().__init__("pre-flight failed")
        self.report = report


class RunConflictError(Exception):
    """409: the run is not in a state that allows this call, or the real path is busy."""


def _now() -> datetime:
    return datetime.now(UTC)


def real_path_gaps(group: Group) -> list[str]:
    cfg = load_config()
    gaps = [
        "real step execution (source DB load, CDI taskflow start, B360 job status) is not wired "
        "to test runs yet",
    ]
    if cfg.source_db.kind == "sqlite":
        gaps.append(
            "test_config.toml [source_db] kind is sqlite; the real path needs oracle or "
            "snowflake plus a connection (not defined yet)"
        )
    entity = cfg.pipeline[group].entity
    job = cfg.match_merge.get(entity)
    if job is not None:
        gaps.append(
            f"match-merge job {job.job_definition_id} / {job.match_model_id} is a "
            "placeholder; create it in Business 360 Console or change the TOML"
        )
    return gaps


class RunStore:
    def __init__(self, root: Path = RUNS_DIR) -> None:
        self.root = root
        self._runs: dict[str, RunView] = {}
        self._books: dict[str, Workbook] = {}
        self._real_lock: dict[Group, str] = {}
        self._mutex = threading.RLock()

    # -- storage --------------------------------------------------------------------------
    def _dir(self, run_id: str) -> Path:
        return self.root / run_id

    def _save(self, run: RunView) -> None:
        run.updated_at = _now()
        self._runs[run.run_id] = run
        (self._dir(run.run_id) / "state.json").write_text(run.model_dump_json(indent=2))

    def _log(self, run: RunView, line: str) -> None:
        with (self._dir(run.run_id) / "run.log").open("a", encoding="ascii", errors="replace") as f:
            f.write(f"{_now().isoformat(timespec='seconds')} {line}\n")

    def get(self, run_id: str) -> RunView:
        with self._mutex:
            run = self._runs.get(run_id)
            state = self._dir(run_id) / "state.json"
            if run is None and run_id.isalnum() and state.is_file():
                run = RunView.model_validate_json(state.read_text())
                self._runs[run_id] = run
            if run is None:
                raise RunNotFoundError(f"test run {run_id} not found")
            return run

    def _book(self, run: RunView) -> tuple[UseCase, Workbook]:
        case = find_case(run.group, run.use_case)
        if run.run_id not in self._books:
            data = (self._dir(run.run_id) / "upload.xlsx").read_bytes()
            self._books[run.run_id] = read_workbook(data, case)[0]
        return case, self._books[run.run_id]

    # -- lifecycle ------------------------------------------------------------------------
    def start(self, path: RunPath, case: UseCase, data: bytes) -> RunView:
        book, report = read_workbook(data, case)
        if not report.ok:
            raise PreflightFailedError(report)
        manual = set(load_config().pipeline[case.group].manual_steps)
        with self._mutex:
            if path == RunPath.REAL and case.group in self._real_lock:
                busy = self._real_lock[case.group]
                raise RunConflictError(f"a real {case.group.value} run is active: {busy}")
            run_id = uuid.uuid4().hex[:12]
            self._dir(run_id).mkdir(parents=True)
            (self._dir(run_id) / "upload.xlsx").write_bytes(data)
            self._books[run_id] = book
            run = RunView(
                run_id=run_id,
                path=path,
                group=case.group,
                use_case=case.use_case,
                state=RunState.RUNNING,
                created_at=_now(),
                updated_at=_now(),
                steps=[StepView(step=s, manual=s in manual) for s in GROUP_STEPS[case.group]],
            )
            self._log(run, f"created {path.value} {case.group.value}/{case.use_case}")
            if path == RunPath.REAL:
                self._real_lock[case.group] = run_id
                run.state = RunState.NOT_CONFIGURED
                run.message = "; ".join(real_path_gaps(case.group))
                self._finish(run)
                return run
            return self._advance(run)

    def _finish(self, run: RunView) -> None:
        if run.state.is_terminal and self._real_lock.get(run.group) == run.run_id:
            del self._real_lock[run.group]
        self._log(run, f"state {run.state.value} {run.message}")
        self._save(run)

    def _execute(self, run: RunView, view: StepView) -> bool:
        case, book = self._book(run)
        view.started_at = _now()
        out = MockPipeline(self._dir(run.run_id) / "mock.sqlite", case).run(view.step, book)
        view.ended_at = _now()
        view.status, view.rows_in, view.rows_out = out.status, out.rows_in, out.rows_out
        view.message, view.errors = out.message, out.errors
        self._log(run, f"step {view.step.value} {view.status.value} {view.message}")
        if view.step == Step.COMPARE and out.status == StepStatus.SUCCESS:
            result = self._compare(run)
            view.rows_out = result.checked
            view.message = f"{result.failed} of {result.checked} checks failed"
            if not result.passed:
                view.status = StepStatus.FAILED
        return view.status in (StepStatus.SUCCESS, StepStatus.SKIPPED)

    def _advance(self, run: RunView) -> RunView:
        for view in run.steps:
            if view.status != StepStatus.PENDING:
                continue
            if view.manual:
                view.status, run.state = StepStatus.WAITING, RunState.WAITING
                run.message = f"waiting for the tester: {view.step.value}"
                self._finish(run)
                return run
            if not self._execute(run, view):
                run.state = RunState.FAILED
                run.message = f"step {view.step.value} {view.status.value}: {view.message}"
                self._finish(run)
                return run
        run.state, run.message = RunState.PASSED, "all steps passed"
        self._finish(run)
        return run

    def resume(self, run_id: str, req: ContinueRequest) -> RunView:
        with self._mutex:
            run = self.get(run_id)
            view = next((s for s in run.steps if s.step == req.step), None)
            open_states = (StepStatus.WAITING, StepStatus.FAILED)
            if view is None or view.status not in open_states or run.state == RunState.ABORTED:
                raise RunConflictError(f"step {req.step.value} is not waiting or failed")
            if run.path == RunPath.REAL:
                raise RunConflictError("the real path is not configured")
            later = run.steps[run.steps.index(view) + 1 :]
            self._log(run, f"continue {req.step.value} answer={req.answer.value}")
            match req.answer:
                case Answer.ABORT:
                    return self.abort(run_id)
                case Answer.SKIP:
                    view.status, view.message = StepStatus.SKIPPED, "skipped by the tester"
                case Answer.DONE | Answer.RETRY:
                    for s in later:
                        s.status = StepStatus.PENDING
                    run.state = RunState.RUNNING
                    if not self._execute(run, view):
                        run.state = RunState.FAILED
                        run.message = f"step {view.step.value} {view.status.value}: {view.message}"
                        self._finish(run)
                        return run
            run.state = RunState.RUNNING
            return self._advance(run)

    def abort(self, run_id: str) -> RunView:
        with self._mutex:
            run = self.get(run_id)
            if run.state.is_terminal and run.state != RunState.FAILED:
                raise RunConflictError(f"run already {run.state.value}")
            for view in run.steps:
                if view.status in (StepStatus.PENDING, StepStatus.WAITING):
                    view.status = StepStatus.ABORTED
            run.state, run.message = RunState.ABORTED, "aborted"
            self._finish(run)
            return run

    def set_handshakes(self, run_id: str, handshakes: list[Handshake]) -> RunView:
        with self._mutex:
            run = self.get(run_id)
            run.handshakes = handshakes
            self._log(run, f"handshakes recorded: {len(handshakes)}")
            self._save(run)
            return run

    # -- results --------------------------------------------------------------------------
    def actual(self, run: RunView) -> dict[str, list[Row]]:
        case, _ = self._book(run)
        return MockPipeline(self._dir(run.run_id) / "mock.sqlite", case).actual()

    def _compare(self, run: RunView) -> Comparison:
        case, book = self._book(run)
        eg = load_config().egress
        actual = self.actual(run)
        main = actual.get("MDM_SEARCH" if case.group == Group.MDM else eg.table, [])
        phones = actual.get(eg.phone_table) if case.group == Group.TTF else None
        expected_phones = book.sheets.get("ExpectedPhones") if case.group == Group.TTF else None
        result = compare(run.run_id, book.sheets["Expected"], expected_phones, main, phones or [])
        (self._dir(run.run_id) / "comparison.json").write_text(result.model_dump_json(indent=2))
        return result

    def comparison(self, run_id: str) -> Comparison:
        file = self._dir(self.get(run_id).run_id) / "comparison.json"
        if not file.is_file():
            raise RunConflictError("not compared yet: the compare step has not run")
        return Comparison.model_validate_json(file.read_text())

    def result(self, run_id: str) -> tuple[str, bytes]:
        run = self.get(run_id)
        case, book = self._book(run)
        file = self._dir(run_id) / "comparison.json"
        cmp = Comparison.model_validate_json(file.read_text()) if file.is_file() else None
        uploaded = {k: v for k, v in book.sheets.items() if k.startswith("Expected")}
        data = workbooks.result(case, run, cmp, self.actual(run), uploaded)
        name = f"{run.group.value}_{run.use_case}_result_{run.run_id}.xlsx"
        (self._dir(run_id) / name).write_bytes(data)
        return name, data


_store: RunStore | None = None


def get_store() -> RunStore:
    global _store
    if _store is None:
        _store = RunStore()
    return _store
