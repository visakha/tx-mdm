"""roadrunner command line. Start menu, help, init, run (one or --all), resume, test (BDD).

Every command talks to the tx-mdm backend over HTTP (--base-url or TXMDM_BASE_URL); --local
starts a backend on this machine first. Output is ASCII only.
"""

import argparse
import os
import sys
from collections.abc import Callable, Generator
from contextlib import contextmanager, nullcontext
from pathlib import Path

from roadrunner.api import ApiError, RunPath, TestApi, UseCase
from roadrunner.handshake import Pauses, auto_from_env, load_answers
from roadrunner.local import DEFAULT_BACKEND, local_backend
from roadrunner.runner import ANSWERS, CaseRunner, Outcome, case_dir

GROUPS = ("TTF", "MDM")
DEFAULT_URL = "http://127.0.0.1:8000"


def _ascii_console() -> None:
    for stream in (sys.stdout, sys.stderr):
        reconfigure = getattr(stream, "reconfigure", None)
        if reconfigure is not None:
            reconfigure(encoding="ascii", errors="backslashreplace")


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(prog="roadrunner", description="tx-mdm desktop test runner")
    p.add_argument("--base-url", default=os.environ.get("TXMDM_BASE_URL", DEFAULT_URL))
    p.add_argument("--real", action="store_true", help="real-service path (default: mock path)")
    p.add_argument("--dry-run", action="store_true", help="mock path (the default; explicit)")
    p.add_argument("--local", action="store_true", help="start the backend here (mock path)")
    p.add_argument("--backend-dir", type=Path, default=DEFAULT_BACKEND)
    p.add_argument("--work", type=Path, default=Path(os.environ.get("TXMDM_WORK", "runs")))
    p.add_argument("--auto", action="store_true", help="take the default at every pause")
    p.add_argument(
        "--answers", type=Path, help="answers TOML (default: <case folder>/answers.toml)"
    )
    sub = p.add_subparsers(dest="command")
    sub.add_parser("menu", help="start menu (the default)")
    h = sub.add_parser("help", help="set-up steps, or one use case's sheets and story")
    h.add_argument("group", nargs="?", choices=GROUPS)
    h.add_argument("use_case", nargs="?")
    i = sub.add_parser("init", help="make the test-case folder and download its template")
    i.add_argument("group", choices=GROUPS)
    i.add_argument("use_case")
    i.add_argument("--empty", action="store_true", help="empty template (default: generated)")
    i.add_argument("--rows", type=int)
    r = sub.add_parser("run", help="run one use case, or --all")
    r.add_argument("group", nargs="?", choices=GROUPS)
    r.add_argument("use_case", nargs="?")
    r.add_argument("--all", action="store_true", help="every use case (of GROUP if given)")
    s = sub.add_parser("resume", help="continue a run by run_id")
    s.add_argument("group", choices=GROUPS)
    s.add_argument("use_case")
    s.add_argument("run_id")
    sub.add_parser("test", help="run the BDD features (pytest-bdd) against --base-url")
    return p


