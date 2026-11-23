"""B360 Data: business entities -> metadata -> first N records. Read-only, never retried.

IDMC JSON is parsed into typed models in app.b360data.wire, right where it arrives.
"""

import math
import time
from datetime import datetime
from urllib.parse import quote

import httpx

from app.b360data import endpoints as ep
from app.b360data import forms, testdata, wire
from app.b360data import scope as entity_scope
from app.b360data.models import (
    AppliedFilter,
    BusinessEntity,
    BusinessEntityList,
    BusinessEntitySummary,
    CreateOutcome,
    CreateRequest,
    CreateResponse,
    CreateResult,
    DiscoveryStatus,
    EntityField,
    EntityRecord,
    EntityScope,
    FieldDataType,
    FocusEntityStatus,
    FormSchema,
    GeneratedRows,
    GenerateRequest,
    LookupMode,
    LookupStatus,
    MergeFieldRow,
    MergeOverride,
    MergePreview,
    MergePreviewRequest,
    MergeRequest,
    MergeResponse,
    MergeStep,
    MergeStepName,
    MergeStepStatus,
    NameFilterComparator,
    PatchOperation,
    PicklistOption,
    PicklistSource,
    RecordPage,
    SortOrder,
    SourceKey,
    SourceRecord,
    SourceRecordList,
    SourceSystemList,
    UnmergeRequest,
    UnmergeResponse,
    UpdateSourceRequest,
    UpdateSourceResponse,
)
from app.common.idmc_session import IdmcError, IdmcHttp, IdmcRateLimitedError


class B360InputError(ValueError):
    """A request the backend refuses before calling IDMC (shown as 400)."""


class SourceRecordNotFoundError(LookupError):
    """Read Source Record answered 404: no such sourceSystem + sourcePKey."""


class SourceNotAllowedError(ValueError):
    """sourceSystem is not in [sources] allowed of b360_entities.toml. Nothing was sent."""


class DuplicateSourcePKeyError(ValueError):
    """Two records in one request carry the same sourcePKey. Nothing was sent."""


# A record answer with one of these stops the whole send: the next calls would fail the same way.
_STOP_STATUS = {401: "IDMC 401 (session not accepted)", 403: "IDMC 403 (not permitted)"}


_PICKS = (FieldDataType.PICKLIST, FieldDataType.DEPENDENT_PICKLIST)


def _keyed_fields(entity: BusinessEntity) -> list[tuple[str, EntityField]]:
    """Root fields under group "", group fields under their group name."""
    return [("", f) for f in entity.fields] + [
        (g.name, f) for g in entity.field_groups for f in g.fields
    ]


def _all_fields(entity: BusinessEntity) -> list[EntityField]:
    return [f for _, f in _keyed_fields(entity)]


