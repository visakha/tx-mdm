# ruff: noqa: N815 - the wire models below use IDMC's own JSON names (camelCase) on purpose.
"""0.9.14 (Vamsi 03:15 CST): "I would also like the API docs that are specific to IDMC calls only."

ONE typed, declarative registry of every Informatica IDMC call this backend makes. It is used by:
- IdmcHttp.request / request_bytes: every outbound call takes an IdmcCallSpec (method and session
  header come from it), so no IDMC call can exist without a registry row (mypy enforces it).
- Copy IDMC curl (idmc_echo): each recorded call carries its registry id.
- /openapi-idmc.json (/docs-idmc): built from this table only, never hand-written.

Paths come from the endpoints modules (one constant per path), so code, docs and curl share them.
Doc status: REFERENCE = printed in an Informatica REST API reference (page in `doc`); KB =
Informatica knowledge base / community article; POSTMAN = Vamsi's B360 Postman collection;
UNVERIFIED_DOC = not documented anywhere we found, used because it answers on his org (or is the
documented family's pattern) - treat with care.
"""

from dataclasses import dataclass, field
from enum import StrEnum

from pydantic import BaseModel, Field, JsonValue

from app.b360data import endpoints as b360_ep
from app.cdi import endpoints as cdi_ep
from app.mdm import endpoints as mdm_ep


class SessionHeader(StrEnum):
    """Session header names IDMC uses (MDM: IDS-SESSION-ID, CDI v3: INFA-SESSION-ID, v2:
    icSessionId). The value in a script is always the login variable, never a real id."""

    IDS = "IDS-SESSION-ID"
    INFA = "INFA-SESSION-ID"
    IC = "icSessionId"


class HttpMethod(StrEnum):
    GET = "GET"
    POST = "POST"
    PUT = "PUT"
    PATCH = "PATCH"
    DELETE = "DELETE"


class IdmcHost(StrEnum):
    """Which IDMC host a path is relative to (examples are dm1-us / usw1, his org)."""

    LOGIN = "LOGIN"  # settings idmc_login_url, e.g. https://dm1-us.informaticacloud.com
    PLATFORM = "PLATFORM"  # login reply products[0].baseApiUrl (.../saas)
    POD = "POD"  # baseApiUrl without /saas (advanced taskflows)
    MDM = "MDM"  # settings idmc_mdm_url, e.g. https://usw1-mdm.dm1-us.informaticacloud.com


@dataclass(frozen=True)
class HostInfo:
    server: str  # example server URL for the docs
    doc_prefix: str  # prefix between server and the code path (PLATFORM paths sit under /saas)
    words: str


HOSTS: dict[IdmcHost, HostInfo] = {
    IdmcHost.LOGIN: HostInfo(
        "https://dm1-us.informaticacloud.com", "", "login host (settings idmc_login_url)"
    ),
    IdmcHost.PLATFORM: HostInfo(
        "https://usw1.dm1-us.informaticacloud.com",
        "/saas",
        "platform host = login reply products[0].baseApiUrl (.../saas)",
    ),
    IdmcHost.POD: HostInfo(
        "https://usw1.dm1-us.informaticacloud.com",
        "",
        "pod host = baseApiUrl without /saas (advanced taskflows)",
    ),
    IdmcHost.MDM: HostInfo(
        "https://usw1-mdm.dm1-us.informaticacloud.com",
        "",
        "Business 360 / MDM host (settings idmc_mdm_url)",
    ),
}


class DocStatus(StrEnum):
    REFERENCE = "REFERENCE"
    KB = "KB"
    POSTMAN = "POSTMAN"
    UNVERIFIED_DOC = "UNVERIFIED_DOC"


class Area(StrEnum):
    LOGIN = "Login"
    CDI = "CDI and taskflows"
    B360_JOBS = "Business 360 jobs"
    B360_METADATA = "Business 360 metadata"
    B360_DATA = "Business 360 records"


@dataclass(frozen=True)
class QueryParam:
    name: str
    description: str
    required: bool = False


# ---- IDMC wire shapes, only as far as this backend knows them (more fields may exist) ----


class LoginRequest(BaseModel):
    username: str
    password: str = Field(description="Never stored or echoed by tx-mdm.")


class LoginUserInfo(BaseModel):
    sessionId: str


class LoginProduct(BaseModel):
    name: str | None = None
    baseApiUrl: str


