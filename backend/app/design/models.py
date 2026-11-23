"""Typed models of the Design notebook (0.9.15). Read-only metadata of CDI design assets.

Vamsi (voice, 2026-11-23 03:22-03:24 CST): "given a task flow you can interrogate the mapping
tasks that are behind the scene and for each of the mapping task ... get information like when it
was created, when it was updated, who updated it and what runtime it is." The runtime lives on the
mapping task; a taskflow has none of its own.
"""

from dataclasses import dataclass
from datetime import datetime
from enum import StrEnum

from pydantic import BaseModel, Field

from app.common.naming import MatchKind, NameRule


class DesignAssetType(StrEnum):
    """Asset types of the Design page. v3 values are IDMC's own v3 objects `type` strings."""

    MTT = "MTT"
    TASKFLOW = "TASKFLOW"
    DTEMPLATE = "DTEMPLATE"
    DSS = "DSS"
    WORKFLOW = "WORKFLOW"
    CONNECTION = "CONNECTION"
    RUNTIME_ENVIRONMENT = "RUNTIME_ENVIRONMENT"


class ListSource(StrEnum):
    """Which documented IDMC call lists the type."""

    V3_OBJECTS = "v3 objects"
    V2_CONNECTION = "v2 connection"
    V2_RUNTIME_ENVIRONMENT = "v2 runtimeEnvironment"


class DetailSource(StrEnum):
    """Which documented IDMC call gives created / updated / by for one asset."""

    V2_MTTASK = "v2 mttask/frs/<id>"
    V2_MAPPING_SEARCH = "v2 mapping/search?name="
    V2_CONNECTION = "v2 connection/<id>"
    V2_RUNTIME_ENVIRONMENT = "v2 runtimeEnvironment"
    V3_ONLY = "v3 objects only"


@dataclass(frozen=True)
class TypeRule:
    """One row of the asset type table (declarative; the UI shows these words)."""

    label: str
    lists: ListSource
    detail: DetailSource
    has_runtime: bool
    note: str


NO_CREATE = (
    "Created time / by are not available for this type: the v3 objects API gives update time / "
    "by only, and the IICS REST API Reference (Nov 2025) documents no v2 detail resource for it."
)

TYPE_RULES: dict[DesignAssetType, TypeRule] = {
    DesignAssetType.MTT: TypeRule(
        "Mapping task",
        ListSource.V3_OBJECTS,
        DetailSource.V2_MTTASK,
        True,
        "Runtime environment, created and updated come from v2 mttask.",
    ),
    DesignAssetType.TASKFLOW: TypeRule(
        "Taskflow",
        ListSource.V3_OBJECTS,
        DetailSource.V3_ONLY,
        False,
        "A taskflow has no runtime environment of its own; each mapping task it uses has one. "
        + NO_CREATE,
    ),
    DesignAssetType.DTEMPLATE: TypeRule(
        "Mapping",
        ListSource.V3_OBJECTS,
        DetailSource.V2_MAPPING_SEARCH,
        False,
        "Created / updated come from v2 mapping, matched by name.",
    ),
    DesignAssetType.DSS: TypeRule(
        "Synchronization task", ListSource.V3_OBJECTS, DetailSource.V3_ONLY, False, NO_CREATE
    ),
    DesignAssetType.WORKFLOW: TypeRule(
        "Linear taskflow", ListSource.V3_OBJECTS, DetailSource.V3_ONLY, False, NO_CREATE
    ),
    DesignAssetType.CONNECTION: TypeRule(
        "Connection",
        ListSource.V2_CONNECTION,
        DetailSource.V2_CONNECTION,
        True,
        "Safe fields only: user names, passwords and tokens are never read into tx-mdm.",
    ),
    DesignAssetType.RUNTIME_ENVIRONMENT: TypeRule(
        "Runtime environment",
        ListSource.V2_RUNTIME_ENVIRONMENT,
        DetailSource.V2_RUNTIME_ENVIRONMENT,
        False,
        "Secure Agent groups and serverless environments.",
    ),
}


# 0.9.17 (Vamsi voice 08:49-08:50 CST): "they are both a mix of what I have written and what came
# with the product ... Only keep those." His own assets by name prefix, exact case. Types without a
# row show everything (no convention given yet: connections, runtime environments, DSS, WORKFLOW).
OWN_MEANING = "his own asset"
OWN_NAME_RULES: dict[DesignAssetType, NameRule[str]] = {
    DesignAssetType.DTEMPLATE: NameRule(MatchKind.PREFIX, "m_", OWN_MEANING, exact_case=True),
    DesignAssetType.MTT: NameRule(MatchKind.PREFIX, "mt_", OWN_MEANING, exact_case=True),
    DesignAssetType.TASKFLOW: NameRule(MatchKind.PREFIX, "tf_", OWN_MEANING, exact_case=True),
}


