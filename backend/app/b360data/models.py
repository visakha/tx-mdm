"""Typed public models of the B360 Data notebook. Every /api/b360 route returns these, so
Swagger (/docs) shows the full schemas and frontend/src/b360/api-types.ts is generated from them.

Data types: Business 360 REST API Reference (Oct 2026) p. 150 "data types of business entity
fields" (String, Picklist, Dependent Picklist, Date, Double, Boolean, Integer) plus Decimal and
DateTime from the search-term formats table pp. 113-114. UNKNOWN keeps the raw metadata type.
"""

from datetime import date, datetime
from enum import StrEnum

from pydantic import BaseModel, Field


class FieldDataType(StrEnum):
    STRING = "STRING"
    PICKLIST = "PICKLIST"
    DEPENDENT_PICKLIST = "DEPENDENT_PICKLIST"
    DATE = "DATE"
    DATETIME = "DATETIME"
    DOUBLE = "DOUBLE"
    DECIMAL = "DECIMAL"
    BOOLEAN = "BOOLEAN"
    INTEGER = "INTEGER"
    UNKNOWN = "UNKNOWN"


class Cardinality(StrEnum):
    ONE = "ONE"
    MANY = "MANY"


class EntityScope(StrEnum):
    FOCUS = "focus"  # only the entities in backend/b360_entities.toml (default)
    ALL = "all"  # every entity the metadata APIs return


class EntityCategory(StrEnum):
    """Decided by name prefix in app.b360data.scope.category_of."""

    CUSTOM = "CUSTOM"  # the org's own entities, e.g. zlv_guest
    OUT_OF_THE_BOX = "OUT_OF_THE_BOX"  # c360.*
    REFERENCE = "REFERENCE"  # rdm.*
    TEMPLATE = "TEMPLATE"  # entity.*


# One cell. Which member is used is driven by the field's declared FieldDataType.
FieldValue = str | int | float | bool | date | datetime | None


class BusinessEntitySummary(BaseModel):
    name: str = Field(description="Internal id (guid) of the business entity, e.g. c360.person.")
    label: str
    category: EntityCategory = Field(description="Custom / out of the box / reference / template.")
    focus: bool = Field(description="True when this entity is listed in b360_entities.toml.")


class FocusEntityStatus(BaseModel):
    """One entry of b360_entities.toml, checked against the org metadata."""

    name: str = Field(description="Entity id as written in b360_entities.toml.")
    label: str = Field(description="Label override from the file, else the metadata label.")
    found: bool = Field(description="False when the org metadata has no entity with this id.")


class BusinessEntityList(BaseModel):
    scope: EntityScope
    entities: list[BusinessEntitySummary] = Field(
        description="focus: only the focus entities found in the metadata; all: every entity."
    )
    total: int = Field(description="How many entities the metadata listed in all.")
    focus: list[FocusEntityStatus] = Field(
        description="Entries of b360_entities.toml in file order, each marked found or not."
    )
    focus_file: str = Field(description="The TOML file the focus list was read from.")
    source: str = Field(description="The metadata call the list was derived from.")


class FieldOrigin(StrEnum):
    """0.9.9: who defined a field / field group (Vamsi 2026-11-23: show system ones in magenta)."""

    CONFIGURED = "CONFIGURED"  # modelled by the org in Business 360 Console (e.g. first_name)
    SYSTEM = "SYSTEM"  # added by Business 360 itself (_meta.*, validation fields, ...)


class OriginSource(StrEnum):
    """Where we learned of the field: the org's metadata reply, or only the reference PDF."""

    METADATA = "METADATA"  # GET metadata/api/v2/objects/businessEntity/<guid>
    DOCUMENTED = "DOCUMENTED"  # B360 REST API Reference Oct 2026 (_meta table p. 61-62, p. 25)


class LookupStatus(StrEnum):
    """0.9.12: how a picklist field's Reference 360 list was found."""

    DECLARED = "DECLARED"  # the metadata names the list / rdm entity (attribute in found_in)
    LABEL_MATCH = "LABEL_MATCH"  # declared code list matched an rdm entity labelled
    # "RDM values of list <code list>" in the datamodel
    GUESSED = "GUESSED"  # metadata names nothing; matched by field name only (labelled a guess)
    NOT_FOUND = "NOT_FOUND"  # nothing named, nothing matched: options fall back to observed