class LoginResponse(BaseModel):
    userInfo: LoginUserInfo
    products: list[LoginProduct]


class JsonPatchOp(BaseModel):
    op: str = Field(description="add | replace | remove")
    path: str
    value: JsonValue = None


class BusinessIdRef(BaseModel):
    businessId: str


class SourceKeyRef(BaseModel):
    sourcePKey: str
    sourceSystem: str


class ApprovalResponse(BaseModel):
    approvalRequired: bool | None = None


class MergeResponse(BaseModel):
    approvalRequired: bool | None = None
    businessId: str | None = Field(default=None, description="The surviving master.")


class CreateRecordResponse(BaseModel):
    approvalRequired: bool | None = None
    businessId: str | None = None
    id: str | None = Field(default=None, description="Deprecated (p. 55).")


class SearchFilter(BaseModel):
    fieldName: str
    comparator: str
    fieldValue: JsonValue = None


class SearchFilters(BaseModel):
    filter: list[SearchFilter] = Field(default_factory=list)


class SearchSort(BaseModel):
    fieldName: str
    order: str


class SearchRequest(BaseModel):
    search: str = "*"
    entityType: str | None = None
    recordOffset: int | None = None
    recordsToReturn: int | None = None
    pageSize: int | None = None
    filters: SearchFilters | None = None
    sort: list[SearchSort] | None = None


class SearchResponse(BaseModel):
    totalRecords: int | None = None
    records: list[dict[str, JsonValue]] = Field(default_factory=list)


class EntityMemberRef(BaseModel):
    sourcePKey: str
    sourceSystem: str


class EntityMembersResponse(BaseModel):
    content: list[EntityMemberRef] = Field(default_factory=list)


class JobRunRequest(BaseModel):
    taskFederatedId: str
    taskType: str


class JobInstanceRunRequest(BaseModel):
    jobDefinitionId: str


class JobSearchRequest(BaseModel):
    search: str = "*"
    pageSize: int | None = None
    pageOffset: int | None = None


class TaskflowTerminateRequest(BaseModel):
    runid: list[str] = Field(description="Up to 200 run ids.")


class TaskflowRunRequest(BaseModel):
    """The taskflow's own input fields (e.g. jobInstanceId for tf_MDM_*), as published."""

    model_config = {"extra": "allow"}


# ---- the registry ----


@dataclass(frozen=True)
class IdmcCallSpec:
    id: str
    area: Area
    method: HttpMethod
    host: IdmcHost
    path: str  # as the code builds it, relative to the host (PLATFORM: relative to .../saas)
    auth: SessionHeader | None
    summary: str
    doc: str
    status: DocStatus
    query: tuple[QueryParam, ...] = ()
    request_model: type[BaseModel] | None = None
    request_array: bool = False  # request body is a JSON array of request_model
    response_model: type[BaseModel] | None = None
    notes: str = ""
    path_params: tuple[str, ...] = field(default=())

    @property
    def writes(self) -> bool:
        return self.method != HttpMethod.GET

    @property
    def session_headers(self) -> tuple[str, ...]:
        return () if self.auth is None else (self.auth.value,)

    def doc_path(self) -> str:
        return HOSTS[self.host].doc_prefix + self.path


B360_REF = "Business 360 REST API Reference (Oct 2026)"
IICS_REF = "IICS REST API Reference (Nov 2025)"

LOGIN = IdmcCallSpec(
    "login",
    Area.LOGIN,
    HttpMethod.POST,
    IdmcHost.LOGIN,
    "/saas/public/core/v3/login",
    None,
    "v3 login: session id + baseApiUrl",
    f"{IICS_REF}, Platform REST API v3 Login",
    DocStatus.REFERENCE,
    request_model=LoginRequest,
    response_model=LoginResponse,
    notes="Not echoed into Copy IDMC curl calls (the scripts log in themselves).",
)

