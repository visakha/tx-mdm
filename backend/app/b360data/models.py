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


class EntityField(BaseModel):
    name: str
    label: str
    data_type: FieldDataType
    raw_type: str = Field(description="Type as IDMC sent it (eClass suffix), kept for UNKNOWN.")
    searchable: bool
    mandatory: bool


class FieldGroup(BaseModel):
    name: str
    label: str
    cardinality: Cardinality
    fields: list[EntityField]


class BusinessEntity(BaseModel):
    name: str
    label: str
    fields: list[EntityField]
    field_groups: list[FieldGroup]


class FieldGroupRows(BaseModel):
    group: str = Field(description="FieldGroup.name")
    rows: list[dict[str, FieldValue]] = Field(description="One map per row, keyed by field name.")


class EntityRecord(BaseModel):
    business_id: str
    values: dict[str, FieldValue] = Field(description="Top-level fields, keyed by field name.")
    groups: list[FieldGroupRows]


class RecordPage(BaseModel):
    entity: BusinessEntity
    hits: int | None
    records: list[EntityRecord]
    unknown_keys: list[str] = Field(
        description="Record keys the entity metadata did not describe (listed, never guessed)."
    )


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


class FormField(BaseModel):
    name: str
    label: str
    data_type: FieldDataType
    input: FormInput
    required: bool = Field(description="True when the metadata marks the field mandatory.")


class FormSchema(BaseModel):
    """The entity's root-field form, built from a Pydantic model created from the metadata."""

    entity: str
    label: str
    model_name: str = Field(
        description="Name of the dynamic Pydantic model (pydantic.create_model)."
    )
    fields: list[FormField]
    skipped_groups: list[str] = Field(
        description="Field groups not offered in the form yet (root fields only in 0.9.8)."
    )
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