class B360DataService:
    def __init__(self, http: IdmcHttp, mdm_url: str) -> None:
        self._http = http
        self._mdm_url = mdm_url.rstrip("/")
        self._meta_cache: dict[str, tuple[float, BusinessEntity]] = {}
        self._prefix: dict[str, str] = {}
        self._rdm_cache: tuple[float, list[BusinessEntitySummary]] | None = None
        self._rdm_values: dict[str, tuple[float, list[PicklistOption]]] = {}

    def entities(self, scope: EntityScope = EntityScope.FOCUS) -> BusinessEntityList:
        body: object = self._http.request("GET", self._mdm_url + ep.DATAMODEL, ep.MDM_HEADERS)
        every = wire.entities_from_datamodel(body)
        config = entity_scope.focus_config()
        by_id = {e.name.lower(): e for e in every}
        status: list[FocusEntityStatus] = []
        focused: list[BusinessEntitySummary] = []
        for wanted in config.entity:
            hit = by_id.get(wanted.name.lower())
            label = wanted.label or (hit.label if hit else wanted.name)
            status.append(FocusEntityStatus(name=wanted.name, label=label, found=hit is not None))
            if hit is not None:
                focused.append(hit.model_copy(update={"label": label}))
        shown = every if scope is EntityScope.ALL else focused
        return BusinessEntityList(
            scope=scope,
            entities=shown,
            total=len(every),
            focus=status,
            focus_file=str(entity_scope.config_path()),
            source="GET " + ep.DATAMODEL,
        )

    def metadata(self, guid: str) -> BusinessEntity:
        cached = self._meta_cache.get(guid)
        if cached is not None and time.monotonic() - cached[0] < ep.METADATA_CACHE_SECONDS:
            return cached[1]
        body: object = self._http.request(
            "GET", self._mdm_url + ep.BUSINESS_ENTITY.format(guid=guid), ep.MDM_HEADERS
        )
        entity = wire.business_entity_from_metadata(body, guid)
        self._meta_cache[guid] = (time.monotonic(), entity)
        return entity

    def metadata_with_lookups(self, guid: str) -> BusinessEntity:
        """0.9.12: metadata plus each picklist field's Reference 360 list resolved against the
        datamodel's rdm.* entities (one extra cached DATAMODEL read, only if a picklist exists)."""
        entity = self.metadata(guid)
        if any(f.lookup is not None for f in _all_fields(entity)):
            entity = wire.with_lookups(entity, self._rdm_entities())
        return entity

    def _rdm_entities(self) -> list[BusinessEntitySummary]:
        """rdm.* entities from the datamodel (cached 5 min). Error -> [] (lookups stay
        unresolved, never invented); 429 passed through."""
        if self._rdm_cache and time.monotonic() - self._rdm_cache[0] < ep.RDM_CACHE_SECONDS:
            return self._rdm_cache[1]
        try:
            body: object = self._http.request("GET", self._mdm_url + ep.DATAMODEL, ep.MDM_HEADERS)
        except IdmcRateLimitedError:
            raise
        except IdmcError:
            return []
        rdm = [e for e in wire.entities_from_datamodel(body) if e.name.startswith("rdm.")]
        self._rdm_cache = (time.monotonic(), rdm)
        return rdm

    def _rdm_allowed(self, rdm_entity: str) -> list[PicklistOption]:
        """Every {Code, Name} of a Reference 360 value entity: one Search API call, pageSize
        200, cached 5 min. Error or no records -> [] (caller falls back); 429 passed through."""
        cached = self._rdm_values.get(rdm_entity)
        if cached is not None and time.monotonic() - cached[0] < ep.RDM_CACHE_SECONDS:
            return cached[1]
        body = {
            "entityType": rdm_entity,
            "search": "*",
            "pageSize": ep.RDM_PAGE_SIZE,
            "recordOffset": 0,
            "recordsToReturn": ep.RDM_PAGE_SIZE,
        }
        try:
            reply: object = self._http.request(
                "POST", self._mdm_url + ep.SEARCH, ep.MDM_HEADERS, json=body
            )
        except IdmcRateLimitedError:
            raise
        except IdmcError:
            return []
        found = wire.rdm_options(wire.search_response(reply).records)
        self._rdm_values[rdm_entity] = (time.monotonic(), found)
        return found

    def records(
        self,
        guid: str,
        limit: int = ep.PAGE_SIZE,
        *,
        page: int = 1,
        first_name: str = "",
        last_name: str = "",
        business_id: str = "",
        sort: SortOrder = SortOrder.NEWEST_FIRST,
    ) -> RecordPage:
        entity = self.metadata(guid)
        if business_id.strip():
            return self._by_business_id(entity, business_id.strip(), limit, sort)
        filters = self._name_filters(entity, first_name, last_name)
        body: dict[str, object] = {
            "entityType": guid,
            "search": "*",
            "pageSize": limit,
            "pageOffset": 0,
            "recordOffset": (page - 1) * limit,
            "recordsToReturn": limit,
            "sort": [
                {
                    "fieldName": ep.LAST_UPDATE_FIELD,
                    "order": "DESCENDING" if sort is SortOrder.NEWEST_FIRST else "ASCENDING",
                }
            ],
        }
        if filters:
            body["filters"] = {
                "filter": [
                    {
                        "fieldName": f.field_name,
                        "comparator": f.comparator.value,
                        "fieldValue": f.value,
                    }
                    for f in filters
                ]
            }
        reply: object = self._http.request(
            "POST", self._mdm_url + ep.SEARCH, ep.MDM_HEADERS, json=body
        )
        result = wire.search_response(reply)
        raw = result.records[:limit]
        seen_prefix = wire.key_prefix(raw)
        if seen_prefix:
            self._prefix[guid] = seen_prefix
        hits = result.hits
        records = [wire.record_from_search(r, entity) for r in raw]
        return RecordPage(
            entity=entity,
            hits=hits,
            records=records,
            unknown_keys=wire.unknown_keys(raw, entity),
            system_columns=wire.system_columns([r.system_values for r in records]),
            visibility=entity_scope.field_visibility(entity),
            page=page,
            page_size=limit,
            total_pages=max(1, math.ceil((hits or 0) / limit)),
            sort=sort,
            filters=filters,
            mode=LookupMode.SEARCH,
        )

    def _field_prefix(self, guid: str) -> str:
        """Prefix the last search reply used for this entity, else the documented rule (p. 27)."""
        return self._prefix.get(guid) or guid.replace(".", "")

    def _name_filters(self, entity: BusinessEntity, first: str, last: str) -> list[AppliedFilter]:
        out: list[AppliedFilter] = []
        wanted_fields = (("First name", "firstname", first), ("Last name", "lastname", last))
        for label, wanted, value in wanted_fields:
            if not value.strip():
                continue
            field = next(
                (f for f in entity.fields if f.name.lower().replace("_", "") == wanted), None
            )
            if field is None:
                raise B360InputError(f"{entity.name} has no {label.lower()} field to filter on.")
            out.append(
                AppliedFilter(
                    label=label,
                    field_name=f"{self._field_prefix(entity.name)}.{field.name}",
                    comparator=NameFilterComparator.STARTS_WITH,
                    value=value.strip(),
                )
            )
        return out

    def _by_business_id(
        self, entity: BusinessEntity, business_id: str, limit: int, sort: SortOrder
    ) -> RecordPage:
        url = self._mdm_url + ep.READ_RECORD.format(
            guid=quote(entity.name, safe="."), business_id=quote(business_id, safe="")
        )
        note = "Read Master Record by Business ID (exact match)."
        try:
            reply: object = self._http.request("GET", url, ep.MDM_HEADERS)
            data = wire.as_json(reply)
            raw = [data] if isinstance(data, dict) and data else []
        except IdmcRateLimitedError:
            raise
        except IdmcError as exc:
            if exc.status_code not in (400, 404):
                raise
            raw, note = [], f"No active master record with business ID {business_id} ({exc})."
        records = [wire.record_from_search(r, entity) for r in raw]
        return RecordPage(
            entity=entity,
            hits=len(raw),
            records=records,
            system_columns=wire.system_columns([r.system_values for r in records]),
            visibility=entity_scope.field_visibility(entity),
            unknown_keys=wire.unknown_keys(raw, entity),
            page=1,
            page_size=limit,
            total_pages=1,
            sort=sort,
            mode=LookupMode.BUSINESS_ID,
            business_id=business_id,
            note=note,
        )

    # ------------------------------------------------------------------ 0.9.8 Add records

    def source_systems(self) -> SourceSystemList:
        """Allowed list from the TOML + a read-only discovery attempt. 429 is passed through."""
        sources = entity_scope.focus_config().sources
        discovered: list[str] = []
        try:
            body: object = self._http.request(
                "GET", self._mdm_url + ep.SOURCE_SYSTEMS, ep.MDM_HEADERS
            )
            discovered = wire.source_system_ids(body)
            status = DiscoveryStatus.OK
            note = f"IDMC listed {len(discovered)} source system(s)."
        except IdmcRateLimitedError:
            raise
        except IdmcError as exc:
            status = DiscoveryStatus.NOT_AVAILABLE
            note = f"Not available on this org ({exc}). Using the allowed list in the TOML only."
        return SourceSystemList(
            allowed=list(sources.allowed),
            default=sources.default_source(),
            discovered=discovered,
            not_allowed=[d for d in discovered if not sources.is_allowed(d)],
            discovery=status,
            discovery_note=note,
            source="GET " + ep.SOURCE_SYSTEMS + " (undocumented, UNVERIFIED)",
        )

    def picklist_options(self, entity: BusinessEntity) -> forms.PicklistOptions:
        """Real picklist values: distinct {Code, Name} in up to 50 of the entity's own records
        (one Search API call). Only when the entity has a picklist field. 429 passed through;
        any other error -> no options (fields left empty, never invented)."""
        picks = (FieldDataType.PICKLIST, FieldDataType.DEPENDENT_PICKLIST)
        fields = [*entity.fields, *(f for g in entity.field_groups for f in g.fields)]
        if not any(f.data_type in picks for f in fields):
            return {}
        body = {
            "entityType": entity.name,
            "search": "*",
            "pageSize": ep.PICKLIST_SAMPLE,
            "recordOffset": 0,
            "recordsToReturn": ep.PICKLIST_SAMPLE,
        }
        try:
            reply: object = self._http.request(
                "POST", self._mdm_url + ep.SEARCH, ep.MDM_HEADERS, json=body
            )
        except IdmcRateLimitedError:
            raise
        except IdmcError:
            return {}
        return wire.picklist_options(wire.search_response(reply).records, entity)

    def picklists(self, entity: BusinessEntity) -> forms.Picklists:
        """0.9.12: allowed values per picklist field. Reference 360 first (the rdm.value.be.*
        entity the metadata points to), else the values observed in records (0.9.10), else none.
        """
        options: forms.PicklistOptions = {}
        sources: forms.PicklistSources = {}
        observed: forms.PicklistOptions | None = None
        for group, f in _keyed_fields(entity):
            if f.data_type not in _PICKS:
                continue
            key = (group, f.name)
            lookup = f.lookup
            if lookup is not None and lookup.rdm_entity:
                allowed = self._rdm_allowed(lookup.rdm_entity)
                if allowed:
                    options[key] = allowed
                    sources[key] = (
                        PicklistSource.REFERENCE_360_GUESSED
                        if lookup.status is LookupStatus.GUESSED
                        else PicklistSource.REFERENCE_360
                    )
                    continue
            if observed is None:
                observed = self.picklist_options(entity)
            seen = observed.get(key, [])
            options[key] = seen
            sources[key] = PicklistSource.OBSERVED_IN_RECORDS if seen else PicklistSource.NONE
        return forms.Picklists(options=options, sources=sources)

    def typed_entities(self) -> tuple[list[tuple[BusinessEntity, forms.Picklists]], list[str]]:
        """0.9.12 /openapi-typed.json: each focus entity's metadata + picklist values (read-only,
        cached). A failure is a warning, never an error: the spec still renders."""
        found: list[tuple[BusinessEntity, forms.Picklists]] = []
        warnings: list[str] = []
        for wanted in entity_scope.focus_config().entity:
            try:
                entity = self.metadata_with_lookups(wanted.name)
                found.append((entity, self.picklists(entity)))
            except Exception as exc:  # noqa: BLE001 - a docs page must not 500 (his ask)
                warnings.append(f"{wanted.name}: metadata not read ({type(exc).__name__}: {exc})")
        return found, warnings

    def form_schema(self, guid: str) -> FormSchema:
        entity = self.metadata_with_lookups(guid)
        return forms.form_schema(entity, self.picklists(entity))

    def generate(self, guid: str, request: GenerateRequest) -> GeneratedRows:
        entity = self.metadata_with_lookups(guid)
        return testdata.generate(
            entity, request.count, request.seed, datetime.now(), self.picklists(entity)
        )

    # ------------------------------------------------------------------ 0.9.10 source records

    def source_metadata(self, guid: str) -> BusinessEntity:
        return wire.source_view(self.metadata(guid))

    def _xref_url(self, guid: str, source_system: str, source_pkey: str) -> str:
        return self._mdm_url + ep.ENTITY_XREF.format(
            guid=quote(guid, safe="."),
            source_system=quote(source_system, safe="."),
            source_pkey=quote(source_pkey, safe=""),
        )

    def source_record(self, guid: str, source_system: str, source_pkey: str) -> SourceRecord:
        """Read Source Record (pp. 80-84). 404 -> SourceRecordNotFoundError. Never retried."""
        entity = self.metadata(guid)
        try:
            reply: object = self._http.request(
                "GET", self._xref_url(guid, source_system, source_pkey), ep.MDM_HEADERS
            )
        except IdmcRateLimitedError:
            raise
        except IdmcError as exc:
            if exc.status_code == 404:
                raise SourceRecordNotFoundError(
                    f"no source record {source_system} / {source_pkey} in {guid} ({exc})"
                ) from exc
            raise
        return wire.source_record(reply, entity, source_system, source_pkey)

    def source_records(self, guid: str, business_id: str) -> SourceRecordList:
        """Read Source Records by Master Record (p. 70), then Read Source Record for each member
        (p. 80), one at a time, at most 20. 429 stops everything (passed through)."""
        entity = self.metadata(guid)
        url = self._mdm_url + ep.ENTITY_MEMBER.format(
            guid=quote(guid, safe="."), business_id=quote(business_id, safe="")
        )
        try:
            reply: object = self._http.request("GET", url, ep.MDM_HEADERS)
        except IdmcRateLimitedError:
            raise
        except IdmcError as exc:
            if exc.status_code not in (400, 404):
                raise
            return SourceRecordList(
                entity=entity,
                business_id=business_id,
                members=[],
                records=[],
                note=f"No master record {business_id} ({exc}).",
            )
        members = wire.source_members(reply)
        records: list[SourceRecord] = []
        not_read: list[SourceKey] = []
        for n, member in enumerate(members):
            if n >= ep.MAX_SOURCES_READ:
                not_read.append(member)
                continue
            try:
                body: object = self._http.request(
                    "GET",
                    self._xref_url(guid, member.source_system, member.source_pkey),
                    ep.MDM_HEADERS,
                )
            except IdmcRateLimitedError:
                raise
            except IdmcError:
                not_read.append(member)
                continue
            records.append(
                wire.source_record(body, entity, member.source_system, member.source_pkey)
            )
        note = f"{len(members)} source record(s) contribute to {business_id}."
        if not_read:
            note += f" {len(not_read)} not read (over {ep.MAX_SOURCES_READ} or the read failed)."
        return SourceRecordList(
            entity=entity,
            business_id=business_id,
            members=members,
            records=records,
            not_read=not_read,
            note=note,
            system_columns=wire.system_columns([r.system_values for r in records]),
            visibility=entity_scope.field_visibility(entity),
        )

    def update_source(
        self, guid: str, source_system: str, source_pkey: str, request: UpdateSourceRequest
    ) -> UpdateSourceResponse:
        """Update Source Record Field (PATCH, pp. 88-90) with only what changed. One call.

        dry_run (default) builds the operations and sends nothing (the Edit page shows
        them, old -> new). Allowed source only (else 400); edited values must fit the dynamic
        models (else 422). 429 passed through, never retried."""
        sources = entity_scope.focus_config().sources
        if not sources.is_allowed(source_system):
            raise SourceNotAllowedError(
                f"source system {source_system!r} is not in [sources] allowed of "
                f"{entity_scope.config_path().name} (allowed: {', '.join(sources.allowed)}). "
                "Nothing was sent."
            )
        entity = self.metadata(guid)
        new_values = forms.validate_values(entity, request.updated.values, 0)
        new_groups = forms.validate_groups(entity, request.updated.groups, 0)
        ops = forms.patch_ops(entity, request.original, new_values, new_groups)
        base = UpdateSourceResponse(
            entity=guid,
            source_system=source_system,
            source_pkey=source_pkey,
            ops=ops,
            sent=False,
            note="",
        )
        if request.dry_run:
            return base.model_copy(
                update={"note": f"Dry run: {len(ops)} change(s) would be sent. Nothing was sent."}
            )
        if not ops:
            return base.model_copy(update={"note": "Nothing changed. Nothing was sent."})
        body = [
            o.model_dump(
                include={"op", "path"}
                if o.op is PatchOperation.REMOVE
                else {"op", "path", "value"},
                mode="json",
            )
            for o in ops
        ]
        reply: object = self._http.request(
            "PATCH", self._xref_url(guid, source_system, source_pkey), ep.MDM_HEADERS, json=body
        )
        data = wire.as_json(reply)
        approval = data.get("approvalRequired") if isinstance(data, dict) else None
        return base.model_copy(
            update={
                "sent": True,
                "approval_required": approval if isinstance(approval, bool) else None,
                "note": f"Sent {len(ops)} change(s) with Update Source Record Field (PATCH).",
            }
        )

    def create(self, guid: str, request: CreateRequest) -> CreateResponse:
        """Create Master Record, one call per record, in order, never in parallel, never retried.

        Everything is validated first (allowed source, dynamic model, unique sourcePKey); a bad
        request sends nothing. Then: 429 / 401 / 403 / no answer stop the run (the rest NOT_SENT);
        any other IDMC error marks that record FAILED and the next one still goes.
        """
        sources = entity_scope.focus_config().sources
        if not sources.is_allowed(request.source_system):
            raise SourceNotAllowedError(
                f"source system {request.source_system!r} is not in [sources] allowed of "
                f"{entity_scope.config_path().name} (allowed: {', '.join(sources.allowed)}). "
                "Nothing was sent."
            )
        entity = self.metadata(guid)
        stamp = datetime.now()
        prepared: list[tuple[str, dict[str, object]]] = []
        for index, record in enumerate(request.records):
            values = forms.validate_values(entity, record.values, index)
            groups = forms.validate_groups(entity, record.groups, index)
            pkey = record.source_pkey or testdata.make_source_pkey(stamp, index + 1)
            prepared.append((pkey, forms.wire_body(entity, values, groups)))
        pkeys = [p for p, _ in prepared]
        if len(set(pkeys)) != len(pkeys):
            raise DuplicateSourcePKeyError("two records share a sourcePKey. Nothing was sent.")

        url = self._mdm_url + ep.CREATE_RECORD.format(guid=guid)
        results: list[CreateResult] = []
        stopped: str | None = None
        for index, (pkey, body) in enumerate(prepared):
            if stopped is not None:
                results.append(
                    CreateResult(index=index, source_pkey=pkey, outcome=CreateOutcome.NOT_SENT)
                )
                continue
            params = {"sourceSystem": request.source_system, "sourcePKey": pkey}
            try:
                reply: object = self._http.request(
                    "POST", url, ep.MDM_HEADERS, json=body, params=params
                )
            except IdmcRateLimitedError:
                stopped = "IDMC 429 (rate limited); stopped, nothing retried"
                results.append(
                    CreateResult(index=index, source_pkey=pkey, outcome=CreateOutcome.NOT_SENT)
                )
                continue
            except IdmcError as exc:
                results.append(
                    CreateResult(
                        index=index, source_pkey=pkey, outcome=CreateOutcome.FAILED, error=str(exc)
                    )
                )
                if exc.status_code in _STOP_STATUS:
                    stopped = _STOP_STATUS[exc.status_code] + "; stopped"
                continue
            except httpx.HTTPError as exc:
                stopped = "no answer from IDMC; stopped (check B360 before sending again)"
                results.append(
                    CreateResult(
                        index=index,
                        source_pkey=pkey,
                        outcome=CreateOutcome.UNKNOWN,
                        error=f"{type(exc).__name__}: {exc}"[:500],
                    )
                )
                continue
            created = wire.created_record(reply)
            business_id = created.business_id if created.business_id is not None else created.id
            results.append(
                CreateResult(
                    index=index,
                    source_pkey=pkey,
                    outcome=CreateOutcome.CREATED,
                    business_id=None if business_id is None else str(business_id),
                    approval_required=created.approval_required,
                )
            )

        def count(outcome: CreateOutcome) -> int:
            return sum(1 for r in results if r.outcome is outcome)

        return CreateResponse(
            entity=guid,
            source_system=request.source_system,
            created=count(CreateOutcome.CREATED),
            failed=count(CreateOutcome.FAILED),
            not_sent=count(CreateOutcome.NOT_SENT),
            unknown=count(CreateOutcome.UNKNOWN),
            stopped_reason=stopped,
            results=results,
        )

    # ------------------------------------------------------------------ 0.9.12 Merge (M)

    def _require_focus(self, guid: str) -> BusinessEntity:
        names = {e.name.lower() for e in entity_scope.focus_config().entity}
        if guid.lower() not in names:
            raise B360InputError(
                f"{guid} is not in the focus list of {entity_scope.config_path().name}; "
                "merge is only offered for focus entities. Nothing was sent."
            )
        return self.metadata(guid)

    @staticmethod
    def _clean_ids(ids: list[str]) -> list[str]:
        clean = [i.strip() for i in ids if i.strip()]
        if len(clean) != len(set(clean)):
            raise B360InputError("the same business id is listed twice. Nothing was sent.")
        if not 2 <= len(clean) <= ep.MAX_MERGE:
            raise B360InputError(
                f"merge needs 2-{ep.MAX_MERGE} business ids (got {len(clean)}). Nothing was sent."
            )
        return clean

    def _read_master(self, entity: BusinessEntity, business_id: str) -> EntityRecord | None:
        """Read Master Record by Business ID (pp. 56-58). 400/404 -> None; 429 passed through."""
        url = self._mdm_url + ep.READ_RECORD.format(
            guid=quote(entity.name, safe="."), business_id=quote(business_id, safe="")
        )
        try:
            reply: object = self._http.request("GET", url, ep.MDM_HEADERS)
        except IdmcRateLimitedError:
            raise
        except IdmcError as exc:
            if exc.status_code in (400, 404):
                return None
            raise
        data = wire.as_json(reply)
        if not isinstance(data, dict) or not data:
            return None
        return wire.record_from_search(data, entity)

    @staticmethod
    def _follower(entity: BusinessEntity, field: str) -> str | None:
        """clns_<field> when the entity has it (the cleansed twin follows its field's winner)."""
        twin = f"clns_{field}"
        return twin if any(f.name == twin for f in entity.fields) else None

    def merge_preview(self, guid: str, request: MergePreviewRequest) -> MergePreview:
        """Read each record (Read Master Record, one at a time). Read-only."""
        entity = self._require_focus(guid)
        ids = self._clean_ids(request.business_ids)
        records: list[EntityRecord] = []
        missing: list[str] = []
        for bid in ids:
            record = self._read_master(entity, bid)
            if record is None:
                missing.append(bid)
            else:
                records.append(record)
        followers = {
            twin: f.name for f in entity.fields if (twin := self._follower(entity, f.name))
        }
        rows: list[MergeFieldRow] = []
        for f in entity.fields:
            values = {r.business_id: r.values.get(f.name) for r in records}
            rows.append(
                MergeFieldRow(
                    field=f.name,
                    label=f.label,
                    values=values,
                    differs=len({str(v) for v in values.values()}) > 1,
                    follows=followers.get(f.name),
                )
            )
        note = f"Read {len(records)} of {len(ids)} record(s). Nothing was sent."
        if missing:
            note += f" No active master record for: {', '.join(missing)} (merge refused)."
        return MergePreview(
            entity=guid, business_ids=ids, records=records, rows=rows, missing=missing, note=note
        )

    def merge(self, guid: str, request: MergeRequest) -> MergeResponse:
        """READ each id -> MERGE (p. 106) -> OVERRIDE the picked fields on the survivor
        (Update Master Record Field, pp. 67-68) -> READ_BACK. Never retried, never parallel.

        Refused before any call (400): entity not in focus, not 2-10 distinct ids, a winner id
        not in the list, a winner field not a root field, a picklist winner, a not-allowed
        override source. A missing record stops before MERGE. After MERGE a 429 or error stops
        the remaining steps and is reported in steps (the merge itself is not undone)."""
        entity = self._require_focus(guid)
        ids = self._clean_ids(request.business_ids)
        by_field = {f.name: f for f in entity.fields}
        for field, winner in request.winners.items():
            if field not in by_field:
                raise B360InputError(f"{field} is not a root field of {guid}. Nothing was sent.")
            if by_field[field].data_type in (
                FieldDataType.PICKLIST,
                FieldDataType.DEPENDENT_PICKLIST,
            ):
                raise B360InputError(
                    f"{field} is a picklist; picklist winners are not supported yet "
                    "(override body shape UNVERIFIED). Nothing was sent."
                )
            if winner not in ids:
                raise B360InputError(
                    f"winner {winner} for {field} is not one of the merged ids. Nothing was sent."
                )
        sources = entity_scope.focus_config().sources
        override_source = request.override_source_system or sources.default_source()
        if request.winners and (override_source is None or not sources.is_allowed(override_source)):
            raise SourceNotAllowedError(
                f"source system {override_source!r} is not in [sources] allowed of "
                f"{entity_scope.config_path().name} (allowed: {', '.join(sources.allowed)}). "
                "Nothing was sent."
            )

        steps: list[MergeStep] = []

        def done(note: str, **extra: object) -> MergeResponse:
            fields: dict[str, object] = {
                "entity": guid,
                "business_ids": ids,
                "surviving_business_id": None,
                "override_source_system": override_source if request.winners else None,
                "overrides": [],
                "steps": steps,
                "before": [],
                "note": note,
            }
            fields.update(extra)
            return MergeResponse.model_validate(fields)

        # 1. READ (429 here is passed through: nothing has changed yet)
        before: list[EntityRecord] = []
        missing: list[str] = []
        for bid in ids:
            record = self._read_master(entity, bid)
            if record is None:
                missing.append(bid)
            else:
                before.append(record)
        if missing:
            steps.append(
                MergeStep(
                    step=MergeStepName.READ,
                    status=MergeStepStatus.FAILED,
                    detail=f"no active master record for {', '.join(missing)}",
                )
            )
            return done("Nothing was merged.", before=before)
        steps.append(
            MergeStep(
                step=MergeStepName.READ,
                status=MergeStepStatus.OK,
                detail=f"read {len(before)} master record(s)",
            )
        )
        values = {r.business_id: r.values for r in before}

        # 2. MERGE
        url = self._mdm_url + ep.ENTITY_GROUP.format(guid=quote(guid, safe="."))
        try:
            reply: object = self._http.request(
                "POST", url, ep.MDM_HEADERS, json=[{"businessId": bid} for bid in ids]
            )
        except IdmcRateLimitedError:
            raise
        except IdmcError as exc:
            steps.append(
                MergeStep(step=MergeStepName.MERGE, status=MergeStepStatus.FAILED, detail=str(exc))
            )
            return done("IDMC refused the merge. Nothing else was sent.", before=before)
        except httpx.HTTPError as exc:
            steps.append(
                MergeStep(
                    step=MergeStepName.MERGE,
                    status=MergeStepStatus.FAILED,
                    detail=f"no answer from IDMC ({type(exc).__name__}); the merge MAY have "
                    "happened - check Records (M) before trying again",
                )
            )
            return done("Merge outcome unknown. Nothing else was sent.", before=before)
        data = wire.as_json(reply)
        raw_bid = data.get("businessId") if isinstance(data, dict) else None
        raw_approval = data.get("approvalRequired") if isinstance(data, dict) else None
        survivor = str(raw_bid) if raw_bid is not None else None
        approval = raw_approval if isinstance(raw_approval, bool) else None
        steps.append(
            MergeStep(
                step=MergeStepName.MERGE,
                status=MergeStepStatus.OK,
                detail=f"surviving master {survivor}, approvalRequired {approval}",
            )
        )

        # 3. OVERRIDE
        overrides: list[MergeOverride] = []
        for field, winner in request.winners.items():
            overrides.append(
                MergeOverride(
                    field=field, winner_business_id=winner, value=values[winner].get(field)
                )
            )
            twin = self._follower(entity, field)
            if twin is not None and twin not in request.winners:
                overrides.append(
                    MergeOverride(
                        field=twin,
                        winner_business_id=winner,
                        value=values[winner].get(twin),
                        carried_with=field,
                    )
                )
        stop_after_merge = ""
        if not overrides:
            steps.append(
                MergeStep(
                    step=MergeStepName.OVERRIDE,
                    status=MergeStepStatus.SKIPPED,
                    detail="no field winners picked; IDMC survivorship decides every field",
                )
            )
        elif approval is True or survivor is None:
            steps.append(
                MergeStep(
                    step=MergeStepName.OVERRIDE,
                    status=MergeStepStatus.SKIPPED,
                    detail="merge waits for steward approval; winners not applied"
                    if approval
                    else "IDMC returned no surviving business id; winners not applied",
                )
            )
        else:
            ops = [
                {"op": "remove", "path": o.field}
                if o.value is None
                else {
                    "op": "replace",
                    "path": o.field,
                    "value": forms.wire_value(o.value, by_field[o.field].data_type),
                }
                for o in overrides
            ]
            patch_url = self._mdm_url + ep.READ_RECORD.format(
                guid=quote(guid, safe="."), business_id=quote(survivor, safe="")
            )
            try:
                self._http.request(
                    "PATCH",
                    patch_url,
                    ep.MDM_HEADERS,
                    json=ops,
                    params={"sourceSystem": str(override_source)},
                )
                steps.append(
                    MergeStep(
                        step=MergeStepName.OVERRIDE,
                        status=MergeStepStatus.OK,
                        detail=f"{len(ops)} field(s) set with Update Master Record Field "
                        f"(sourceSystem {override_source})",
                    )
                )
            except IdmcRateLimitedError:
                stop_after_merge = "IDMC 429 (rate limited); stopped, nothing retried"
                steps.append(
                    MergeStep(
                        step=MergeStepName.OVERRIDE,
                        status=MergeStepStatus.FAILED,
                        detail=stop_after_merge,
                    )
                )
            except (IdmcError, httpx.HTTPError) as exc:
                steps.append(
                    MergeStep(
                        step=MergeStepName.OVERRIDE, status=MergeStepStatus.FAILED, detail=str(exc)
                    )
                )

        # 4. READ_BACK
        after: EntityRecord | None = None
        if survivor is not None and not stop_after_merge:
            try:
                after = self._read_master(entity, survivor)
                steps.append(
                    MergeStep(
                        step=MergeStepName.READ_BACK,
                        status=MergeStepStatus.OK if after else MergeStepStatus.FAILED,
                        detail="read the surviving master"
                        if after
                        else f"no active master {survivor} on read-back",
                    )
                )
            except IdmcRateLimitedError:
                steps.append(
                    MergeStep(
                        step=MergeStepName.READ_BACK,
                        status=MergeStepStatus.FAILED,
                        detail="IDMC 429 (rate limited); not retried",
                    )
                )
        else:
            steps.append(
                MergeStep(
                    step=MergeStepName.READ_BACK,
                    status=MergeStepStatus.SKIPPED,
                    detail=stop_after_merge or "no surviving business id",
                )
            )
        if after is not None:
            overrides = [
                o.model_copy(
                    update={
                        "final_value": after.values.get(o.field),
                        "stuck": str(after.values.get(o.field)) == str(o.value),
                    }
                )
                for o in overrides
            ]
        return done(
            f"Merged {len(ids)} record(s) into {survivor}.",
            surviving_business_id=survivor,
            approval_required=approval,
            overrides=overrides,
            before=before,
            after=after,
        )

    def unmerge(self, guid: str, business_id: str, request: UnmergeRequest) -> UnmergeResponse:
        """Unmerge API (pp. 107-110), _keepRelsWith=BUSINESS_ID (what the B360 UI does, p. 108),
        other parameters at their documented defaults. One call, never retried."""
        self._require_focus(guid)
        url = self._mdm_url + ep.ENTITY_GROUP_MASTER.format(
            guid=quote(guid, safe="."), business_id=quote(business_id, safe="")
        )
        params = {"_keepRelsWith": "BUSINESS_ID"}
        if request.allow_merge_back:
            params["_allowMergeBack"] = "MAY_MERGE"
        body = [
            {"sourcePKey": s.source_pkey, "sourceSystem": s.source_system} for s in request.sources
        ]
        reply: object = self._http.request("POST", url, ep.MDM_HEADERS, json=body, params=params)
        data = wire.as_json(reply)
        approval = data.get("approvalRequired") if isinstance(data, dict) else None
        return UnmergeResponse(
            entity=guid,
            business_id=business_id,
            sources=request.sources,
            approval_required=approval if isinstance(approval, bool) else None,
            note=f"Took {len(request.sources)} source record(s) out of {business_id}.",
        )
