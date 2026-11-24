"""One use case end to end: folder, Excel, pre-flight, run, pauses, result xlsx + run log.

No data cleanup and no key tagging: the tester owns the data (Vamsi, 2026-11-23 22:08).
"""

from dataclasses import dataclass, field
from datetime import UTC, datetime
from pathlib import Path

from roadrunner.api import Answer, Run, RunPath, TestApi
from roadrunner.handshake import Pauses

FILLED = "filled.xlsx"
ANSWERS = "answers.toml"
STEP_HELP = {
    "ingress": "Start the Business 360 ingress job for this source in IDMC and wait for it.",
    "egress": "Start the Business 360 egress job for this source in IDMC and wait for it.",
    "mdm-job": "Run the MDM job this use case is about (match-merge / reset / index / purge).",
}


def case_dir(work: Path, group: str, uc: str) -> Path:
    return work / f"{group}_{uc}"


@dataclass
class Outcome:
    run: Run | None
    folder: Path
    log: list[str] = field(default_factory=list)

    @property
    def passed(self) -> bool:
        return self.run is not None and self.run.state == "PASSED"


class CaseRunner:
    def __init__(self, api: TestApi, pauses: Pauses, work: Path) -> None:
        self.api, self.pauses, self.work = api, pauses, work
        self.lines: list[str] = []

    def note(self, text: str) -> None:
        line = f"{datetime.now(UTC).isoformat(timespec='seconds')} {text}"
        self.lines.append(line)
        self.pauses.say(f"  {text}")

    def init(self, group: str, uc: str, generated: bool, rows: int | None) -> Path:
        folder = case_dir(self.work, group, uc)
        folder.mkdir(parents=True, exist_ok=True)
        detail = self.api.use_case(group, uc)
        (folder / FILLED).write_bytes(self.api.template(group, uc, generated, rows))
        about = [f"{group} {uc}: {detail.title}", f"Sheets: {', '.join(detail.sheets)}", ""]
        for block in detail.home:
            about += [f"[{block.label}]", *block.lines, ""]
        (folder / "USE_CASE.txt").write_text("\n".join(about), encoding="ascii", errors="replace")
        pauses = ["prepare-excel", *detail.manual_steps]
        answers = ["[answers]", *[f'"{p}" = "HUMAN"' for p in pauses]]
        (folder / ANSWERS).write_text("\n".join(answers) + "\n", encoding="ascii")
        return folder

    def _fresh(self) -> None:
        self.lines, self.pauses.log = [], []

    def run(self, group: str, uc: str) -> Outcome:
        self._fresh()
        folder = case_dir(self.work, group, uc)
        if not (folder / FILLED).is_file():
            self.init(group, uc, generated=True, rows=None)
            self.note(f"no {FILLED} yet: downloaded a generated template into {folder}")
        out = Outcome(None, folder, self.lines)
        while True:
            shake = self.pauses.pause(
                "prepare-excel", [f"Open {folder / FILLED}, fill or check it, save, close Excel."]
            )
            if shake.answer == Answer.ABORT:
                self.note("aborted before upload")
                return self._write(out)
            data = (folder / FILLED).read_bytes()
            report = self.api.preflight(group, uc, data)
            if report.ok:
                shake.verified = f"pre-flight ok: {report.rows_per_sheet}"
                break
            shake.verified = f"pre-flight failed: {len(report.issues)} issue(s)"
            for issue in report.issues:
                where = f"{issue.sheet} row {issue.row}" if issue.row else issue.sheet
                self.note(f"pre-flight: {where} {issue.column or ''} {issue.message}")
            if shake.source != "human":
                self.note("fix the workbook and run again (scripted / auto answers cannot)")
                return self._write(out)
        out.run = self.api.start(group, uc, data)
        self.note(f"run {out.run.run_id} started ({self.api.path.value} path)")
        return self._drive(out)

    def resume(self, group: str, uc: str, run_id: str) -> Outcome:
        self._fresh()
        out = Outcome(self.api.run(group, uc, run_id), case_dir(self.work, group, uc), self.lines)
        self.note(f"resumed run {run_id}")
        return self._drive(out)

    def _drive(self, out: Outcome) -> Outcome:
        run = out.run
        assert run is not None
        while (step := run.open_step()) is not None and step.manual and run.state != "ABORTED":
            failed = step.status == "FAILED"
            title = f"failed: {step.step}" if failed else step.step
            lines = [STEP_HELP.get(step.step, step.step), run.message]
            if self.api.path == RunPath.MOCK:
                lines.append("Mock path: nothing to start, the fake IDMC does it on Done.")
            shake = self.pauses.pause(title, lines)
            answer = Answer.RETRY if failed and shake.answer == Answer.DONE else shake.answer
            run = self.api.answer(run, step.step, answer)
            after = next(s for s in run.steps if s.step == step.step)
            shake.verified = f"API: {after.step} {after.status} rows_out={after.rows_out}"
            self.note(f"{after.step}: {after.status} {after.message}")
        for s in run.steps:
            self.note(f"step {s.step:<12} {s.status:<8} {s.message}")
        self.note(f"run {run.run_id}: {run.state} {run.message}")
        out.run = run
        return self._write(out)

    def _write(self, out: Outcome) -> Outcome:
        out.folder.mkdir(parents=True, exist_ok=True)
        name = "run.log"
        if out.run is not None:
            self.api.handshakes(out.run, self.pauses.log)
            result, data = self.api.result(out.run)
            (out.folder / result).write_bytes(data)
            self.note(f"result workbook: {out.folder / result}")
            name = f"run_{out.run.run_id}.log"
        log = out.folder / name
        log.write_text("\n".join(self.lines) + "\n", encoding="ascii", errors="replace")
        self.pauses.say(f"  run log: {log}")
        return out
