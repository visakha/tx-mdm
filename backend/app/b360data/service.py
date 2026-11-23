"""B360 Data: business entities -> metadata -> first N records. Read-only, never retried.

IDMC JSON is parsed into typed models in app.b360data.wire, right where it arrives.
"""

import time
from datetime import datetime

import httpx

from app.b360data import endpoints as ep
from app.b360data import forms, testdata, wire
from app.b360data import scope as entity_scope
from app.b360data.models import (
    BusinessEntity,
    BusinessEntityList,
    BusinessEntitySummary,
    CreateOutcome,
    CreateRequest,
    CreateResponse,
    CreateResult,
    DiscoveryStatus,
    EntityScope,
    FocusEntityStatus,
    FormSchema,
    GeneratedRows,
    GenerateRequest,
    RecordPage,
    SourceSystemList,
)
from app.common.idmc_session import IdmcError, IdmcHttp, IdmcRateLimitedError


class SourceNotAllowedError(ValueError):
    """sourceSystem is not in [sources] allowed of b360_entities.toml. Nothing was sent."""


class DuplicateSourcePKeyError(ValueError):
    """Two records in one request carry the same sourcePKey. Nothing was sent."""


# A record answer with one of these stops the whole send: the next calls would fail the same way.
_STOP_STATUS = {401: "IDMC 401 (session not accepted)", 403: "IDMC 403 (not permitted)"}


class B360DataService:
    def __init__(self, http: IdmcHttp, mdm_url: str) -> None:
        self._http = http
        self._mdm_url = mdm_url.rstrip("/")
        self._meta_cache: dict[str, tuple[float, BusinessEntity]] = {}

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

    def records(self, guid: str, limit: int) -> RecordPage:
        entity = self.metadata(guid)
        body: object = self._http.request(
            "POST",
            self._mdm_url + ep.SEARCH,
            ep.MDM_HEADERS,
            json={"entityType": guid, "search": "*", "pageSize": limit, "recordsToReturn": limit},
        )
        result = wire.search_response(body)
        raw = result.records[:limit]
        return RecordPage(
            entity=entity,
            hits=result.hits,
            records=[wire.record_from_search(r, entity) for r in raw],
            unknown_keys=wire.unknown_keys(raw, entity),
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

    def form_schema(self, guid: str) -> FormSchema:
        return forms.form_schema(self.metadata(guid))

    def generate(self, guid: str, request: GenerateRequest) -> GeneratedRows:
        return testdata.generate(self.metadata(guid), request.count, request.seed, datetime.now())

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
            pkey = record.source_pkey or testdata.make_source_pkey(stamp, index + 1)
            prepared.append((pkey, forms.wire_body(entity, values)))
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
