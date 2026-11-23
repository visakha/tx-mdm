"""Shared pieces: the run view the UI renders (same layout for CDI and MDM), errors, run registry.

Only the *shape* of a run result is shared. Sessions, hosts and job lists stay in app.cdi / app.mdm.
"""

import threading
import uuid
from datetime import UTC, datetime
from enum import StrEnum

from pydantic import BaseModel, Field


class RunStatus(StrEnum):
    STARTING = "STARTING"
    QUEUED = "QUEUED"
    RUNNING = "RUNNING"
    SUCCESS = "SUCCESS"
    WARNING = "WARNING"  # completed with errors / warnings
    FAILED = "FAILED"
    STOPPED = "STOPPED"
    UNKNOWN = "UNKNOWN"

    @property
    def is_terminal(self) -> bool:
        return self in {RunStatus.SUCCESS, RunStatus.WARNING, RunStatus.FAILED, RunStatus.STOPPED}


class RunCounts(BaseModel):
    """Ingress / egress style counts. None means Informatica did not report it."""

    source_success: int | None = None
    source_failed: int | None = None
    target_success: int | None = None
    target_failed: int | None = None


class LogLine(BaseModel):
    at: datetime
    message: str


class RunView(BaseModel):
    """What the results screen shows: name, status, start time, log, counts, errors."""

    run_key: str
    service: str  # "cdi" or "mdm"
    job_name: str
    job_kind: str
    status: RunStatus
    started_at: datetime | None = None
    ended_at: datetime | None = None
    log: list[LogLine] = Field(default_factory=list)
    counts: RunCounts = Field(default_factory=RunCounts)
    errors: list[str] = Field(default_factory=list)


def now_utc() -> datetime:
    return datetime.now(UTC)


class RunRegistry:
    """In-memory record of runs started from this backend.

    Enforces one active run per job. Never retries a failed run.
    """

    def __init__(self, service: str) -> None:
        self._service = service
        self._runs: dict[str, RunView] = {}
        self._active_by_job: dict[str, str] = {}
        self._lock = threading.Lock()

    def reserve(self, job_id: str, job_name: str, job_kind: str) -> RunView:
        with self._lock:
            active_key = self._active_by_job.get(job_id)
            if active_key is not None and not self._runs[active_key].status.is_terminal:
                raise JobAlreadyRunningError(job_name)
            run = RunView(
                run_key=uuid.uuid4().hex,
                service=self._service,
                job_name=job_name,
                job_kind=job_kind,
                status=RunStatus.STARTING,
                started_at=now_utc(),
            )
            run.log.append(LogLine(at=now_utc(), message=f"Starting {job_kind} job {job_name}"))
            self._runs[run.run_key] = run
            self._active_by_job[job_id] = run.run_key
            return run

    def get(self, run_key: str) -> RunView:
        run = self._runs.get(run_key)
        if run is None:
            raise RunNotFoundError(run_key)
        return run

    def update_status(self, run: RunView, status: RunStatus, note: str | None = None) -> None:
        """Set status and add a log line only when something changed."""
        if status != run.status:
            run.log.append(LogLine(at=now_utc(), message=note or f"Status: {status.value}"))
            run.status = status
            if status.is_terminal and run.ended_at is None:
                run.ended_at = now_utc()
        elif note and (not run.log or run.log[-1].message != note):
            run.log.append(LogLine(at=now_utc(), message=note))

    def fail(self, run: RunView, error: str) -> None:
        run.errors.append(error)
        self.update_status(run, RunStatus.FAILED, f"Failed: {error}")

    def list_runs(self) -> list[RunView]:
        return sorted(self._runs.values(), key=lambda r: r.started_at or now_utc(), reverse=True)


class JobAlreadyRunningError(Exception):
    def __init__(self, job_name: str) -> None:
        super().__init__(f"{job_name} already has a run in progress")


class RunNotFoundError(Exception):
    def __init__(self, run_key: str) -> None:
        super().__init__(f"No run {run_key} in this backend session")
