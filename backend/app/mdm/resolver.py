"""Resolve a listed job definition asset to the internal jobDefinitionId + job type.

UNVERIFIED AND PLUGGABLE. The documented list call (v3 objects, MDM_JOB_DEFINITION) gives name and
path but not the internal id the run calls need, nor whether the job is ingress, egress or
match-merge. The default resolver below matches assets against recent job instances from the B360
job search. A job that has never run cannot be resolved this way and shows as not runnable.

To swap strategy (e.g. read the id from an export package once its format is confirmed), write
another class with the same `resolve` method and wire it in app/dependencies.py.
"""

import re
import threading
import time
from collections.abc import Callable
from typing import Any, Protocol

from app.mdm import endpoints as ep
from app.mdm.models import MdmJobAsset, MdmJobKind, ResolvedDefinition


class JobDefinitionResolver(Protocol):
    def resolve(self, assets: list[MdmJobAsset]) -> dict[str, ResolvedDefinition]:
        """Return asset_id -> resolved definition, for the assets it could resolve."""
        ...


def kind_from_job_type(job_type: str) -> MdmJobKind:
    lowered = job_type.lower()
    if job_type == ep.JOB_TYPE_INGRESS or ".ingress." in lowered:
        return MdmJobKind.INGRESS
    if job_type == ep.JOB_TYPE_MATCH_MERGE or "matchmerge" in lowered:
        return MdmJobKind.MATCH_MERGE
    if "egress" in lowered:  # egress jobType undocumented: recognise it, don't hard-code it
        return MdmJobKind.EGRESS
    return MdmJobKind.UNKNOWN


def normalise(name: str) -> str:
    return re.sub(r"[^a-z0-9]+", "_", name.lower()).strip("_")


def definitions_from_instances(instances: list[dict[str, Any]]) -> dict[str, ResolvedDefinition]:
    """jobDefinition.id -> definition, skipping console file-import runs and training jobs."""
    found: dict[str, ResolvedDefinition] = {}
    for instance in instances:
        definition_id = str((instance.get("jobDefinition") or {}).get("id") or "")
        job_type = str(instance.get("jobType") or "")
        if not definition_id or definition_id == ep.CONSOLE_FILE_IMPORT_JOB:
            continue
        kind = kind_from_job_type(job_type)
        if kind is MdmJobKind.UNKNOWN:
            continue
        found.setdefault(
            definition_id,
            ResolvedDefinition(job_definition_id=definition_id, job_type=job_type, kind=kind),
        )
    return found


def match_assets(
    assets: list[MdmJobAsset], definitions: dict[str, ResolvedDefinition]
) -> dict[str, ResolvedDefinition]:
    """Match on exact id == asset name, else on a normalised form of both."""
    by_normalised = {normalise(def_id): d for def_id, d in definitions.items()}
    resolved: dict[str, ResolvedDefinition] = {}
    for asset in assets:
        hit = definitions.get(asset.name) or by_normalised.get(normalise(asset.name))
        if hit is not None:
            resolved[asset.asset_id] = hit
    return resolved


class JobSearchResolver:
    """Default resolver: B360 job search, cached for `cache_seconds`."""

    def __init__(
        self,
        search_instances: Callable[[], list[dict[str, Any]]],
        cache_seconds: int,
        clock: Callable[[], float] = time.monotonic,
    ) -> None:
        self._search_instances = search_instances
        self._cache_seconds = cache_seconds
        self._clock = clock
        self._cached: dict[str, ResolvedDefinition] | None = None
        self._cached_at = 0.0
        self._lock = threading.Lock()

    def resolve(self, assets: list[MdmJobAsset]) -> dict[str, ResolvedDefinition]:
        return match_assets(assets, self._definitions())

    def _definitions(self) -> dict[str, ResolvedDefinition]:
        with self._lock:
            expired = self._clock() - self._cached_at > self._cache_seconds
            if self._cached is None or expired:
                self._cached = definitions_from_instances(self._search_instances())
                self._cached_at = self._clock()
            return self._cached