# CDI / taskflows
PLATFORM_OBJECTS = IdmcCallSpec(
    "platform-objects",
    Area.CDI,
    HttpMethod.GET,
    IdmcHost.PLATFORM,
    cdi_ep.OBJECTS,
    SessionHeader.INFA,
    "Find assets (task lists: MTT / WORKFLOW / TASKFLOW; MDM_JOB_DEFINITION)",
    f"{IICS_REF}, v3 objects (Finding an asset)",
    DocStatus.REFERENCE,
    query=(
        QueryParam("q", "e.g. type=='TASKFLOW' or type=='MDM_JOB_DEFINITION'", True),
        QueryParam("limit", "page size, up to 200"),
        QueryParam("skip", "offset"),
    ),
)
JOB_RUN = IdmcCallSpec(
    "cdi-job-run",
    Area.CDI,
    HttpMethod.POST,
    IdmcHost.PLATFORM,
    cdi_ep.JOB_RUN,
    SessionHeader.IC,
    "Run a CDI task (mapping task, linear taskflow)",
    f"{IICS_REF}, v2 job",
    DocStatus.REFERENCE,
    request_model=JobRunRequest,
)
ACTIVITY_MONITOR = IdmcCallSpec(
    "cdi-activity-monitor",
    Area.CDI,
    HttpMethod.GET,
    IdmcHost.PLATFORM,
    cdi_ep.ACTIVITY_MONITOR,
    SessionHeader.IC,
    "Running jobs",
    f"{IICS_REF}, v2 activity/activityMonitor",
    DocStatus.REFERENCE,
    query=(QueryParam("details", "true for child rows"),),
)
ACTIVITY_LOG = IdmcCallSpec(
    "cdi-activity-log",
    Area.CDI,
    HttpMethod.GET,
    IdmcHost.PLATFORM,
    cdi_ep.ACTIVITY_LOG,
    SessionHeader.IC,
    "Finished jobs (state 1 success, 2 warning, 3 failed)",
    f"{IICS_REF}, v2 activity/activityLog",
    DocStatus.REFERENCE,
    query=(
        QueryParam("runId", "run id"),
        QueryParam("taskId", "task id"),
        QueryParam("rowLimit", "rows"),
    ),
)
SESSION_LOG = IdmcCallSpec(
    "cdi-session-log",
    Area.CDI,
    HttpMethod.GET,
    IdmcHost.PLATFORM,
    cdi_ep.SESSION_LOG,
    SessionHeader.IC,
    "Session log of one activity-log entry (text)",
    f"{IICS_REF}, v2 activity/activityLog/<id>/sessionLog",
    DocStatus.REFERENCE,
    path_params=("log_id",),
)
TASKFLOW_RUN = IdmcCallSpec(
    "taskflow-run",
    Area.CDI,
    HttpMethod.POST,
    IdmcHost.POD,
    cdi_ep.TASKFLOW_RUN,
    SessionHeader.INFA,
    "Start a published advanced taskflow by its API name",
    "Informatica docs: Application Integration, run a taskflow as a REST service (active-bpel/rt)",
    DocStatus.REFERENCE,
    request_model=TaskflowRunRequest,
    path_params=("api_name",),
    notes="INFA-SESSION-ID on this call and the run-id field name: UNVERIFIED (api-facts.md).",
)
TASKFLOW_STATUS = IdmcCallSpec(
    "taskflow-status",
    Area.CDI,
    HttpMethod.GET,
    IdmcHost.POD,
    cdi_ep.TASKFLOW_STATUS,
    SessionHeader.INFA,
    "Status of one advanced taskflow run",
    "Informatica docs: Application Integration, taskflow status (active-bpel/services/tf/status)",
    DocStatus.REFERENCE,
    query=(QueryParam("subtaskDetails", "Yes: per child task status (KB: change in behavior)"),),
    path_params=("run_id",),
)
TASKFLOW_TERMINATE = IdmcCallSpec(
    "taskflow-terminate",
    Area.CDI,
    HttpMethod.PUT,
    IdmcHost.POD,
    cdi_ep.TASKFLOW_TERMINATE,
    SessionHeader.INFA,
    "Terminate advanced taskflow runs (204 = terminated, 500 = invalid id)",
    "Informatica KB 000216333 (HOW TO: Stop/Terminate Advanced Task flows using API)",
    DocStatus.KB,
    request_model=TaskflowTerminateRequest,
)

