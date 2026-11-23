"""HTTP routes for the B360 Data notebook. Mounted at /api/b360.

All read-only except POST /entities/{name}/records (Create Master Record), which runs only when
a person presses Save / Send to B360 in the Add records tab.
"""

from typing import Annotated

from fastapi import APIRouter, Body, Depends, HTTPException, Path, Query

from app.b360data import endpoints as ep
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
    RecordPage,
    SortOrder,
    SourceSystemList,
)
from app.b360data.service import (
    B360DataService,
    B360InputError,
    DuplicateSourcePKeyError,
    SourceNotAllowedError,
)
from app.dependencies import get_b360_data_service

router = APIRouter(prefix="/api/b360", tags=["b360"])

Service = Annotated[B360DataService, Depends(get_b360_data_service)]
EntityName = Annotated[str, Path(pattern=r"^[A-Za-z0-9._-]{1,128}$")]


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
    return service.metadata(name)


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
    return service.generate(name, request)


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
