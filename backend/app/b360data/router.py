"""HTTP routes for the B360 Data notebook. Mounted at /api/b360. All read-only."""

from typing import Annotated

from fastapi import APIRouter, Depends, Path, Query

from app.b360data import endpoints as ep
from app.b360data.models import BusinessEntity, BusinessEntityList, EntityScope, RecordPage
from app.b360data.service import B360DataService
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
    summary="First N master records of one business entity",
    description="Read-only POST search/public/api/v1/search with entityType={name}, "
    "search=*. Columns and field groups come from the entity metadata.",
)
def entity_records(
    name: EntityName,
    service: Service,
    limit: Annotated[int, Query(ge=1, le=ep.MAX_LIMIT)] = ep.DEFAULT_LIMIT,
) -> RecordPage:
    return service.records(name, limit)