class App:
    def __init__(self, args: argparse.Namespace, base_url: str, ask: Callable[[str], str]) -> None:
        self.args, self.ask = args, ask
        self.api = TestApi(base_url, RunPath.REAL if args.real else RunPath.MOCK)
        self.auto = args.auto or auto_from_env()

    def runner(self, group: str, uc: str) -> CaseRunner:
        answers = self.args.answers or case_dir(self.args.work, group, uc) / ANSWERS
        pauses = Pauses(auto=self.auto, answers=load_answers(answers), ask=self.ask)
        return CaseRunner(self.api, pauses, self.args.work)

    def cases(self, group: str | None) -> list[UseCase]:
        return [c for g in GROUPS if group in (None, g) for c in self.api.use_cases(g)]

    def help(self, group: str | None, uc: str | None) -> int:
        if group and uc:
            d = self.api.use_case(group, uc)
            print(f"{group} {uc}: {d.title}\nSheets to fill: {', '.join(d.sheets)}")
            print(f"Pauses: prepare-excel, {', '.join(d.manual_steps)}")
            for block in d.home:
                print(f"[{block.label}]", *[f"  {x}" for x in block.lines], sep="\n")
            return 0
        print(HELP.format(work=self.args.work.resolve(), url=self.api.http.base_url))
        for c in self.cases(group):
            print(f"  {c.group:<4} {c.use_case:<12} {c.title}")
        return 0

    def init(self, group: str, uc: str, empty: bool, rows: int | None) -> int:
        folder = self.runner(group, uc).init(group, uc, generated=not empty, rows=rows)
        print(f"Folder ready: {folder}\n  filled.xlsx   <- fill this, keep Home as the first sheet")
        print("  answers.toml  <- optional scripted answers\n  USE_CASE.txt  <- the story")
        return 0

    def run(self, group: str | None, uc: str | None, every: bool) -> int:
        todo = [(c.group, c.use_case) for c in self.cases(group)] if every else []
        if not every:
            if not (group and uc):
                print("run needs GROUP USE_CASE, or --all")
                return 2
            todo = [(group, uc)]
        results = [self._one(g, u) for g, u in todo]
        print("=" * 72)
        for g, u, out in results:
            state = out.run.state if out.run else "NOT STARTED"
            print(f"{g:<4} {u:<12} {state:<15} {out.folder}")
        passed = sum(out.passed for _, _, out in results)
        print(f"{passed} of {len(results)} passed")
        return 0 if passed == len(results) else 1

    def _one(self, group: str, uc: str) -> tuple[str, str, Outcome]:
        print(f"== {group} {uc} ({self.api.path.value} path)")
        return group, uc, self.runner(group, uc).run(group, uc)

    def resume(self, group: str, uc: str, run_id: str) -> int:
        return 0 if self.runner(group, uc).resume(group, uc, run_id).passed else 1

    def menu(self) -> int:
        while True:
            print("\nroadrunner - tx-mdm tests")
            print("  [1] Help - set me up (default)\n  [2] Run a test case\n  [3] Quit")
            pick = self.ask("Choice: ").strip().lower() or "1"
            if pick in ("3", "q", "quit"):
                return 0
            group = self.ask("Group (TTF / MDM) [TTF]: ").strip().upper() or "TTF"
            if group not in GROUPS:
                print("Group must be TTF or MDM.")
                continue
            if pick in ("1", "help"):
                self.help(group, None)
                uc = self.ask("Use case to set up (e.g. use-case-1, Enter = skip): ").strip()
                if uc:
                    kind = self.ask("Template: [1] generated sample data (default) [2] empty: ")
                    rows = self.ask("Rows (Enter = use-case default): ").strip()
                    self.init(group, uc, kind.strip() == "2", int(rows) if rows.isdigit() else None)
            elif pick in ("2", "run"):
                uc = self.ask("Use case (e.g. use-case-1): ").strip()
                if uc:
                    self.run(group, uc, every=False)


HELP = """Set-up, step by step:
  1. The backend must be running: {url} (or start roadrunner with --local).
  2. Pick a use case below. Run:  roadrunner init TTF use-case-1
     That makes one folder per test case under {work}
     with filled.xlsx (Home sheet first, then the sheets to fill), answers.toml, USE_CASE.txt.
  3. Fill filled.xlsx (or keep the generated sample data). Expected sheets say what should land.
  4. Run:  roadrunner run TTF use-case-1   It pauses at manual steps: Enter = Done.
  5. The result workbook and run log land in the same folder.
  Cleanup of test data is yours: the runner never deletes anything.
Use cases:"""


@contextmanager
def _backend(args: argparse.Namespace) -> Generator[str]:
    with local_backend(args.backend_dir) if args.local else nullcontext(args.base_url) as url:
        yield url


def main(argv: list[str] | None = None, ask: Callable[[str], str] = input) -> int:
    _ascii_console()
    args = build_parser().parse_args(argv)
    if args.local and args.real:
        print("--local is for the mock path only.")
        return 2
    try:
        with _backend(args) as url:
            if args.command == "test":
                import pytest

                os.environ["TXMDM_BASE_URL"] = url
                os.environ["TXMDM_PATH"] = "real" if args.real else "mock"
                if args.auto:
                    os.environ["TXMDM_BDD_AUTO"] = "1"
                return int(pytest.main([str(Path(__file__).resolve().parents[2] / "tests")]))
            app = App(args, url, ask)
            if not app.api.health():
                print(f"Backend not reachable at {url}. Start it, or use --local.")
                return 2
            match args.command:
                case "help":
                    return app.help(args.group, args.use_case)
                case "init":
                    return app.init(args.group, args.use_case, args.empty, args.rows)
                case "run":
                    return app.run(args.group, args.use_case, args.all)
                case "resume":
                    return app.resume(args.group, args.use_case, args.run_id)
                case _:
                    return app.menu()
    except EOFError:
        print("\nInput closed; stopping.")
        return 1
    except ApiError as exc:
        print(f"Backend said no: {exc}")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