class NameFilterInfo(BaseModel):
    """The own-name rule applied to a list (0.9.17)."""

    kind: MatchKind
    value: str = Field(description='Name prefix of his own assets, exact case (e.g. "m_").')
    exact_case: bool
    applied: bool = Field(description="False when include_all=true asked for every asset.")


PORTAL_DESCRIPTION = (
    "IDMC portal page of this asset (0.9.16, Design page only): mapping, mapping task and "
    "taskflow; null for other types (no known pattern). UNVERIFIED-DOC: from his browser."
)


class AssetTypeInfo(BaseModel):
    type: DesignAssetType
    label: str
    listed_by: ListSource
    detail_by: DetailSource
    has_runtime: bool = Field(description="True when the asset itself names a runtime environment.")
    note: str


class AssetTypeList(BaseModel):
    types: list[AssetTypeInfo]


class AssetSummary(BaseModel):
    """One row of the asset list."""

    id: str = Field(description="Id to open the detail with (v3 id; v2 id for connections / RE).")
    name: str
    path: str = Field(description="Project / folder path (v3); the name for v2-listed types.")
    type: DesignAssetType
    description: str = ""
    updated_at: datetime | None = None
    updated_by: str = ""
    portal_url: str | None = Field(default=None, description=PORTAL_DESCRIPTION)


class AssetList(BaseModel):
    type: DesignAssetType
    label: str
    as_of: datetime
    assets: list[AssetSummary]
    from_cache: bool = Field(description="True when served from tx-mdm's cache (Refresh re-reads).")
    name_filter: NameFilterInfo | None = Field(
        default=None, description="Own-name rule of this type (0.9.17); null = no rule, all shown."
    )
    shown_count: int = Field(default=0, description="Assets in this answer.")
    hidden_count: int = Field(default=0, description="Assets IDMC listed that the rule hid.")
    notes: list[str] = Field(default_factory=list)


class RuntimeEnvironmentRef(BaseModel):
    id: str
    name: str | None = Field(description="Resolved from v2 runtimeEnvironment; null if unknown.")


class MappingRef(BaseModel):
    """The mapping a mapping task runs (mtTask.mappingId -> v2 mapping/<id>)."""

    id: str
    name: str | None = None
    created_at: datetime | None = None
    created_by: str = ""
    updated_at: datetime | None = None
    updated_by: str = ""


class UsedAsset(BaseModel):
    """One dependency (v3 references) with, for a mapping task, its own v2 metadata."""

    id: str = Field(description="v3 (federated) id.")
    v2_id: str | None = Field(default=None, description="appContextId: the id v2 calls take.")
    name: str
    path: str
    type: str = Field(description="IDMC's type string as returned (e.g. MTT, DTEMPLATE).")
    open_type: DesignAssetType | None = Field(
        default=None, description="Design page type to open it with; null = not supported."
    )
    open_id: str | None = Field(default=None, description="Id to pass to the detail route.")
    description: str = ""
    updated_at: datetime | None = None
    created_at: datetime | None = None
    created_by: str = ""
    updated_by: str = ""
    runtime_environment: RuntimeEnvironmentRef | None = None
    detail_note: str = ""
    portal_url: str | None = Field(default=None, description=PORTAL_DESCRIPTION)


class AssetDetail(BaseModel):
    type: DesignAssetType
    label: str
    as_of: datetime
    id: str
    v2_id: str | None = None
    name: str
    path: str
    description: str = ""
    created_at: datetime | None = None
    created_by: str = ""
    updated_at: datetime | None = None
    updated_by: str = ""
    runtime_environment: RuntimeEnvironmentRef | None = None
    runtime_note: str = ""
    mapping: MappingRef | None = None
    connection_type: str | None = None
    is_shared: bool | None = Field(default=None, description="Runtime environment: shared.")
    uses: list[UsedAsset] = Field(default_factory=list, description="v3 references refType=Uses.")
    used_by: list[UsedAsset] = Field(
        default_factory=list, description="v3 references refType=usedBy (mappings only)."
    )
    portal_url: str | None = Field(default=None, description=PORTAL_DESCRIPTION)
    notes: list[str] = Field(default_factory=list)