class FieldLookup(BaseModel):
    """0.9.12: the Reference 360 code list behind a picklist (LookupField) field."""

    code_list: str | None = Field(default=None, description="Code list name the metadata gives.")
    master_code_list: str | None = Field(
        default=None, description="Parent code list of a dependent picklist, if given."
    )
    rdm_entity: str | None = Field(
        default=None, description="Searchable B360 entity holding the values (rdm.value.be.*)."
    )
    status: LookupStatus = LookupStatus.NOT_FOUND
    found_in: str | None = Field(
        default=None, description="Raw metadata attribute the list was read from (UNVERIFIED)."
    )
    raw_keys: list[str] = Field(
        default_factory=list,
        description="Every attribute NAME on the raw metadata field (values not kept), to learn "
        "what IDMC calls the reference.",
    )


class EntityField(BaseModel):
    name: str
    label: str
    data_type: FieldDataType
    raw_type: str = Field(description="Type as IDMC sent it (eClass suffix), kept for UNKNOWN.")
    searchable: bool
    mandatory: bool
    origin: FieldOrigin = FieldOrigin.CONFIGURED
    origin_source: OriginSource = OriginSource.METADATA
    lookup: FieldLookup | None = Field(
        default=None, description="Picklist fields only: the Reference 360 list behind it."
    )


class FieldGroup(BaseModel):
    name: str
    label: str
    cardinality: Cardinality
    fields: list[EntityField]
    origin: FieldOrigin = FieldOrigin.CONFIGURED
    origin_source: OriginSource = OriginSource.METADATA


class BusinessEntity(BaseModel):
    name: str
    label: str
    fields: list[EntityField] = Field(description="CONFIGURED root fields (records columns, form).")
    field_groups: list[FieldGroup] = Field(description="CONFIGURED field groups.")
    system_fields: list[EntityField] = Field(
        default_factory=list, description="SYSTEM root fields (Metadata tab only)."
    )
    system_field_groups: list[FieldGroup] = Field(
        default_factory=list, description="SYSTEM field groups, e.g. _meta (Metadata tab only)."
    )


class FieldGroupRows(BaseModel):
    group: str = Field(description="FieldGroup.name")
    rows: list[dict[str, FieldValue]] = Field(description="One map per row, keyed by field name.")


class SystemValue(BaseModel):
    """0.9.10: one system value exactly as the reply's _meta carried it (flattened: states.base).
    Only keys IDMC actually returned; nothing is invented."""

    name: str = Field(description="_meta key, nested ones dotted (states.consolidation).")
    value: FieldValue
    origin: FieldOrigin = FieldOrigin.SYSTEM


class EntityRecord(BaseModel):
    business_id: str
    values: dict[str, FieldValue] = Field(description="Top-level fields, keyed by field name.")
    groups: list[FieldGroupRows]
    last_updated: datetime | None = Field(
        default=None, description="_meta.lastUpdateDate: last change via any channel (UTC)."
    )
    updated_by: str | None = Field(default=None, description="_meta.updatedBy")
    system_values: list[SystemValue] = Field(
        default_factory=list, description="0.9.10: every _meta value the reply carried (SYSTEM)."
    )


class SortOrder(StrEnum):
    """0.9.9: the ONLY sort is Last updated (_meta.lastUpdateDate), server-side."""

    NEWEST_FIRST = "NEWEST_FIRST"  # DESCENDING (default)
    OLDEST_FIRST = "OLDEST_FIRST"  # ASCENDING


class NameFilterComparator(StrEnum):
    STARTS_WITH = "STARTS_WITH"  # Search API comparator, partial values allowed (p. 24-25)


class AppliedFilter(BaseModel):
    label: str = Field(description="First name / Last name")
    field_name: str = Field(description="fieldName sent to IDMC, e.g. zlv_guest.first_name")
    comparator: NameFilterComparator
    value: str


class LookupMode(StrEnum):
    SEARCH = "SEARCH"  # Search API page (filters + sort + paging)
    BUSINESS_ID = "BUSINESS_ID"  # Read Master Record by Business ID (p. 56-58)


class FieldVisibility(BaseModel):
    """0.10 (Vamsi 02:01 CST): which fields the Records (M)/(S) columns and record detail show.

    From the entity's `fields = [...]` list in b360_entities.toml: a name commented out there is
    hidden. Names: root field `first_name`, group `x_phone`, group field `x_phone.ph_num`, system
    field `validationType`, record system metadata `_meta.lastUpdateDate`. The Metadata tab always
    shows everything."""

    listed: bool = Field(
        default=False, description="True when the TOML has a fields list (else everything shows)."
    )
    hidden: list[str] = Field(
        default_factory=list, description="Metadata names hidden on the records screens."
    )
    warnings: list[str] = Field(
        default_factory=list, description="TOML names not in the metadata (ignored, not a crash)."
    )


