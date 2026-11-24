"""Typed client for the tx-mdm /api/test routes. Shapes mirror the backend models by name."""

from datetime import datetime
from enum import StrEnum

import httpx
from pydantic import BaseModel, TypeAdapter


class RunPath(StrEnum):
    MOCK = "mock"
    REAL = "real"


class Answer(StrEnum):
    DONE = "done"
    RETRY = "retry"
    SKIP = "skip"
    ABORT = "abort"


class UseCase(BaseModel):
    group: str
    use_case: str
    title: str
    template_version: str
    sheets: list[str]
    manual_steps: list[str]
    default_rows: int


class HomeBlock(BaseModel):
    label: str
    lines: list[str]


class UseCaseDetail(UseCase):
    home: list[HomeBlock]


class Issue(BaseModel):
    sheet: str
    row: int | None = None
    column: str | None = None
    message: str


class Preflight(BaseModel):
    ok: bool
    template_version: str | None
    rows_per_sheet: dict[str, int]
    issues: list[Issue]


class StepView(BaseModel):
    step: str
    status: str
    manual: bool
    rows_in: int | None = None
    rows_out: int | None = None
    message: str = ""
    errors: list[str] = []


class Handshake(BaseModel):
    title: str
    answer: Answer
    source: str
    at: datetime
    verified: str = ""


class Run(BaseModel):
    run_id: str
    path: RunPath
    group: str
    use_case: str
    state: str
    message: str = ""
    steps: list[StepView]

    @property
    def terminal(self) -> bool:
        return self.state not in ("RUNNING", "WAITING")

    def open_step(self) -> StepView | None:
        """The manual step waiting for the tester, or a failed step that can be retried."""
        return next((s for s in self.steps if s.status in ("WAITING", "FAILED")), None)


class CompareRow(BaseModel):
    check: str
    clientcode: str
    field: str
    expected: str
    actual: str
    passed: bool


class Comparison(BaseModel):
    run_id: str
    passed: bool
    checked: int
    failed: int
    rows: list[CompareRow]


class ApiError(Exception):
    def __init__(self, response: httpx.Response) -> None:
        super().__init__(
            f"HTTP {response.status_code} {response.request.url.path}: {response.text[:400]}"
        )
        self.status_code = response.status_code


_CASES = TypeAdapter(list[UseCase])


class TestApi:
    __test__ = False  # not a pytest class

    def __init__(self, base_url: str, path: RunPath = RunPath.MOCK, timeout: float = 60) -> None:
        self.http = httpx.Client(base_url=base_url.rstrip("/"), timeout=timeout, trust_env=False)
        self.path = path

    def _root(self, group: str) -> str:
        return f"/api/test/mock/{group}" if self.path == RunPath.MOCK else f"/api/test/{group}"

    def _ok(self, response: httpx.Response) -> httpx.Response:
        if response.status_code >= 400:
            raise ApiError(response)
        return response

    def health(self) -> bool:
        try:
            return self.http.get("/api/health").status_code == 200
        except httpx.HTTPError:
            return False

    def use_cases(self, group: str) -> list[UseCase]:
        return _CASES.validate_json(
            self._ok(self.http.get(f"{self._root(group)}/use-cases")).content
        )

    def use_case(self, group: str, uc: str) -> UseCaseDetail:
        body = self._ok(self.http.get(f"{self._root(group)}/{uc}")).content
        return UseCaseDetail.model_validate_json(body)

    def template(self, group: str, uc: str, generated: bool, rows: int | None) -> bytes:
        params: dict[str, str | int] = {"mode": "generated" if generated else "empty"}
        if rows:
            params["rows"] = rows
        return self._ok(self.http.get(f"{self._root(group)}/{uc}/template", params=params)).content

    def preflight(self, group: str, uc: str, data: bytes) -> Preflight:
        files = {"file": ("filled.xlsx", data)}
        response = self._ok(self.http.post(f"{self._root(group)}/{uc}/preflight", files=files))
        return Preflight.model_validate_json(response.content)

    def start(self, group: str, uc: str, data: bytes) -> Run:
        files = {"file": ("filled.xlsx", data)}
        response = self._ok(self.http.post(f"{self._root(group)}/{uc}/runs", files=files))
        return Run.model_validate_json(response.content)

    def run(self, group: str, uc: str, run_id: str) -> Run:
        response = self._ok(self.http.get(f"{self._root(group)}/{uc}/runs/{run_id}"))
        return Run.model_validate_json(response.content)

    def answer(self, run: Run, step: str, answer: Answer) -> Run:
        url = f"{self._root(run.group)}/{run.use_case}/runs/{run.run_id}/continue"
        body = {"step": step, "answer": answer.value}
        return Run.model_validate_json(self._ok(self.http.post(url, json=body)).content)

    def handshakes(self, run: Run, items: list[Handshake]) -> None:
        url = f"{self._root(run.group)}/{run.use_case}/runs/{run.run_id}/handshakes"
        self._ok(self.http.post(url, json=[h.model_dump(mode="json") for h in items]))

    def comparison(self, run: Run) -> Comparison | None:
        url = f"{self._root(run.group)}/{run.use_case}/runs/{run.run_id}/comparison"
        response = self.http.get(url)
        return (
            Comparison.model_validate_json(response.content)
            if response.status_code == 200
            else None
        )

    def result(self, run: Run) -> tuple[str, bytes]:
        url = f"{self._root(run.group)}/{run.use_case}/runs/{run.run_id}/result"
        response = self._ok(self.http.get(url))
        disposition = response.headers.get("content-disposition", "")
        name = disposition.partition("filename=")[2].strip('"') or f"result_{run.run_id}.xlsx"
        return name, response.content
