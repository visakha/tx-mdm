"""Test rows for the Add records tab, made with Faker in the backend. No IDMC call.

Vamsi (voice, 2026-11-23 01:06 CST): "the number of test data that needs to be generated ...
use the data faker to go ahead and generate the test data."

Rules (by field name, then by data type), one place:
  - first/last/middle/full name, email, phone, city, postal code, address -> matching Faker
    provider (en_US).
  - clns_<x>  ("cleansed"): the row's own <x> value, upper-cased, letters and digits only.
  - ffr_<x>   ("fuzzy-friendly"): the row's own <x> value, lower-cased, letters and digits only.
    Chosen by the builder (2026-11-23); Vamsi has not said what ffr means. Change it here.
  - anything else: by FieldDataType (word / number / decimal / true-false / date / date-time).
Rows go through the entity's dynamic Pydantic model (app.b360data.forms) before they are returned.
"""

import re
from datetime import datetime

import faker as faker_pkg
from faker import Faker

from app.b360data import forms
from app.b360data.models import (
    BusinessEntity,
    EntityField,
    FieldDataType,
    FieldValue,
    GeneratedFieldRule,
    GeneratedRows,
    NewRecord,
)

_NON_ALNUM = re.compile(r"[^A-Za-z0-9]")
_DERIVED = (
    ("clns_", "cleansed: upper-case, letters and digits only"),
    ("ffr_", "fuzzy-friendly: lower-case, letters and digits only"),
)

# name hint (substring of the lower-cased field name) -> (Faker call, plain words)
_HINTS: tuple[tuple[str, str, str], ...] = (
    ("first", "first_name", "Faker first_name()"),
    ("mid", "first_name", "Faker first_name() (as a middle name)"),
    ("last", "last_name", "Faker last_name()"),
    ("full", "name", "Faker name()"),
    ("email", "email", "Faker email()"),
    ("phone", "phone_number", "Faker phone_number()"),
    ("city", "city", "Faker city()"),
    ("postal", "postcode", "Faker postcode()"),
    ("zip", "postcode", "Faker postcode()"),
    ("address", "street_address", "Faker street_address()"),
)

_BY_TYPE: dict[FieldDataType, str] = {
    FieldDataType.INTEGER: "Faker random_int(1, 1000)",
    FieldDataType.DOUBLE: "Faker pyfloat(2 decimals, 0-1000)",
    FieldDataType.DECIMAL: "Faker pyfloat(2 decimals, 0-1000)",
    FieldDataType.BOOLEAN: "Faker pybool()",
    FieldDataType.DATE: "Faker date_of_birth() if the name has 'birth', else date_this_decade()",
    FieldDataType.DATETIME: "Faker date_time_this_year()",
}

FAKER_VERSION: str = str(getattr(faker_pkg, "VERSION", "unknown"))


def make_source_pkey(stamp: datetime, n: int) -> str:
    """Default sourcePKey: TXMDM-<yyyymmddHHMMSS>-<n>, readable and unique per request."""
    return f"TXMDM-{stamp.strftime('%Y%m%d%H%M%S')}-{n}"


def _derived(name: str) -> tuple[str, str] | None:
    lowered = name.lower()
    for prefix, words in _DERIVED:
        if lowered.startswith(prefix) and len(name) > len(prefix):
            return name[len(prefix) :], words
    return None


def _hint(name: str) -> tuple[str, str] | None:
    lowered = name.lower()
    for needle, call, words in _HINTS:
        if needle in lowered:
            return call, words
    return None


def rule_for(field: EntityField) -> str:
    derived = _derived(field.name)
    if derived is not None:
        return f"this row's {derived[0]}, {derived[1]}"
    hint = _hint(field.name)
    if hint is not None and field.data_type in (FieldDataType.STRING, FieldDataType.UNKNOWN):
        return hint[1]
    return _BY_TYPE.get(field.data_type, "Faker word()")


def _fresh(fake: Faker, field: EntityField) -> FieldValue:
    hint = _hint(field.name)
    match field.data_type:
        case FieldDataType.INTEGER:
            return int(fake.random_int(1, 1000))
        case FieldDataType.DOUBLE | FieldDataType.DECIMAL:
            return float(fake.pyfloat(right_digits=2, min_value=0, max_value=1000))
        case FieldDataType.BOOLEAN:
            return bool(fake.pybool())
        case FieldDataType.DATE:
            return (
                fake.date_of_birth() if "birth" in field.name.lower() else fake.date_this_decade()
            )
        case FieldDataType.DATETIME:
            return fake.date_time_this_year()
        case _:
            return str(getattr(fake, hint[0])()) if hint is not None else str(fake.word())


def _cleanse(value: FieldValue, upper: bool) -> str:
    text = _NON_ALNUM.sub("", str(value))
    return text.upper() if upper else text.lower()


def generate(
    entity: BusinessEntity, count: int, seed: int | None, stamp: datetime
) -> GeneratedRows:
    fake = Faker("en_US")
    if seed is not None:
        fake.seed_instance(seed)
    by_name = {f.name.lower(): f for f in entity.fields}
    rows: list[NewRecord] = []
    for n in range(1, count + 1):
        values: dict[str, FieldValue] = {}
        # plain fields first, so clns_/ffr_ copies can use the row's own value
        for field in entity.fields:
            if _derived(field.name) is None:
                values[field.name] = _fresh(fake, field)
        for field in entity.fields:
            derived = _derived(field.name)
            if derived is None:
                continue
            base_field = by_name.get(derived[0].lower())
            base = values.get(base_field.name) if base_field else None
            if base is None:
                base = _fresh(fake, field)
            values[field.name] = _cleanse(base, upper=field.name.lower().startswith("clns_"))
        cleaned = forms.validate_values(entity, values, n - 1)
        rows.append(NewRecord(source_pkey=make_source_pkey(stamp, n), values=cleaned))
    return GeneratedRows(
        entity=entity.name,
        rows=rows,
        rules=[GeneratedFieldRule(field=f.name, rule=rule_for(f)) for f in entity.fields],
        faker_version=FAKER_VERSION,
        note="Preview only: nothing was sent to IDMC. Edit or remove rows, then Send to B360.",
    )
