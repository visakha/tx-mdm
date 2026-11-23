"""FastAPI app: two routers (CDI, MDM) and a small error mapping. Run: uvicorn app.main:app"""

import logging
import sys
from collections.abc import Awaitable, Callable

from fastapi import Depends, FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.openapi.docs import get_swagger_ui_html
from fastapi.responses import HTMLResponse, JSONResponse, Response
from pydantic import JsonValue

from app.b360data import scope as b360_scope
from app.b360data import typed_openapi
from app.b360data.router import router as b360_router
from app.b360data.service import B360DataService
from app.cdi.router import router as cdi_router
from app.common import idmc_echo, idmc_openapi
from app.common.idmc_session import IdmcError, IdmcRateLimitedError
from app.common.runs import JobAlreadyRunningError, RunNotFoundError
from app.dependencies import get_b360_data_service
from app.design.router import router as design_router
from app.mdm.router import router as mdm_router
from app.version import HIGHLIGHTS, VERSION

log = logging.getLogger("tx_mdm")


def _force_ascii_console() -> None:
    """Terminal output is ASCII only (Windows terminals garble anything else).

    Any non-ASCII text that still reaches stdout/stderr at runtime (for example a job name
    coming back from IDMC) is written as a backslash escape instead of raw Unicode.
    """
    for stream in (sys.stdout, sys.stderr):
        reconfigure = getattr(stream, "reconfigure", None)
        if reconfigure is not None:
            reconfigure(encoding="ascii", errors="backslashreplace")


_force_ascii_console()


