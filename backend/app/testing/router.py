"""HTTP routes for the testing harness. Mock path: /api/test/mock/{group}/... (everything faked,
SQLite for the source and egress tables). Real path: /api/test/{group}/... (real services; reports
NOT_CONFIGURED until the placeholders in test_cases/test_config.toml are real).
"""

from typing import Annotated

from fastapi import APIRouter, Depends, File, HTTPException, Path, Query, UploadFile
from fastapi.responses import JSONResponse, Response

from app.testing import workbooks
from app.testing.cases import HomeBlock, UseCase, find_case, load_config, use_cases
from app.testing.generate import generate
from app.testing.models import (
    Comparison,
    ContinueRequest,
    Group,
    Handshake,
    PreflightReport,
    RunPath,
    RunView,
    TemplateMode,
    UseCaseSummary,
)
from app.testing.runs import PreflightFailedError, RunConflictError, RunStore, get_store
from app.testing.sheets import group_sheets, read_workbook

XLSX = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
Store = Annotated[RunStore, Depends(get_store)]
Upload = Annotated[UploadFile, File(description="The filled .xlsx workbook.")]


class UseCaseDetail(UseCaseSummary):
    home: list[HomeBlock]


def _case(group: Group, use_case: Annotated[str, Path(examples=["use-case-1"])]) -> UseCase:
    try:
        return find_case(group, use_case)
    except LookupError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


Case = Annotated[UseCase, Depends(_case)]


def _summary(case: UseCase) -> UseCaseSummary:
    return UseCaseSummary(
        group=case.group,
        use_case=case.use_case,
        title=case.title,
        template_version=case.template_version,
        sheets=[s.name for s in group_sheets(case.group)],
        manual_steps=load_config().pipeline[case.group].manual_steps,
        default_rows=case.mock.default_rows,
    )


def _xlsx(name: str, data: bytes) -> Response:
    return Response(
        data, media_type=XLSX, headers={"Content-Disposition": f'attachment; filename="{name}"'}
    )


def make_router(path: RunPath) -> APIRouter:
    prefix = "/api/test/mock/{group}" if path == RunPath.MOCK else "/api/test/{group}"
    tag = f"test-{path.value}"
    op = f"test_{path.value}_"
    router = APIRouter(prefix=prefix, tags=[tag])

    def owned(store: RunStore, case: UseCase, run_id: str) -> RunView:
        run = store.get(run_id)
        if (run.path, run.group, run.use_case) != (path, case.group, case.use_case):
            raise HTTPException(status_code=404, detail=f"run {run_id} is not under this path")
        return run

    @router.get("/use-cases", operation_id=op + "use_cases", summary="List the use cases")
    def list_cases(group: Group) -> list[UseCaseSummary]:
        return [_summary(c) for c in use_cases(group)]

    @router.get("/{use_case}", operation_id=op + "use_case", summary="One use case + Home text")
    def one_case(case: Case) -> UseCaseDetail:
        return UseCaseDetail(**_summary(case).model_dump(), home=case.home)

    @router.get(
        "/{use_case}/template",
        operation_id=op + "template",
        summary="Download the Excel template (empty, or generated data with Expected pre-filled)",
        response_class=Response,
        responses={200: {"content": {XLSX: {}}}},
    )
    def template(
        case: Case,
        mode: TemplateMode = TemplateMode.EMPTY,
        rows: Annotated[int | None, Query(ge=1, le=500)] = None,
    ) -> Response:
        n = rows or case.mock.default_rows
        data = generate(case, n) if mode == TemplateMode.GENERATED else {}
        name = f"{case.group.value}_{case.use_case}_template_v{case.template_version}.xlsx"
        return _xlsx(name, workbooks.template(case, mode, data))

    @router.post(
        "/{use_case}/preflight",
        operation_id=op + "preflight",
        summary="Check a filled workbook without starting a run",
    )
    async def preflight(case: Case, file: Upload) -> PreflightReport:
        return read_workbook(await file.read(), case)[1]

    @router.post(
        "/{use_case}/runs",
        operation_id=op + "start_run",
        summary="Upload a filled workbook and start a run -> run_id",
        responses={422: {"model": PreflightReport}, 409: {"description": "real path busy"}},
    )
    async def start(case: Case, file: Upload, store: Store) -> RunView:
        return store.start(path, case, await file.read())

    @router.get("/{use_case}/runs/{run_id}", operation_id=op + "run", summary="Per-step status")
    def status(case: Case, run_id: str, store: Store) -> RunView:
        return owned(store, case, run_id)

    @router.post(
        "/{use_case}/runs/{run_id}/continue",
        operation_id=op + "continue",
        summary="The tester finished a manual step (done / retry / skip / abort)",
    )
    def resume(case: Case, run_id: str, req: ContinueRequest, store: Store) -> RunView:
        owned(store, case, run_id)
        return store.resume(run_id, req)

    @router.post("/{use_case}/runs/{run_id}/abort", operation_id=op + "abort", summary="Stop")
    def abort(case: Case, run_id: str, store: Store) -> RunView:
        owned(store, case, run_id)
        return store.abort(run_id)

    @router.post(
        "/{use_case}/runs/{run_id}/handshakes",
        operation_id=op + "handshakes",
        summary="Record the runner's handshakes (go to the Handshakes sheet)",
    )
    def handshakes(case: Case, run_id: str, items: list[Handshake], store: Store) -> RunView:
        owned(store, case, run_id)
        return store.set_handshakes(run_id, items)

    @router.get(
        "/{use_case}/runs/{run_id}/comparison",
        operation_id=op + "comparison",
        summary="Expected vs actual, pass/fail per check",
    )
    def comparison(case: Case, run_id: str, store: Store) -> Comparison:
        owned(store, case, run_id)
        return store.comparison(run_id)

    @router.get(
        "/{use_case}/runs/{run_id}/result",
        operation_id=op + "result",
        summary="Download the result workbook (Home, Handshakes, Steps, Comparison, tables)",
        response_class=Response,
        responses={200: {"content": {XLSX: {}}}},
    )
    def result(case: Case, run_id: str, store: Store) -> Response:
        owned(store, case, run_id)
        return _xlsx(*store.result(run_id))

    return router


def preflight_failed(_: object, exc: PreflightFailedError) -> JSONResponse:
    return JSONResponse(status_code=422, content=exc.report.model_dump(mode="json"))


def run_conflict(_: object, exc: RunConflictError) -> JSONResponse:
    return JSONResponse(status_code=409, content={"detail": str(exc)})
