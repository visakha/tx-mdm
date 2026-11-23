"""HTTP routes for the B360 Data notebook. Mounted at /api/b360.

All read-only except POST /entities/{name}/records (Create Master Record), which runs only when
a person presses Save / Send to B360 in the Add records tab.
"""

from typing import Annotated

from fastapi import APIRouter, Body, Depends, HTTPException, Path, Query

from app.b360data import endpoints as ep
from app.b360data import history
from app.b360data.forms import RecordInvalidError
from app.b360data.models import (
    BusinessEntity,
    BusinessEntityList,
    CreateRequest,
    CreateResponse,
    EntityScope,
    FormSchema,
    GeneratedRows,
    GenerateRequest,
    MasterMergeHistory,
    MergePreview,
    MergePreviewRequest,
    MergeRequest,
    MergeResponse,
    RecordPage,
    SortOrder,
    SourceMergeHistory,
    SourceMetadata,
    SourceRecord,
    SourceRecordList,
    SourceRecordPage,
    SourceSystemList,
    UnmergeRequest,
    UnmergeResponse,
    UpdateSourceRequest,
    UpdateSourceResponse,
)
from app.b360data.service import (
    B360DataService,
    B360InputError,
    DuplicateSourcePKeyError,
    SourceNotAllowedError,
    SourceRecordNotFoundError,
)
from app.b360data.testdata import GenerateBlockedError
from app.common.naming import Identifier128
from app.dependencies import get_b360_data_service

router = APIRouter(prefix="/api/b360", tags=["b360"])

SourceSystem = Annotated[Identifier128, Path(min_length=1, max_length=128)]
SourcePKey = Annotated[str, Path(min_length=1, max_length=255)]
BusinessId = Annotated[str, Path(min_length=1, max_length=100)]
Service = Annotated[B360DataService, Depends(get_b360_data_service)]
EntityName = Annotated[Identifier128, Path(min_length=1, max_length=128)]


@router.get(
    "/entities",
    response_model=BusinessEntityList,
    operation_id="b360_list_entities",
    summary="Business entities configured in the org (derived from B360 metadata)",
    description="Read-only GET metadata/api/v2/objects/tenantModel/datamodel; every "
    "BusinessEntity object in it. scope=focus (default) keeps only the focus list "
    "(backend/b360_entities.toml, read at startup); scope=all returns every entity "
    "with its category. "
    "429 passed through, never retried.",
)
def list_entities(
    service: Service, scope: Annotated[EntityScope, Query()] = EntityScope.FOCUS
) -> BusinessEntityList:
    return service.entities(scope)


@router.get(
    "/entities/{name}/metadata",
    response_model=BusinessEntity,
    operation_id="b360_entity_metadata",
    summary="Fields and field groups of one business entity",
    description="Read-only GET metadata/api/v2/objects/businessEntity/{name}, cached 5 min.",
)
def entity_metadata(name: EntityName, service: Service) -> BusinessEntity:
    return service.metadata_with_lookups(name)


@router.get(
    "/entities/{name}/records",
    response_model=RecordPage,
    operation_id="b360_entity_records",
    summary="One page of master records: paged, filtered, sorted by Last updated",
    description="Read-only. POST search/public/api/v1/search with recordOffset/recordsToReturn "
    "(10 per page), optional STARTS_WITH filters on the entity's first/last name field, sort on "
    "_meta.lastUpdateDate (the only sort). business_id switches to Read Master Record by "
    "Business ID (GET business-entity/public/api/v1/entity/{name}/{businessId}), exact match.",
)
def entity_records(
    name: EntityName,
    service: Service,
    limit: Annotated[int, Query(ge=1, le=ep.MAX_LIMIT)] = ep.PAGE_SIZE,
    page: Annotated[int, Query(ge=1, le=ep.MAX_PAGE)] = 1,
    first_name: Annotated[str, Query(max_length=100)] = "",
    last_name: Annotated[str, Query(max_length=100)] = "",
    business_id: Annotated[str, Query(max_length=100)] = "",
    sort: SortOrder = SortOrder.NEWEST_FIRST,
) -> RecordPage:
    try:
        return service.records(
            name,
            limit,
            page=page,
            first_name=first_name,
            last_name=last_name,
            business_id=business_id,
            sort=sort,
        )
    except B360InputError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.get(
    "/source-systems",
    response_model=SourceSystemList,
    operation_id="b360_source_systems",
    summary="Source systems the Add records tab may send to",
    description="[sources] allowed of backend/b360_entities.toml, plus a read-only discovery "
    "attempt GET metadata/api/v2/objects/sourceSystem (undocumented, UNVERIFIED; "
    "NOT_AVAILABLE when it fails). 429 passed through, never retried.",
)
def source_systems(service: Service) -> SourceSystemList:
    return service.source_systems()