def create_app(frontend_origin: str = "http://localhost:5173") -> FastAPI:
    # Read backend/b360_entities.toml now, so a bad file stops startup with a clear error.
    b360_scope.focus_config()
    app = FastAPI(
        title="TX MDM job runner",
        version=VERSION,
        description=(
            "Runs and monitors Informatica IDMC jobs. Two separate services: `cdi` (Data "
            "Integration tasks) and `mdm` (Business 360 ingress / egress / match-merge). "
            "Flow for both: list -> start run -> poll the run until a final status. "
            "One active run per job; failed runs are never retried; HTTP 429 from IDMC is "
            "returned as 429 and not retried."
        ),
        openapi_tags=[
            {"name": "cdi", "description": "Data Integration (CDI) tasks and runs."},
            {"name": "mdm", "description": "Business 360 (MDM) job definitions and runs."},
            {
                "name": "b360",
                "description": "Business 360 data: entities, metadata, first records (read-only).",
            },
            {
                "name": "design",
                "description": "CDI design assets: types, lists, metadata (read-only, 0.9.15).",
            },
            {"name": "meta", "description": "Health."},
        ],
    )
    app.add_middleware(
        CORSMiddleware,
        allow_origins=[frontend_origin],
        allow_methods=["GET", "POST"],
        allow_headers=["Content-Type"],
        expose_headers=["X-Idmc-Echo-Id"],
    )

    @app.middleware("http")
    async def idmc_echo_mw(
        request: Request, call_next: Callable[[Request], Awaitable[Response]]
    ) -> Response:
        recorded = idmc_echo.begin()
        response = await call_next(request)
        echo_id = idmc_echo.finish(recorded, request.method, request.url.path)
        if echo_id is not None:
            response.headers["X-Idmc-Echo-Id"] = echo_id
        return response

    @app.get(
        "/api/idmc/echo/{echo_id}",
        tags=["meta"],
        operation_id="idmc_echo",
        response_model=idmc_echo.IdmcEcho,
        summary="Copy IDMC curl: the exact IDMC calls one tx-mdm call made, as runnable scripts",
        description="echo_id = the X-Idmc-Echo-Id header of a tx-mdm response. Returns the IDMC "
        "calls (method, full URL, session header NAMES, JSON body) plus PowerShell (curl.exe) and "
        "bash scripts that log in with $env:IDMC_PASSWORD and repeat them against IDMC. Never "
        "contains the session id or password. Last 200 kept in memory; lost on restart.",
    )
    def idmc_echo_read(echo_id: str) -> idmc_echo.IdmcEcho:
        echo = idmc_echo.get(echo_id)
        if echo is None:
            raise HTTPException(status_code=404, detail="echo not kept (expired or restarted)")
        return echo

    app.include_router(cdi_router)
    app.include_router(mdm_router)
    app.include_router(b360_router)
    app.include_router(design_router)

    @app.get("/api/health", tags=["meta"], operation_id="health", summary="Liveness check")
    def health() -> dict[str, str]:
        return {"status": "ok"}

    @app.get("/api/about", tags=["meta"], operation_id="about", summary="Version + top 3")
    def about() -> dict[str, str | list[str]]:
        return {"version": VERSION, "highlights": list(HIGHLIGHTS)}

    # 0.9.12 (Vamsi 02:32 CST): a second, concrete spec next to /openapi.json - the same spec
    # plus typed schemas and paths per focus business entity, built from live metadata.
    @app.get("/openapi-typed.json", include_in_schema=False)
    def openapi_typed(
        service: B360DataService = Depends(get_b360_data_service),  # noqa: B008
    ) -> dict[str, JsonValue]:
        base: dict[str, JsonValue] = app.openapi()
        try:
            entities, warnings = service.typed_entities()
        except Exception as exc:  # noqa: BLE001 - never 500: base spec + warning
            entities, warnings = [], [f"typed entities not built ({type(exc).__name__}: {exc})"]
        return typed_openapi.build(base, entities, warnings)

    @app.get("/docs-typed", include_in_schema=False)
    def docs_typed() -> HTMLResponse:
        return get_swagger_ui_html(
            openapi_url="/openapi-typed.json", title="TX MDM API (typed per business entity)"
        )

    # 0.9.14 (Vamsi 03:15 CST): a THIRD spec, IDMC calls only, from the typed registry.
    @app.get("/openapi-idmc.json", include_in_schema=False)
    def openapi_idmc() -> dict[str, object]:
        return idmc_openapi.build()

    @app.get("/docs-idmc", include_in_schema=False)
    def docs_idmc() -> HTMLResponse:
        return get_swagger_ui_html(
            openapi_url="/openapi-idmc.json", title="IDMC calls made by tx-mdm"
        )

    @app.exception_handler(IdmcRateLimitedError)
    def rate_limited(_: Request, exc: IdmcRateLimitedError) -> JSONResponse:
        return JSONResponse(status_code=429, content={"detail": exc.message})

    @app.exception_handler(IdmcError)
    def idmc_error(_: Request, exc: IdmcError) -> JSONResponse:
        return JSONResponse(status_code=502, content={"detail": str(exc)})

    @app.exception_handler(JobAlreadyRunningError)
    def already_running(_: Request, exc: JobAlreadyRunningError) -> JSONResponse:
        return JSONResponse(status_code=409, content={"detail": str(exc)})

    @app.exception_handler(RunNotFoundError)
    def run_not_found(_: Request, exc: RunNotFoundError) -> JSONResponse:
        return JSONResponse(status_code=404, content={"detail": str(exc)})

    @app.exception_handler(Exception)
    def unexpected(request: Request, exc: Exception) -> JSONResponse:
        # Never a bare "Internal Server Error": say where and what, so the UI can show it.
        log.exception("unhandled error on %s %s", request.method, request.url.path)
        return JSONResponse(
            status_code=500,
            content={
                "detail": f"Backend error on {request.method} {request.url.path}: "
                f"{type(exc).__name__}: {exc}. Full traceback is in the backend window."
            },
        )

    @app.exception_handler(LookupError)
    def lookup_error(_: Request, exc: LookupError) -> JSONResponse:
        return JSONResponse(status_code=400, content={"detail": str(exc)})

    return app


app = create_app()
