"""Business 360 "Currently running": every B360 job instance in the org, whoever started it.

Read-only. Two IDMC calls per refresh, both on the MDM host with IDS-SESSION-ID:
  1. POST /job/public/api/v1/search filtered to status RUNNING or QUEUED  -> running jobs
  2. POST /job/public/api/v1/search unfiltered, one page of `row_limit`   -> recent jobs
and one call for a single lookup:
  GET /job/public/api/v1/jobInstance/{id}?details=true

VERIFIED against the Business 360 REST API Reference (Oct 2026) "Search Job Instances" and
"Read Job Instance Summary" (pp. 130-135): request keys search / pageSize / pageOffset /
filters{operator, filter[{fieldName, fieldValue}]}, fieldName one of name / status / jobType;
response keys totalRecords / totalPages / currentPage / jobInstances[], each with id, name,
jobType, jobDefinition.id and _meta{state, startedAt, startedBy, completedAt, isCompleted}
(epoch milliseconds in the example).

UNVERIFIED (not stated in the reference):
  - the exact status fieldValue spelling the filter accepts (we send RUNNING and QUEUED, the
    state names the reference uses); running jobs found in the unfiltered page are merged in
    too, so a filter mismatch cannot hide a running job that is in the recent page;
  - the sort order of an unfiltered search (we sort by startedAt, newest first);
  - whether the search is org-wide or limited to the caller's own jobs (the reference says it
    can search by "the user who started the job instance", which suggests org-wide).

A B360 MDM job is any jobType starting with "b360." or "c360." (Vamsi 2026-11-22: b360.* is
ingress / egress / match-merge; his egress job is c360.egress.etl). Other types (for example
internal.* console uploads) are counted, not listed.
"""

from datetime import UTC, datetime
from typing import Any

from pydantic import BaseModel, Field

from app.common.runs import RunCounts, RunStatus
from app.mdm import endpoints as ep
from app.mdm.client import JOB_INSTANCE_STATES, MdmClient, collect_errors, counts_from_metrics
from app.mdm.models import MdmJobKind
from app.mdm.resolver import kind_from_job_type

B360_TYPE_PREFIXES = ("b360.", "c360.")
RUNNING_STATES = ("RUNNING", "QUEUED")
MAX_ROW_LIMIT = 100


class MdmJobInstanceView(BaseModel):
    """One B360 job instance, as the Currently running view and the lookup show it."""

    instance_id: str = Field(description="Full job instance id, never shortened.")
    name: str
    job_definition_id: str
    job_type: str
    kind: MdmJobKind
    status: RunStatus
    state_text: str = Field(description="IDMC state as sent, e.g. RUNNING.")
    started_at: datetime | None = None
    ended_at: datetime | None = None
    elapsed_minutes: float | None = None
    started_by: str = ""
    counts: RunCounts = Field(default_factory=RunCounts)
    errors: list[str] = Field(default_factory=list)


class MdmMonitorSnapshot(BaseModel):
    as_of: datetime
    running: list[MdmJobInstanceView]
    recent: list[MdmJobInstanceView]
    other_types_hidden: int = Field(
        default=0, description="Instances whose jobType is not b360.* / c360.* (not listed)."
    )
    notes: list[str] = Field(default_factory=list)


def is_b360_type(job_type: str) -> bool:
    return job_type.lower().startswith(B360_TYPE_PREFIXES)


def _epoch_ms(value: Any) -> datetime | None:
    if value in (None, "", 0):
        return None
    if isinstance(value, (int, float)) or str(value).isdigit():
        return datetime.fromtimestamp(int(value) / 1000, tz=UTC)
    try:  # tolerate ISO strings, the reference table calls these fields "String"
        return datetime.fromisoformat(str(value).replace("Z", "+00:00"))
    except ValueError:
        return None


def view_from_instance(body: dict[str, Any], now: datetime) -> MdmJobInstanceView:
    """Translate one jobInstance object (search item or summary read) into the view."""
    meta = body.get("_meta") or {}
    state = str(meta.get("state") or body.get("state") or "")
    job_type = str(body.get("jobType") or "")
    started = _epoch_ms(meta.get("startedAt"))
    ended = _epoch_ms(meta.get("completedAt"))
    status = JOB_INSTANCE_STATES.get(state, RunStatus.UNKNOWN)
    elapsed = None
    if started is not None:
        until = ended if ended is not None else now
        elapsed = round(max((until - started).total_seconds(), 0) / 60, 1)
    return MdmJobInstanceView(
        instance_id=str(body.get("id") or ""),
        name=str(body.get("name") or (body.get("jobDefinition") or {}).get("id") or ""),
        job_definition_id=str((body.get("jobDefinition") or {}).get("id") or ""),
        job_type=job_type,
        kind=kind_from_job_type(job_type),
        status=status,
        state_text=state or "unknown",
        started_at=started,
        ended_at=ended if status.is_terminal else None,
        elapsed_minutes=elapsed,
        started_by=str(meta.get("startedBy") or ""),
        counts=counts_from_metrics(body.get("jobLevelMetrics") or []),
        errors=collect_errors(body.get("steps") or []),
    )


def _newest_first(views: list[MdmJobInstanceView]) -> list[MdmJobInstanceView]:
    floor = datetime.min.replace(tzinfo=UTC)
    return sorted(views, key=lambda v: v.started_at or floor, reverse=True)


def build_snapshot(
    running_items: list[dict[str, Any]],
    recent_items: list[dict[str, Any]],
    row_limit: int,
    now: datetime,
) -> MdmMonitorSnapshot:
    """Pure: merge the two search answers, keep only B360 types, split running / finished."""
    seen: dict[str, MdmJobInstanceView] = {}
    hidden: set[str] = set()
    for item in [*running_items, *recent_items]:
        view = view_from_instance(item, now)
        if not is_b360_type(view.job_type):
            hidden.add(view.instance_id)
            continue
        seen.setdefault(view.instance_id, view)
    views = list(seen.values())
    running = [v for v in views if not v.status.is_terminal]
    recent = [v for v in views if v.status.is_terminal]
    return MdmMonitorSnapshot(
        as_of=now,
        running=_newest_first(running),
        recent=_newest_first(recent)[:row_limit],
        other_types_hidden=len(hidden),
    )


class MdmMonitor:
    def __init__(self, client: MdmClient) -> None:
        self._client = client

    def snapshot(self, row_limit: int) -> MdmMonitorSnapshot:
        limit = max(1, min(row_limit, MAX_ROW_LIMIT))
        running_filter = {
            "operator": "OR",
            "filter": [{"fieldName": "status", "fieldValue": s} for s in RUNNING_STATES],
        }
        running = self._client.search_page(ep.JOB_SEARCH_PAGE_SIZE, 0, running_filter)
        recent = self._client.search_page(limit, 0, None)
        snap = build_snapshot(running, recent, limit, datetime.now(tz=UTC))
        snap.notes.append(
            "Org-wide B360 job search (b360.* and c360.* types), whoever started the job."
        )
        return snap

    def lookup(self, instance_id: str) -> MdmJobInstanceView:
        body = self._client.read_instance(instance_id)
        view = view_from_instance(body, datetime.now(tz=UTC))
        if view.instance_id == "":
            view.instance_id = instance_id
        return view