class RecordPage(BaseModel):
    entity: BusinessEntity
    hits: int | None
    records: list[EntityRecord]
    unknown_keys: list[str] = Field(
        description="Record keys the entity metadata did not describe (listed, never guessed)."
    )
    page: int = 1
    page_size: int = 10
    total_pages: int = 1
    sort: SortOrder = SortOrder.NEWEST_FIRST
    filters: list[AppliedFilter] = Field(default_factory=list)
    mode: LookupMode = LookupMode.SEARCH
    business_id: str | None = Field(default=None, description="Set when mode is BUSINESS_ID.")
    note: str = ""
    system_columns: list[EntityField] = Field(
        default_factory=list,
        description="0.9.10: _meta keys present in these records, origin SYSTEM, reply order.",
    )
    visibility: FieldVisibility = Field(default_factory=FieldVisibility)


# ---------------------------------------------------------------------------------------------
# 0.9.8 Add records (Create Master Record). Vamsi, voice 2026-11-23 01:05-01:10 CST.
# ---------------------------------------------------------------------------------------------


class DiscoveryStatus(StrEnum):
    OK = "OK"  # IDMC answered the (undocumented) source-system metadata call
    NOT_AVAILABLE = "NOT_AVAILABLE"  # it did not; the TOML allowed list is all there is


class SourceSystemList(BaseModel):
    allowed: list[str] = Field(
        description="[sources] allowed in b360_entities.toml, exact case. Only these can be sent."
    )
    default: str | None = Field(description="[sources] default (falls back to the first allowed).")
    discovered: list[str] = Field(description="Source system ids IDMC listed (may be empty).")
    not_allowed: list[str] = Field(
        description="Discovered but not in the allowed list: add to b360_entities.toml to allow."
    )
    discovery: DiscoveryStatus
    discovery_note: str = Field(description="What the discovery call returned, in plain words.")
    source: str = Field(description="The metadata call that was tried.")


class FormInput(StrEnum):
    """Which input the frontend renders for a field. Decided by FieldDataType."""

    TEXT = "TEXT"
    INTEGER = "INTEGER"
    DECIMAL = "DECIMAL"
    CHECKBOX = "CHECKBOX"
    DATE = "DATE"
    DATETIME = "DATETIME"


class PicklistOption(BaseModel):
    """One picklist value as IDMC returned it ({"Code", "Name"}, pp. 53, 83). Never invented."""

    code: str
    name: str


class PicklistSource(StrEnum):
    """0.9.10: where a picklist's options came from."""

    REFERENCE_360 = "REFERENCE_360"  # 0.9.12: every record of the rdm.value.be.* entity
    REFERENCE_360_GUESSED = "REFERENCE_360_GUESSED"  # same, but the entity was matched by name
    OBSERVED_IN_RECORDS = "OBSERVED_IN_RECORDS"  # distinct {Code, Name} in Search API replies
    NONE = "NONE"  # no documented list call and none observed: left empty, never invented


class FormField(BaseModel):
    name: str
    label: str
    data_type: FieldDataType
    input: FormInput
    required: bool = Field(description="True when the metadata marks the field mandatory.")
    options: list[PicklistOption] = Field(
        default_factory=list,
        description="PICKLIST only: values IDMC returned (see options_source).",
    )
    options_source: PicklistSource | None = Field(
        default=None, description="PICKLIST only: where options came from (NONE = left empty)."
    )


class FormGroup(BaseModel):
    """0.9.10: one field group in the form / generator (any group, from the metadata)."""

    name: str
    label: str
    cardinality: Cardinality
    fields: list[FormField]


class FormSchema(BaseModel):
    """The entity's root-field form, built from a Pydantic model created from the metadata."""

    entity: str
    label: str
    model_name: str = Field(
        description="Name of the dynamic Pydantic model (pydantic.create_model)."
    )
    fields: list[FormField]
    groups: list[FormGroup] = Field(
        default_factory=list, description="0.9.10: field groups, each a repeatable block."
    )
    skipped_groups: list[str] = Field(
        description="Field groups not offered in the form (empty since 0.9.10)."
    )
    picklist_note: str = Field(default="", description="How picklist options were found.")
    json_schema_text: str = Field(
        description="model_json_schema() of the dynamic model as pretty JSON text, for reference."
    )


class NewRecord(BaseModel):
    source_pkey: str | None = Field(
        default=None,
        min_length=1,
        max_length=255,
        description="sourcePKey. Empty: the backend makes TXMDM-<yyyymmddHHMMSS>-<n>.",
    )
    values: dict[str, FieldValue] = Field(description="Root fields, keyed by field name.")
    groups: list["NewGroupRows"] = Field(
        default_factory=list, description="0.9.10: field group rows (any group in the metadata)."
    )