@router.get(
    "/entities/{name}/form-schema",
    response_model=FormSchema,
    operation_id="b360_form_schema",
    summary="Root-field form of one entity, from a Pydantic model built from its metadata",
    description="pydantic.create_model per entity: one field per root field, typed by its "
    "data type, required when mandatory. No IDMC write.",
)
def form_schema(name: EntityName, service: Service) -> FormSchema:
    return service.form_schema(name)


@router.post(
    "/entities/{name}/records/generate",
    response_model=GeneratedRows,
    operation_id="b360_generate_records",
    summary="Make 1-100 test rows with Faker (preview only, nothing sent to IDMC)",
)
def generate_records(
    name: EntityName,
    service: Service,
    request: Annotated[GenerateRequest, Body()],
) -> GeneratedRows:
    try:
        return service.generate(name, request)
    except GenerateBlockedError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    except RecordInvalidError as exc:
        raise HTTPException(
            status_code=422,
            detail=f"generated row {exc.index} does not fit the entity: {'; '.join(exc.problems)}",
        ) from exc


@router.post(
    "/entities/{name}/records",
    response_model=CreateResponse,
    operation_id="b360_create_records",
    summary="WRITE: create master records in B360 (Create Master Record), one at a time",
    description="POST business-entity/public/api/v1/entity/{name}?sourceSystem=&sourcePKey= per "
    "record, in order, never in parallel, never retried. At most 100. sourceSystem must be in "
    "[sources] allowed of b360_entities.toml (else 400, nothing sent). Every record is validated "
    "by the entity's dynamic Pydantic model first (else 422, nothing sent). 429 / 401 / 403 / "
    "no answer stop the run; the rest are NOT_SENT.",
)
def create_records(
    name: EntityName,
    service: Service,
    request: Annotated[CreateRequest, Body()],
) -> CreateResponse:
    try:
        return service.create(name, request)
    except SourceNotAllowedError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except DuplicateSourcePKeyError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    except RecordInvalidError as exc:
        raise HTTPException(
            status_code=422,
            detail=f"record {exc.index} does not fit the entity: {'; '.join(exc.problems)}. "
            "Nothing was sent.",
        ) from exc


# ---------------------------------------------------------------- 0.9.10 source (xref) records


@router.get(
    "/entities/{name}/source-metadata",
    response_model=BusinessEntity,
    operation_id="b360_source_metadata",
    summary="Metadata (S): the source-record view of the entity metadata",
    description="Same configured fields and field groups as the master (a source record carries "
    "the same model, pp. 82-87) plus the documented source (xref) _meta fields of Read Source "
    "Record (pp. 81-83) as SYSTEM / DOCUMENTED. Derived: there is no separate source metadata "
    "call in the reference. Read-only.",
)
def source_metadata(name: EntityName, service: Service) -> BusinessEntity:
    return service.source_metadata(name)


PickedSources = Annotated[
    list[str],
    Query(
        description="Source systems to show (repeat the parameter); each must be in "
        "b360_entities.toml [sources] allowed, else 400. Empty = [sources] default.",
        max_length=20,
    ),
]


