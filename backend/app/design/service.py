"""DesignService: list design assets by type and read one asset's metadata (0.9.15). Read-only.

Caches (Refresh on the page passes refresh=true and re-reads):
- runtime environments (id -> name), RUNTIME_CACHE_SECONDS;
- the last list of each v3 type, so opening a row needs no second objects query.
Cached answers make no IDMC call, so Copy IDMC curl then has nothing new for that click.
"""

import time
from datetime import UTC, datetime
from pathlib import PurePosixPath

from app.common.idmc_registry import (
    ConnectionWire,
    MtTaskWire,
    RuntimeEnvironmentWire,
    V3ObjectRow,
    V3ReferenceRow,
)
from app.common.idmc_session import IdmcError, IdmcRateLimitedError
from app.common.portal import PortalLinks
from app.design.client import DesignClient, RefType
from app.design.endpoints import MAX_CHILD_DETAILS
from app.design.models import (
    TYPE_RULES,
    AssetDetail,
    AssetList,
    AssetSummary,
    AssetTypeInfo,
    AssetTypeList,
    DesignAssetType,
    ListSource,
    MappingRef,
    RuntimeEnvironmentRef,
    UsedAsset,
)

RUNTIME_CACHE_SECONDS = 300
LIST_CACHE_SECONDS = 300
TASKFLOW_RUNTIME_NOTE = (
    "A taskflow has no runtime environment of its own (it is orchestrated in the cloud); each "
    "mapping task it uses runs on its own runtime environment - see Uses below."
)


class DesignNotFoundError(Exception):
    """No asset of that type with that id."""


def _now() -> datetime:
    return datetime.now(UTC)


def name_of(path: str, fallback: str) -> str:
    """Last element of an IDMC folder path, read as a typed path (no string splitting)."""
    return PurePosixPath(path).name if path else fallback


def open_type_of(idmc_type: str) -> DesignAssetType | None:
    """IDMC type strings are case-insensitive (Finding an asset); Connection -> CONNECTION."""
    try:
        return DesignAssetType(idmc_type.upper())
    except ValueError:
        return None


def mapping_task_names(refs: list[V3ReferenceRow]) -> list[str]:
    """Names of the mapping tasks among one asset's Uses references (taskflow children)."""
    return sorted(
        name_of(r.path, r.id) for r in refs if open_type_of(r.type) is DesignAssetType.MTT
    )


