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