@router.get(
    "/entities/{name}/source-records",
    response_model=SourceRecordPage,
    operation_id="b360_source_records_by_system",
    summary="Records (S): source records of the picked source systems, one master page at a time",
    description="IDMC documents no server-side source-system filter (Search API filters, pp. "
    "20-30) and no call listing all records of one source. So: Search API (one page of 10 "
    "masters) -> Read Source Records by Master Record (p. 70) per master -> keep members whose "
    "sourceSystem is picked -> Read Source Record (p. 80) each. Filter applied in the backend "
    "AFTER the IDMC read; paging is per master page. Read-only; 429 passed through, never retried.",
)
def source_records_by_system(
    name: EntityName,
    service: Service,
    source_systems: PickedSources = [],  # noqa: B006 - FastAPI query default
    page: Annotated[int, Query(ge=1, le=100_000)] = 1,
) -> SourceRecordPage:
    try:
        return service.source_records_page(name, source_systems, page)
    except SourceNotAllowedError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.get(
    "/entities/{name}/source-metadata/by-system",
    response_model=SourceMetadata,
    operation_id="b360_source_metadata_by_system",
    summary="Metadata (S) for the picked source systems",
    description="One model for every source system: no per-source metadata call is documented. "
    "Per-source differences (trust, survivorship, manualOverride) are per record (content meta, "
    "_showContentMeta=true), not per model. Read-only.",
)
def source_metadata_by_system(
    name: EntityName,
    service: Service,
    source_systems: PickedSources = [],  # noqa: B006 - FastAPI query default
) -> SourceMetadata:
    try:
        return service.source_metadata_for(name, source_systems)
    except SourceNotAllowedError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.get(
    "/entities/{name}/records/{business_id}/sources",
    response_model=SourceRecordList,
    operation_id="b360_master_sources",
    summary="Records (S): source records that contribute to one master record",
    description="Read Source Records by Master Record GET business-entity/public/api/v1/"
    "entity-member/{name}/{businessId} (p. 70), then Read Source Record GET .../entity-xref/"
    "{name}/{sourceSystem}/{sourcePKey} (p. 80) per member, one at a time, at most 20. "
    "Read-only. 429 passed through, never retried.",
)
def master_sources(name: EntityName, business_id: BusinessId, service: Service) -> SourceRecordList:
    return service.source_records(name, business_id)


@router.get(
    "/entities/{name}/sources/{source_system}/{source_pkey}",
    response_model=SourceRecord,
    operation_id="b360_source_record",
    summary="Read one source record by sourceSystem + sourcePKey",
    description="Read Source Record GET business-entity/public/api/v1/entity-xref/{name}/"
    "{sourceSystem}/{sourcePKey} (pp. 80-84). 404 -> 404. Read-only.",
)
def source_record(
    name: EntityName, source_system: SourceSystem, source_pkey: SourcePKey, service: Service
) -> SourceRecord:
    try:
        return service.source_record(name, source_system, source_pkey)
    except SourceRecordNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


@router.post(
    "/entities/{name}/sources/{source_system}/{source_pkey}/update",
    response_model=UpdateSourceResponse,
    operation_id="b360_update_source_record",
    summary="WRITE (dry_run=false only): update a source record with only what changed",
    description="Diffs original vs updated into Update Source Record Field operations (PATCH "
    "business-entity/public/api/v1/entity-xref/{name}/{sourceSystem}/{sourcePKey}, pp. 88-90). "
    "dry_run=true (default) sends nothing and returns the operations (old -> new), shown "
    "inline on the Edit page. dry_run=false sends ONE PATCH. "
    "sourceSystem must be in [sources] allowed (else 400); edited values must fit the dynamic "
    "models (else 422). 429 passed through, "
    "never retried. No master-record edit exists in this app.",
)
def update_source_record(
    name: EntityName,
    source_system: SourceSystem,
    source_pkey: SourcePKey,
    service: Service,
    request: Annotated[UpdateSourceRequest, Body()],
) -> UpdateSourceResponse:
    try:
        return service.update_source(name, source_system, source_pkey, request)
    except SourceNotAllowedError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except RecordInvalidError as exc:
        raise HTTPException(
            status_code=422,
            detail=f"edit does not fit the entity: {'; '.join(exc.problems)}. Nothing was sent.",
        ) from exc


# ---------------------------------------------------------------- 0.9.12 Merge (M)