class DesignService:
    def __init__(self, client: DesignClient, portal: PortalLinks | None = None) -> None:
        self._client = client
        self._portal = portal or PortalLinks("", "")  # 0.9.16: Design asset portal links
        self._runtime: dict[str, RuntimeEnvironmentWire] = {}
        self._runtime_at = 0.0
        self._lists: dict[DesignAssetType, tuple[float, list[V3ObjectRow]]] = {}

    # ---- types ----

    def types(self) -> AssetTypeList:
        return AssetTypeList(
            types=[
                AssetTypeInfo(
                    type=t,
                    label=rule.label,
                    listed_by=rule.lists,
                    detail_by=rule.detail,
                    has_runtime=rule.has_runtime,
                    note=rule.note,
                )
                for t, rule in TYPE_RULES.items()
            ]
        )

    # ---- caches ----

    def _runtimes(self, refresh: bool) -> dict[str, RuntimeEnvironmentWire]:
        fresh = time.monotonic() - self._runtime_at < RUNTIME_CACHE_SECONDS
        if refresh or not fresh or not self._runtime:
            self._runtime = {r.id: r for r in self._client.runtime_environments()}
            self._runtime_at = time.monotonic()
        return self._runtime

    def _v3_rows(self, t: DesignAssetType, refresh: bool) -> tuple[list[V3ObjectRow], bool]:
        kept = self._lists.get(t)
        if not refresh and kept is not None and time.monotonic() - kept[0] < LIST_CACHE_SECONDS:
            return kept[1], True
        rows = self._client.list_objects(t.value)
        self._lists[t] = (time.monotonic(), rows)
        return rows, False

    def _runtime_ref(
        self, runtime_id: str | None, notes: list[str]
    ) -> RuntimeEnvironmentRef | None:
        if not runtime_id:
            return None
        try:
            known = self._runtimes(refresh=False).get(runtime_id)
        except IdmcRateLimitedError:
            raise
        except IdmcError as exc:
            notes.append(f"Runtime environment names unavailable: {exc}")
            return RuntimeEnvironmentRef(id=runtime_id, name=None)
        if known is None:
            notes.append(f"Runtime environment {runtime_id} is not in v2 runtimeEnvironment.")
        return RuntimeEnvironmentRef(id=runtime_id, name=known.name if known else None)

    # ---- list ----

    def list_assets(self, t: DesignAssetType, refresh: bool) -> AssetList:
        rule = TYPE_RULES[t]
        notes: list[str] = []
        match rule.lists:
            case ListSource.V3_OBJECTS:
                rows, cached = self._v3_rows(t, refresh)
                assets = [self._summary(t, r, self._portal) for r in rows]
            case ListSource.V2_CONNECTION:
                cached = False
                assets = [self._connection_summary(c) for c in self._client.connections()]
            case ListSource.V2_RUNTIME_ENVIRONMENT:
                fresh = time.monotonic() - self._runtime_at < RUNTIME_CACHE_SECONDS
                cached = not refresh and fresh and bool(self._runtime)
                assets = [self._runtime_summary(r) for r in self._runtimes(refresh).values()]
        if not assets:
            notes.append(f"IDMC returned no {rule.label} assets for this user.")
        return AssetList(
            type=t,
            label=rule.label,
            as_of=_now(),
            assets=sorted(assets, key=lambda a: a.path.lower()),
            from_cache=cached,
            notes=notes,
        )

    @staticmethod
    def _summary(t: DesignAssetType, row: V3ObjectRow, portal: PortalLinks) -> AssetSummary:
        return AssetSummary(
            portal_url=portal.design_asset(t.value, row.id),
            id=row.id,
            name=name_of(row.path, row.id),
            path=row.path,
            type=t,
            description=row.description or "",
            updated_at=row.updateTime,
            updated_by=row.updatedBy or "",
        )

    @staticmethod
    def _connection_summary(c: ConnectionWire) -> AssetSummary:
        return AssetSummary(
            id=c.id,
            name=c.name or c.id,
            path=c.name or c.id,
            type=DesignAssetType.CONNECTION,
            description=c.description or "",
            updated_at=c.updateTime,
            updated_by=c.updatedBy or "",
        )

    @staticmethod
    def _runtime_summary(r: RuntimeEnvironmentWire) -> AssetSummary:
        return AssetSummary(
            id=r.id,
            name=r.name or r.id,
            path=r.name or r.id,
            type=DesignAssetType.RUNTIME_ENVIRONMENT,
            description=r.description or "",
            updated_at=r.updateTime,
            updated_by=r.updatedBy or "",
        )

    # ---- detail ----

    def detail(self, t: DesignAssetType, asset_id: str, refresh: bool) -> AssetDetail:
        match t:
            case DesignAssetType.MTT:
                return self._mtt_detail(asset_id, refresh)
            case DesignAssetType.DTEMPLATE:
                return self._mapping_detail(asset_id, refresh)
            case DesignAssetType.TASKFLOW | DesignAssetType.DSS | DesignAssetType.WORKFLOW:
                return self._v3_detail(t, asset_id, refresh)
            case DesignAssetType.CONNECTION:
                return self._connection_detail(asset_id)
            case DesignAssetType.RUNTIME_ENVIRONMENT:
                return self._runtime_detail(asset_id, refresh)

    def _row(self, t: DesignAssetType, asset_id: str, refresh: bool) -> V3ObjectRow:
        rows, cached = self._v3_rows(t, refresh)
        found = next((r for r in rows if r.id == asset_id), None)
        if found is None and cached:
            rows, _ = self._v3_rows(t, refresh=True)
            found = next((r for r in rows if r.id == asset_id), None)
        if found is None:
            raise DesignNotFoundError(f"No {TYPE_RULES[t].label} with id {asset_id} in IDMC.")
        return found

    def _base(self, t: DesignAssetType, row: V3ObjectRow) -> AssetDetail:
        return AssetDetail(
            portal_url=self._portal.design_asset(t.value, row.id),
            type=t,
            label=TYPE_RULES[t].label,
            as_of=_now(),
            id=row.id,
            name=name_of(row.path, row.id),
            path=row.path,
            description=row.description or "",
            updated_at=row.updateTime,
            updated_by=row.updatedBy or "",
        )

    def _refs(self, object_id: str, ref_type: RefType, notes: list[str]) -> list[V3ReferenceRow]:
        try:
            return self._client.references(object_id, ref_type)
        except IdmcRateLimitedError:
            raise
        except IdmcError as exc:
            notes.append(f"References ({ref_type.value}) unavailable: {exc}")
            return []

    def _used(self, refs: list[V3ReferenceRow], notes: list[str]) -> list[UsedAsset]:
        out: list[UsedAsset] = []
        detailed = 0
        for ref in sorted(refs, key=lambda r: (r.type.upper(), r.path.lower())):
            kind = open_type_of(ref.type)
            open_id = ref.appContextId if kind is DesignAssetType.CONNECTION else ref.id
            used = UsedAsset(
                id=ref.id,
                v2_id=ref.appContextId,
                name=name_of(ref.path, ref.id),
                path=ref.path,
                type=ref.type,
                open_type=kind if open_id else None,
                open_id=open_id,
                description=ref.description or "",
                updated_at=ref.updateTime,
                portal_url=self._portal.design_asset(ref.type, ref.id),
            )
            if kind is DesignAssetType.MTT:
                if detailed < MAX_CHILD_DETAILS:
                    detailed += 1
                    self._fill_mtt(used, notes)
                else:
                    used.detail_note = f"Not read: only the first {MAX_CHILD_DETAILS} are detailed."
            out.append(used)
        return out

    def _fill_mtt(self, used: UsedAsset, notes: list[str]) -> None:
        try:
            task = (
                self._client.mttask_by_id(used.v2_id)
                if used.v2_id
                else self._client.mttask_by_frs(used.id)
            )
        except IdmcRateLimitedError:
            raise
        except IdmcError as exc:
            used.detail_note = f"v2 mttask unavailable: {exc}"
            return
        used.created_at = task.createTime
        used.created_by = task.createdBy or ""
        used.updated_at = task.updateTime or used.updated_at
        used.updated_by = task.updatedBy or ""
        used.runtime_environment = self._runtime_ref(task.runtimeEnvironmentId, notes)

    def _mtt_detail(self, asset_id: str, refresh: bool) -> AssetDetail:
        detail = self._base(DesignAssetType.MTT, self._row(DesignAssetType.MTT, asset_id, refresh))
        task: MtTaskWire = self._client.mttask_by_frs(asset_id)
        detail.v2_id = task.id
        detail.created_at = task.createTime
        detail.created_by = task.createdBy or ""
        detail.updated_at = task.updateTime or detail.updated_at
        detail.updated_by = task.updatedBy or detail.updated_by
        detail.description = task.description or detail.description
        detail.runtime_environment = self._runtime_ref(task.runtimeEnvironmentId, detail.notes)
        if task.runtimeEnvironmentId is None:
            detail.runtime_note = "IDMC returned no runtimeEnvironmentId for this mapping task."
        if task.mappingId:
            detail.mapping = self._mapping_ref(task.mappingId, detail.notes)
        detail.uses = self._used(self._refs(asset_id, RefType.USES, detail.notes), detail.notes)
        return detail

    def _mapping_ref(self, mapping_id: str, notes: list[str]) -> MappingRef:
        try:
            m = self._client.mapping_by_id(mapping_id)
        except IdmcRateLimitedError:
            raise
        except IdmcError as exc:
            notes.append(f"Mapping {mapping_id} unavailable: {exc}")
            return MappingRef(id=mapping_id)
        return MappingRef(
            id=m.id,
            name=m.name or None,
            created_at=m.createTime,
            created_by=m.createdBy or "",
            updated_at=m.updateTime,
            updated_by=m.updatedBy or "",
        )

    def _mapping_detail(self, asset_id: str, refresh: bool) -> AssetDetail:
        t = DesignAssetType.DTEMPLATE
        detail = self._base(t, self._row(t, asset_id, refresh))
        try:
            found = self._client.mappings_by_name(detail.name)
        except IdmcRateLimitedError:
            raise
        except IdmcError as exc:
            found = []
            detail.notes.append(f"v2 mapping search unavailable: {exc}")
        if len(found) == 1:
            m = found[0]
            detail.v2_id = m.id
            detail.created_at = m.createTime
            detail.created_by = m.createdBy or ""
            detail.updated_at = m.updateTime or detail.updated_at
            detail.updated_by = m.updatedBy or detail.updated_by
        elif len(found) > 1:
            detail.notes.append(
                f"{len(found)} mappings are named {detail.name}; created time / by not shown "
                "because v2 mapping search cannot tell folders apart."
            )
        detail.notes.append("Created / updated by are matched from v2 mapping by name.")
        detail.uses = self._used(self._refs(asset_id, RefType.USES, detail.notes), detail.notes)
        detail.used_by = self._used(
            self._refs(asset_id, RefType.USED_BY, detail.notes), detail.notes
        )
        return detail

    def _v3_detail(self, t: DesignAssetType, asset_id: str, refresh: bool) -> AssetDetail:
        detail = self._base(t, self._row(t, asset_id, refresh))
        detail.notes.append(TYPE_RULES[t].note)
        if t is DesignAssetType.TASKFLOW:
            detail.runtime_note = TASKFLOW_RUNTIME_NOTE
        detail.uses = self._used(self._refs(asset_id, RefType.USES, detail.notes), detail.notes)
        return detail

    def _connection_detail(self, asset_id: str) -> AssetDetail:
        c = self._client.connection(asset_id)
        detail = AssetDetail(
            type=DesignAssetType.CONNECTION,
            label=TYPE_RULES[DesignAssetType.CONNECTION].label,
            as_of=_now(),
            id=c.id,
            v2_id=c.id,
            name=c.name or c.id,
            path=c.name or c.id,
            description=c.description or "",
            created_at=c.createTime,
            created_by=c.createdBy or "",
            updated_at=c.updateTime,
            updated_by=c.updatedBy or "",
            connection_type=c.type,
        )
        detail.runtime_environment = self._runtime_ref(c.runtimeEnvironmentId, detail.notes)
        detail.notes.append(TYPE_RULES[DesignAssetType.CONNECTION].note)
        return detail

    def _runtime_detail(self, asset_id: str, refresh: bool) -> AssetDetail:
        r = self._runtimes(refresh).get(asset_id)
        if r is None:
            raise DesignNotFoundError(f"No runtime environment with id {asset_id} in IDMC.")
        return AssetDetail(
            type=DesignAssetType.RUNTIME_ENVIRONMENT,
            label=TYPE_RULES[DesignAssetType.RUNTIME_ENVIRONMENT].label,
            as_of=_now(),
            id=r.id,
            v2_id=r.id,
            name=r.name or r.id,
            path=r.name or r.id,
            description=r.description or "",
            created_at=r.createTime,
            created_by=r.createdBy or "",
            updated_at=r.updateTime,
            updated_by=r.updatedBy or "",
            is_shared=r.isShared,
        )