# Business 360 jobs
JOB_SEARCH = IdmcCallSpec(
    "b360-job-search",
    Area.B360_JOBS,
    HttpMethod.POST,
    IdmcHost.MDM,
    mdm_ep.JOB_SEARCH,
    SessionHeader.IDS,
    "Search job instances (Currently running / recent)",
    f"{B360_REF}, job search, example pp. 132-134",
    DocStatus.REFERENCE,
    request_model=JobSearchRequest,
)
JOB_INSTANCE_RUN = IdmcCallSpec(
    "b360-job-run",
    Area.B360_JOBS,
    HttpMethod.POST,
    IdmcHost.MDM,
    mdm_ep.JOB_INSTANCE_RUN,
    SessionHeader.IDS,
    "Run a Business 360 job (Ingress | Egress | MatchMerge)",
    f"{B360_REF} + Vamsi's B360 Postman collection, jobInstance",
    DocStatus.REFERENCE,
    request_model=JobInstanceRunRequest,
    path_params=("kind",),
)
JOB_INSTANCE_READ = IdmcCallSpec(
    "b360-job-read",
    Area.B360_JOBS,
    HttpMethod.GET,
    IdmcHost.MDM,
    mdm_ep.JOB_INSTANCE_READ,
    SessionHeader.IDS,
    "One job instance: _meta.state, jobLevelMetrics (summary)",
    f"{B360_REF}, jobInstance read",
    DocStatus.REFERENCE,
    query=(QueryParam("details", "true for jobLevelMetrics"),),
    path_params=("instance_id",),
)

# Business 360 metadata
DATAMODEL = IdmcCallSpec(
    "b360-datamodel",
    Area.B360_METADATA,
    HttpMethod.GET,
    IdmcHost.MDM,
    b360_ep.DATAMODEL,
    SessionHeader.IDS,
    "Every business entity configured in the org",
    "Vamsi's B360 Postman collection (Meta Data API 3: tenantModel/datamodel)",
    DocStatus.POSTMAN,
    notes="Response shape not printed in the reference: UNVERIFIED.",
)
BUSINESS_ENTITY = IdmcCallSpec(
    "b360-business-entity",
    Area.B360_METADATA,
    HttpMethod.GET,
    IdmcHost.MDM,
    b360_ep.BUSINESS_ENTITY,
    SessionHeader.IDS,
    "One business entity: fields, field groups, lookups (Reference 360 lists)",
    "Informatica KB (search and facetable attributes in C360 SaaS) + reference pp. 94-96 family",
    DocStatus.KB,
    path_params=("guid",),
    notes="Response shape not printed in the reference: UNVERIFIED.",
)
SOURCE_SYSTEMS = IdmcCallSpec(
    "b360-source-systems",
    Area.B360_METADATA,
    HttpMethod.GET,
    IdmcHost.MDM,
    b360_ep.SOURCE_SYSTEMS,
    SessionHeader.IDS,
    "Source system discovery",
    "Not documented; same /metadata/api/v2/objects family; answers on his org (2026-11-23)",
    DocStatus.UNVERIFIED_DOC,
)