class NewGroupRow(BaseModel):
    row_id: str | None = Field(
        default=None, max_length=128, description="The row's _id (pp. 53, 86). Empty: new row."
    )
    values: dict[str, FieldValue] = Field(description="Fields of this row, keyed by field name.")


class NewGroupRows(BaseModel):
    group: str = Field(description="FieldGroup.name")
    rows: list[NewGroupRow] = Field(max_length=50)


class GenerateRequest(BaseModel):
    count: int = Field(default=5, ge=1, le=100, description="How many test rows (1-100).")
    seed: int | None = Field(default=None, description="Optional Faker seed for repeatable rows.")


class GeneratedFieldRule(BaseModel):
    field: str
    rule: str = Field(description="How Faker fills this field, in plain words.")


class GeneratedRows(BaseModel):
    entity: str
    rows: list[NewRecord]
    rules: list[GeneratedFieldRule]
    faker_version: str
    note: str


class CreateRequest(BaseModel):
    source_system: str = Field(min_length=1, max_length=128)
    records: list[NewRecord] = Field(min_length=1, max_length=100)


class CreateOutcome(StrEnum):
    CREATED = "CREATED"  # IDMC answered 200 with a businessId
    FAILED = "FAILED"  # IDMC refused this record (its error text is kept); the next ones still go
    NOT_SENT = "NOT_SENT"  # never sent: the run stopped before it (429, 401, 403 or unknown result)
    UNKNOWN = "UNKNOWN"  # no answer (network error): it may or may not exist in B360 now


class CreateResult(BaseModel):
    index: int = Field(description="0-based position in the request.")
    source_pkey: str
    outcome: CreateOutcome
    business_id: str | None = None
    approval_required: bool | None = Field(
        default=None, description="IDMC approvalRequired: a data steward must approve it."
    )
    error: str | None = None


class CreateResponse(BaseModel):
    entity: str
    source_system: str
    created: int
    failed: int
    not_sent: int
    unknown: int
    stopped_reason: str | None = Field(
        description="Why sending stopped early (429 / 401 / 403 / no answer); null if it ran out."
    )
    results: list[CreateResult]


# ---------------------------------------------------------------------------------------------
# 0.9.10 Source records (xref): Records (S), Metadata (S), Edit records (S)
# ---------------------------------------------------------------------------------------------


class SourceKey(BaseModel):
    """One entry of Read Source Records by Master Record (p. 70-71)."""

    source_system: str
    source_pkey: str


class SourceRecord(BaseModel):
    """Read Source Record reply (pp. 80-84), typed. Picklists keep their Code (editable)."""

    entity: str
    source_system: str
    source_pkey: str
    business_id: str = Field(description="_meta.businessId: the master record it belongs to.")
    values: dict[str, FieldValue] = Field(description="Root fields; picklists as their Code.")
    groups: list[NewGroupRows] = Field(description="Field group rows with their _id.")
    last_updated: datetime | None = Field(default=None, description="_meta.lastUpdateDate")
    source_last_updated: datetime | None = Field(
        default=None, description="_meta.sourceLastUpdatedDate (p. 81)"
    )
    updated_by: str | None = None
    xref_type: str | None = Field(default=None, description="_meta.xrefType (p. 83)")
    states: dict[str, str] = Field(
        default_factory=dict, description="_meta.states: base, consolidation, validation ..."
    )
    unknown_keys: list[str] = Field(default_factory=list)
    system_values: list[SystemValue] = Field(
        default_factory=list, description="Every xref _meta value the reply carried (SYSTEM)."
    )


class SourceRecordList(BaseModel):
    """Source records that contribute to one master record."""

    entity: BusinessEntity
    business_id: str
    members: list[SourceKey] = Field(description="Read Source Records by Master Record (p. 70).")
    records: list[SourceRecord] = Field(description="Read Source Record per member (p. 80).")
    not_read: list[SourceKey] = Field(
        default_factory=list, description="Members not read (over the cap, or a read failed)."
    )
    note: str = ""
    system_columns: list[EntityField] = Field(
        default_factory=list, description="xref _meta keys present in these records (SYSTEM)."
    )
    visibility: FieldVisibility = Field(default_factory=FieldVisibility)


class PatchOperation(StrEnum):
    ADD = "add"
    REPLACE = "replace"
    REMOVE = "remove"


PatchScalar = str | int | float | bool | None
# A root / row field value, a picklist {"Code": ...}, or new group rows (add).
PatchValue = (
    PatchScalar | dict[str, PatchScalar] | list[dict[str, PatchScalar | dict[str, PatchScalar]]]
)


