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


# One cell. Which member is used is driven by the field's declared FieldDataType.
FieldValue = str | int | float | bool | date | datetime | None


class BusinessEntitySummary(BaseModel):
    name: str = Field(description="Internal id (guid) of the business entity, e.g. c360.person.")
    label: str


class BusinessEntityList(BaseModel):
    entities: list[BusinessEntitySummary]
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
