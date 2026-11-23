"""FastAPI app: two routers (CDI, MDM) and a small error mapping. Run: uvicorn app.main:app"""

import sys

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app.b360data import scope as b360_scope
from app.b360data.router import router as b360_router
from app.cdi.router import router as cdi_router
from app.common.idmc_session import IdmcError, IdmcRateLimitedError
from app.common.runs import JobAlreadyRunningError, RunNotFoundError
from app.mdm.router import router as mdm_router
from app.version import HIGHLIGHTS, VERSION


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
            {"name": "meta", "description": "Health."},
        ],
    )
    app.add_middleware(
        CORSMiddleware,
        allow_origins=[frontend_origin],
        allow_methods=["GET", "POST"],
        allow_headers=["Content-Type"],
    )
    app.include_router(cdi_router)
    app.include_router(mdm_router)
    app.include_router(b360_router)

    @app.get("/api/health", tags=["meta"], operation_id="health", summary="Liveness check")
    def health() -> dict[str, str]:
        return {"status": "ok"}

    @app.get("/api/about", tags=["meta"], operation_id="about", summary="Version + top 3")
    def about() -> dict[str, str | list[str]]:
        return {"version": VERSION, "highlights": list(HIGHLIGHTS)}

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

    @app.exception_handler(LookupError)
    def lookup_error(_: Request, exc: LookupError) -> JSONResponse:
        return JSONResponse(status_code=400, content={"detail": str(exc)})

    return app


app = create_app()