@router.post(
    "/entities/{name}/merge/preview",
    response_model=MergePreview,
    operation_id="b360_merge_preview",
    summary="Merge (M) preview: read 2-10 master records side by side (read-only)",
    description="Read Master Record by Business ID (GET business-entity/public/api/v1/entity/"
    "{name}/{businessId}, pp. 56-58) per id, one at a time. Nothing is sent. Focus entities only.",
)
def merge_preview(
    name: EntityName, service: Service, request: Annotated[MergePreviewRequest, Body()]
) -> MergePreview:
    try:
        return service.merge_preview(name, request)
    except B360InputError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.post(
    "/entities/{name}/merge",
    response_model=MergeResponse,
    operation_id="b360_merge",
    summary="WRITE: merge 2-10 master records, then set the picked field winners on the survivor",
    description="1 READ each id (pp. 56-58). 2 MERGE: POST business-entity/public/api/v1/"
    "entity-group/{name} with [{businessId}] (Merge API p. 106). 3 OVERRIDE: one PATCH "
    "business-entity/public/api/v1/entity/{name}/{survivor}?sourceSystem= with [{op: replace, "
    "path, value}] for each field in winners plus its clns_<field> twin (Update Master Record "
    "Field pp. 67-68); skipped when approvalRequired is true. 4 READ_BACK the survivor. "
    "400 before any call when the request is invalid. A 429 before the merge is passed "
    "through; after the merge it stops the rest and is reported in steps. Never retried.",
)
def merge(
    name: EntityName, service: Service, request: Annotated[MergeRequest, Body()]
) -> MergeResponse:
    try:
        result = service.merge(name, request)
    except (B360InputError, SourceNotAllowedError) as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    return _merge_logged(name, result)


def _merge_logged(name: str, result: MergeResponse) -> MergeResponse:
    if result.surviving_business_id is not None:
        history.add_merge(
            name, result.business_ids, result.surviving_business_id, result.approval_required
        )
    return result


@router.post(
    "/entities/{name}/records/{business_id}/unmerge",
    response_model=UnmergeResponse,
    operation_id="b360_unmerge",
    summary="WRITE: take source records out of a master record (Unmerge API)",
    description="POST business-entity/public/api/v1/entity-group/{name}/{businessId}"
    "?_keepRelsWith=BUSINESS_ID[&_allowMergeBack=MAY_MERGE] with [{sourcePKey, sourceSystem}] "
    "(pp. 107-110). Default grouping: each removed source gets its own master (EACH). "
    "One call, never retried; 429 passed through.",
)
def unmerge(
    name: EntityName,
    business_id: BusinessId,
    service: Service,
    request: Annotated[UnmergeRequest, Body()],
) -> UnmergeResponse:
    try:
        result = service.unmerge(name, business_id, request)
    except B360InputError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    history.add_unmerge(name, business_id, result.sources, result.approval_required)
    return result


@router.get(
    "/entities/{name}/records/{business_id}/merge-history",
    response_model=MasterMergeHistory,
    operation_id="b360_master_merge_history",
    summary="Merge history (M): who contributes what to this master now",
    description="Read-only. GET entity/{name}/{businessId}?_showContentMeta=true (content meta "
    "p. 19, Read Master Record pp. 56-58): per field the trust entry (source system / pkey, "
    "trustRule, trustScore, manualOverride); entity-member (p. 70) + entity-xref (p. 80) per "
    "member for dates, oldest first. IDMC has NO read-merge-history API; merges / unmerges "
    "pressed in this app are added from backend memory (lost on restart). 429 passed through.",
)
def master_merge_history(
    name: EntityName, business_id: BusinessId, service: Service
) -> MasterMergeHistory:
    return service.master_history(name, business_id)


@router.get(
    "/entities/{name}/sources/{source_system}/{source_pkey}/merge-history",
    response_model=SourceMergeHistory,
    operation_id="b360_source_merge_history",
    summary="Merge history (S): a source record's trust, its master, and which values won",
    description="Read-only. GET entity-xref/{name}/{system}/{pkey}?_showContentMeta=true (pp. "
    "19, 80) + the master with _showContentMeta=true. 'won' = source value equals the master "
    "value now. No merge-event log exists in the IDMC API. 404 if the source record is unknown.",
)
def source_merge_history(
    name: EntityName,
    source_system: SourceSystem,
    source_pkey: SourcePKey,
    service: Service,
) -> SourceMergeHistory:
    try:
        return service.source_history(name, source_system, source_pkey)
    except SourceRecordNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
