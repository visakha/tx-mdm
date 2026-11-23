"""MdmClient: every Informatica call the MDM side makes."""

from dataclasses import dataclass, field
from datetime import UTC, datetime
from typing import Any

from app.common import idmc_registry as idmc
from app.common.idmc_session import IdmcHttp
from app.common.runs import RunCounts, RunStatus
from app.mdm import endpoints as ep
from app.mdm.models import MdmJobAsset, MdmJobKind


@dataclass
class MdmRunSnapshot:
    status: RunStatus
    note: str
    counts: RunCounts = field(default_factory=RunCounts)
    errors: list[str] = field(default_factory=list)
    started_at: datetime | None = None
    ended_at: datetime | None = None


class MdmClient:
    def __init__(self, http: IdmcHttp, mdm_url: str, platform_url_override: str = "") -> None:
        self._http = http
        self._mdm_url = mdm_url.rstrip("/")
        self._platform_url_override = platform_url_override.rstrip("/")

    def _platform_url(self) -> str:
        return self._platform_url_override or self._http.session.current().base_api_url.rstrip("/")

    def list_job_definitions(self) -> list[MdmJobAsset]:
        assets: list[MdmJobAsset] = []
        skip = 0
        while True:
            body = self._http.request(
                idmc.PLATFORM_OBJECTS,
                self._platform_url() + ep.OBJECTS,
                params={
                    "q": f"type=='{ep.JOB_DEFINITION_ASSET_TYPE}'",
                    "limit": ep.PAGE_SIZE,
                    "skip": skip,
                },
            )
            objects = (body or {}).get("objects", [])
            assets.extend(to_asset(obj) for obj in objects)
            if len(objects) < ep.PAGE_SIZE:
                return sorted(assets, key=lambda a: a.path.lower())
            skip += ep.PAGE_SIZE

    def search_job_instances(self) -> list[dict[str, Any]]:
        """Recent job instances (each carries jobDefinition.id and jobType). Bounded paging."""
        instances: list[dict[str, Any]] = []
        for page in range(ep.JOB_SEARCH_MAX_PAGES):
            body = self._http.request(
                idmc.JOB_SEARCH,
                self._mdm_url + ep.JOB_SEARCH,
                json={"search": "*", "pageSize": ep.JOB_SEARCH_PAGE_SIZE, "pageOffset": page},
            )
            body = body or {}
            instances.extend(body.get("jobInstances", []))
            if page + 1 >= int(body.get("totalPages", 0)):
                break
        return instances

    def search_page(
        self, page_size: int, page_offset: int, filters: dict[str, Any] | None
    ) -> list[dict[str, Any]]:
        """One page of the B360 job search (read-only). `filters` as in the reference."""
        payload: dict[str, Any] = {"search": "*", "pageSize": page_size, "pageOffset": page_offset}
        if filters is not None:
            payload["filters"] = filters
        body = self._http.request(idmc.JOB_SEARCH, self._mdm_url + ep.JOB_SEARCH, json=payload)
        items = (body or {}).get("jobInstances") or []
        return [item for item in items if isinstance(item, dict)]

    def read_instance(self, instance_id: str) -> dict[str, Any]:
        """Raw job instance summary (details=true), read-only."""
        body = self._http.request(
            idmc.JOB_INSTANCE_READ,
            self._mdm_url + ep.JOB_INSTANCE_READ.format(instance_id=instance_id),
            params={"details": "true"},
        )
        return body if isinstance(body, dict) else {}

    def start(self, kind: MdmJobKind, job_definition_id: str) -> str:
        if kind is MdmJobKind.UNKNOWN:
            raise ValueError("job kind unknown; refusing to guess which run endpoint to call")
        body = self._http.request(
            idmc.JOB_INSTANCE_RUN,
            self._mdm_url + ep.JOB_INSTANCE_RUN.format(kind=kind.value),
            json={"jobDefinitionId": job_definition_id},
        )
        return str(body["id"])

    def check(self, instance_id: str) -> MdmRunSnapshot:
        body = self._http.request(
            idmc.JOB_INSTANCE_READ,
            self._mdm_url + ep.JOB_INSTANCE_READ.format(instance_id=instance_id),
            params={"details": "true"},
        )
        return snapshot_from_job_instance(body or {})


# ---- pure translation functions (unit tested) ------------------------------------------------


def to_asset(obj: dict[str, Any]) -> MdmJobAsset:
    path = str(obj.get("path", ""))
    return MdmJobAsset(
        asset_id=str(obj["id"]),
        name=path.rsplit("/", 1)[-1] if path else str(obj["id"]),
        path=path,
        description=str(obj.get("description") or ""),
        updated_at=obj.get("updateTime"),
    )


JOB_INSTANCE_STATES: dict[str, RunStatus] = {
    "QUEUED": RunStatus.QUEUED,
    "RUNNING": RunStatus.RUNNING,
    "SUCCESS": RunStatus.SUCCESS,
    "WARNING": RunStatus.WARNING,
    "FAILED": RunStatus.FAILED,
    "STOPPED": RunStatus.STOPPED,
    "SKIPPED": RunStatus.STOPPED,
}


def _epoch_ms(value: Any) -> datetime | None:
    return datetime.fromtimestamp(int(value) / 1000, tz=UTC) if value else None


def counts_from_metrics(metrics: list[dict[str, Any]]) -> RunCounts:
    """Map jobLevelMetrics (INPUT / SUCCESS / FAILED rows) onto the counts panel."""
    by_id = {m.get("id"): m.get("value") for m in metrics}
    return RunCounts(
        source_success=by_id.get("NUM_OF_INCOMING_RECORDS"),
        source_failed=by_id.get("NUM_OF_REC_FAILED"),
        target_success=by_id.get("NUM_OF_REC_LOAD_CREATED", by_id.get("NUM_OF_REC_SUCCEEDED")),
        target_failed=by_id.get("NUM_OF_REC_LOAD_FAILED"),
    )


def collect_errors(node: Any) -> list[str]:
    """Pick up any error/message text in the details payload (shape not fully documented)."""
    found: list[str] = []
    if isinstance(node, dict):
        for key, value in node.items():
            if (
                isinstance(value, str)
                and value
                and key.lower() in {"errormessage", "errormsg", "error", "failuremessage"}
            ):
                found.append(value)
            else:
                found.extend(collect_errors(value))
    elif isinstance(node, list):
        for item in node:
            found.extend(collect_errors(item))
    return list(dict.fromkeys(found))


def snapshot_from_job_instance(body: dict[str, Any]) -> MdmRunSnapshot:
    meta = body.get("_meta") or {}
    state = str(meta.get("state", ""))
    return MdmRunSnapshot(
        status=JOB_INSTANCE_STATES.get(state, RunStatus.UNKNOWN),
        note=f"Job instance: {state or 'unknown'}",
        counts=counts_from_metrics(body.get("jobLevelMetrics") or []),
        errors=collect_errors(body.get("steps") or []),
        started_at=_epoch_ms(meta.get("startedAt")),
        ended_at=_epoch_ms(meta.get("completedAt")),
    )