# Business 360 records
SEARCH = IdmcCallSpec(
    "b360-search",
    Area.B360_DATA,
    HttpMethod.POST,
    IdmcHost.MDM,
    b360_ep.SEARCH,
    SessionHeader.IDS,
    "Search master records (also Reference 360 value entities rdm.value.be.*)",
    f"{B360_REF}, Search API pp. 20-36",
    DocStatus.REFERENCE,
    request_model=SearchRequest,
    response_model=SearchResponse,
    notes="No server-side sourceSystem filter is documented. Sort on _meta.lastUpdateDate "
    "UNVERIFIED.",
)
CREATE_RECORD = IdmcCallSpec(
    "b360-create-record",
    Area.B360_DATA,
    HttpMethod.POST,
    IdmcHost.MDM,
    b360_ep.CREATE_RECORD,
    SessionHeader.IDS,
    "Create master record (from a source record)",
    f"{B360_REF}, Create Master Record pp. 51-55",
    DocStatus.REFERENCE,
    query=(
        QueryParam("sourceSystem", "source system id", True),
        QueryParam("sourcePKey", "source primary key", True),
    ),
    response_model=CreateRecordResponse,
    path_params=("guid",),
    notes="Body = the record's fields by internal name (see /openapi-typed.json Record_<entity>).",
)
READ_RECORD = IdmcCallSpec(
    "b360-read-master",
    Area.B360_DATA,
    HttpMethod.GET,
    IdmcHost.MDM,
    b360_ep.READ_RECORD,
    SessionHeader.IDS,
    "Read master record by business id",
    f"{B360_REF}, Read Master Record pp. 56-58; content meta p. 19",
    DocStatus.REFERENCE,
    query=(QueryParam("_showContentMeta", "true: trust / survivorship per field (p. 19)"),),
    path_params=("guid", "business_id"),
)
UPDATE_MASTER_FIELD = IdmcCallSpec(
    "b360-update-master-field",
    Area.B360_DATA,
    HttpMethod.PATCH,
    IdmcHost.MDM,
    b360_ep.READ_RECORD,
    SessionHeader.IDS,
    "Update master record field (Merge (M) winners only)",
    f"{B360_REF}, Update Master Record Field pp. 67-68",
    DocStatus.REFERENCE,
    query=(QueryParam("sourceSystem", "source system of the override", True),),
    request_model=JsonPatchOp,
    request_array=True,
    response_model=ApprovalResponse,
    path_params=("guid", "business_id"),
)
ENTITY_MEMBERS = IdmcCallSpec(
    "b360-source-records-by-master",
    Area.B360_DATA,
    HttpMethod.GET,
    IdmcHost.MDM,
    b360_ep.ENTITY_MEMBER,
    SessionHeader.IDS,
    "Read source records by master record",
    f"{B360_REF}, Read Source Records by Master Record pp. 70-71",
    DocStatus.REFERENCE,
    response_model=EntityMembersResponse,
    path_params=("guid", "business_id"),
)
READ_SOURCE = IdmcCallSpec(
    "b360-read-source",
    Area.B360_DATA,
    HttpMethod.GET,
    IdmcHost.MDM,
    b360_ep.ENTITY_XREF,
    SessionHeader.IDS,
    "Read source record",
    f"{B360_REF}, Read Source Record pp. 80-84",
    DocStatus.REFERENCE,
    query=(QueryParam("_showContentMeta", "true: trust per field"),),
    path_params=("guid", "source_system", "source_pkey"),
)
UPDATE_SOURCE_FIELD = IdmcCallSpec(
    "b360-update-source-field",
    Area.B360_DATA,
    HttpMethod.PATCH,
    IdmcHost.MDM,
    b360_ep.ENTITY_XREF,
    SessionHeader.IDS,
    "Update source record field (Edit records (S) Save)",
    f"{B360_REF}, Update Source Record Field pp. 88-90",
    DocStatus.REFERENCE,
    request_model=JsonPatchOp,
    request_array=True,
    response_model=ApprovalResponse,
    path_params=("guid", "source_system", "source_pkey"),
)
MERGE = IdmcCallSpec(
    "b360-merge",
    Area.B360_DATA,
    HttpMethod.POST,
    IdmcHost.MDM,
    b360_ep.ENTITY_GROUP,
    SessionHeader.IDS,
    "Merge up to 10 master records (entity-group)",
    f"{B360_REF}, Merge API p. 106",
    DocStatus.REFERENCE,
    request_model=BusinessIdRef,
    request_array=True,
    response_model=MergeResponse,
    path_params=("guid",),
    notes="Items may also be {sourcePKey, sourceSystem}; tx-mdm sends businessId only.",
)
UNMERGE = IdmcCallSpec(
    "b360-unmerge",
    Area.B360_DATA,
    HttpMethod.POST,
    IdmcHost.MDM,
    b360_ep.ENTITY_GROUP_MASTER,
    SessionHeader.IDS,
    "Unmerge source records from a master",
    f"{B360_REF}, Unmerge API pp. 107-110",
    DocStatus.REFERENCE,
    query=(
        QueryParam("_keepRelsWith", "BUSINESS_ID", True),
        QueryParam("_allowMergeBack", "MAY_MERGE (optional)"),
    ),
    request_model=SourceKeyRef,
    request_array=True,
    response_model=ApprovalResponse,
    path_params=("guid", "business_id"),
)

IDMC_CALLS: tuple[IdmcCallSpec, ...] = (
    LOGIN,
    PLATFORM_OBJECTS,
    JOB_RUN,
    ACTIVITY_MONITOR,
    ACTIVITY_LOG,
    SESSION_LOG,
    TASKFLOW_RUN,
    TASKFLOW_STATUS,
    TASKFLOW_TERMINATE,
    JOB_SEARCH,
    JOB_INSTANCE_RUN,
    JOB_INSTANCE_READ,
    DATAMODEL,
    BUSINESS_ENTITY,
    SOURCE_SYSTEMS,
    SEARCH,
    CREATE_RECORD,
    READ_RECORD,
    UPDATE_MASTER_FIELD,
    ENTITY_MEMBERS,
    READ_SOURCE,
    UPDATE_SOURCE_FIELD,
    MERGE,
    UNMERGE,
)