class PatchOp(BaseModel):
    """One Update Source Record Field operation (pp. 88-90)."""

    op: PatchOperation
    path: str
    value: PatchValue = None
    old: FieldValue = Field(
        default=None, description="Shown inline on the Edit page (old -> new); not sent."
    )
    new: FieldValue = Field(
        default=None, description="Shown inline on the Edit page (old -> new); not sent."
    )
    verified: bool = Field(
        description="True when the path shape is in the reference; False = UNVERIFIED shape."
    )


class UpdateSourceRequest(BaseModel):
    original: NewRecord = Field(description="The record as loaded (Read Source Record).")
    updated: NewRecord = Field(description="The record as edited in the form.")
    dry_run: bool = Field(
        default=True, description="True: only build the operations, send nothing."
    )


class UpdateSourceResponse(BaseModel):
    entity: str
    source_system: str
    source_pkey: str
    ops: list[PatchOp]
    sent: bool
    approval_required: bool | None = None
    note: str


# ---------------------------------------------------------------------------------------------
# 0.9.12 Merge (M): merge 2-10 master records, then apply per-field winners on the survivor
# ---------------------------------------------------------------------------------------------


class MergePreviewRequest(BaseModel):
    business_ids: list[str] = Field(
        min_length=2, max_length=10, description="2-10 distinct master business ids."
    )


class MergeFieldRow(BaseModel):
    """One root field, with each record's current value (side by side on the Merge page)."""

    field: str
    label: str
    values: dict[str, FieldValue] = Field(description="Current value keyed by business id.")
    differs: bool = Field(description="True when the records do not all hold the same value.")
    follows: str | None = Field(
        default=None,
        description="clns_<x> rows: the field whose winner they follow (x); not picked alone.",
    )


class MergePreview(BaseModel):
    """Read-only: what the Merge page shows before anything is sent."""

    entity: str
    business_ids: list[str]
    records: list[EntityRecord]
    rows: list[MergeFieldRow]
    missing: list[str] = Field(
        default_factory=list, description="Ids with no active master record (merge refused)."
    )
    note: str = ""


class MergeRequest(BaseModel):
    business_ids: list[str] = Field(
        min_length=2, max_length=10, description="2-10 distinct master business ids to merge."
    )
    winners: dict[str, str] = Field(
        default_factory=dict,
        description="Root field name -> business id whose value wins on the surviving master. "
        "Only fields named here are overridden; clns_<field> follows its field's winner.",
    )
    override_source_system: str | None = Field(
        default=None,
        description="sourceSystem query parameter of the override PATCH; must be in [sources] "
        "allowed (default: [sources] default).",
    )


class MergeStepName(StrEnum):
    READ = "READ"  # Read Master Record by Business ID, each id (pp. 56-58)
    MERGE = "MERGE"  # Merge API (p. 106)
    OVERRIDE = "OVERRIDE"  # Update Master Record Field PATCH on the survivor (pp. 67-68)
    READ_BACK = "READ_BACK"  # Read Master Record of the survivor


class MergeStepStatus(StrEnum):
    OK = "OK"
    FAILED = "FAILED"
    SKIPPED = "SKIPPED"


class MergeStep(BaseModel):
    step: MergeStepName
    status: MergeStepStatus
    detail: str


class MergeOverride(BaseModel):
    """One field value set on the surviving master."""

    field: str
    winner_business_id: str
    value: FieldValue
    carried_with: str | None = Field(
        default=None, description="Set for clns_<x>: carried because x was picked."
    )
    final_value: FieldValue = Field(default=None, description="Value read back after the merge.")
    stuck: bool | None = Field(
        default=None, description="True when the read-back value equals the winner's value."
    )


class MergeResponse(BaseModel):
    entity: str
    business_ids: list[str]
    surviving_business_id: str | None
    approval_required: bool | None = Field(
        default=None, description="Merge API approvalRequired; true -> overrides not applied."
    )
    override_source_system: str | None
    overrides: list[MergeOverride]
    steps: list[MergeStep]
    before: list[EntityRecord] = Field(description="Each record as read before the merge.")
    after: EntityRecord | None = Field(default=None, description="The survivor, read back.")
    note: str


class UnmergeRequest(BaseModel):
    sources: list[SourceKey] = Field(
        min_length=1, max_length=10, description="Source records to take out (Records (S))."
    )
    allow_merge_back: bool = Field(
        default=False, description="false -> NEVER_MERGE (the API default); true -> MAY_MERGE."
    )


class UnmergeResponse(BaseModel):
    entity: str
    business_id: str
    sources: list[SourceKey]
    approval_required: bool | None = None
    note: str
