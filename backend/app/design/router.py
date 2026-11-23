"""HTTP routes of the Design notebook (0.9.15). Mounted at /api/design. READ-ONLY: GET only,
nothing here writes to IDMC. refresh=true bypasses tx-mdm's short caches (the Refresh button)."""

from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Path, Query

from app.common.naming import Identifier128
from app.dependencies import get_design_service
from app.design.models import AssetDetail, AssetList, AssetTypeList, DesignAssetType
from app.design.service import DesignNotFoundError, DesignService

router = APIRouter(prefix="/api/design", tags=["design"])

Service = Annotated[DesignService, Depends(get_design_service)]
AssetId = Annotated[Identifier128, Path(min_length=1, max_length=128)]
Refresh = Annotated[bool, Query(description="true = re-read from IDMC (skip tx-mdm's cache).")]
IncludeAll = Annotated[
    bool,
    Query(description="true = every asset; default hides product assets (own-name rule, 0.9.17)."),
]


@router.get(
    "/types",
    response_model=AssetTypeList,
    operation_id="design_types",
    summary="Asset types of the Design page (no IDMC call)",
)
def design_types(service: Service) -> AssetTypeList:
    return service.types()


@router.get(
    "/assets/{asset_type}",
    response_model=AssetList,
    operation_id="design_assets",
    summary="Assets of one type (his own by name prefix): name, path, updated time / by",
)
def design_assets(
    asset_type: DesignAssetType,
    service: Service,
    refresh: Refresh = False,
    include_all: IncludeAll = False,
) -> AssetList:
    return service.list_assets(asset_type, refresh, include_all)


@router.get(
    "/assets/{asset_type}/{asset_id}",
    response_model=AssetDetail,
    operation_id="design_asset",
    summary="One asset: created / updated / by, runtime environment name, what it uses",
)
def design_asset(
    asset_type: DesignAssetType, asset_id: AssetId, service: Service, refresh: Refresh = False
) -> AssetDetail:
    try:
        return service.detail(asset_type, asset_id, refresh)
    except DesignNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
