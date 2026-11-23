"""Test rows for the Add records tab, made with Faker in the backend. No IDMC call.

Vamsi (voice, 2026-11-23 01:06 CST): "the number of test data that needs to be generated ...
use the data faker to go ahead and generate the test data."

Rules (by field name, then by data type), one place:
  - first/last/middle/full name, email, phone, city, postal code, address -> matching Faker
    provider (en_US).
  - clns_<x>  ("cleansed"): the row's own <x> value, upper-cased, letters and digits only.
  - ffr_<x>   = FREEFORM REASON (Vamsi 2026-11-23 02:01 CST): free-text reasoning for when data
    validation of <x> fails. Not a name variant, so generated rows leave every ffr_* EMPTY.
  - INTEGER phone number (name has "phone" or starts "ph_"): a 10-digit number;
    INTEGER country code (name has "cntry" / "country"): 1.
  - PICKLIST: one of the Codes IDMC itself returned for that field (forms.PICKLIST_NOTE); none
    known -> left empty. Codes are never invented.
  - anything else: by FieldDataType (word / number / decimal / true-false / date / date-time).
  - 0.9.10 field groups (any group in the metadata): MANY -> 1-2 rows per record, ONE -> 1 row,
    each field by the same rules.
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
    NewGroupRow,
    NewGroupRows,
    NewRecord,
    PicklistSource,
)

_NON_ALNUM = re.compile(r"[^A-Za-z0-9]")
_DERIVED = (("clns_", "cleansed: upper-case, letters and digits only"),)
FREEFORM_REASON_PREFIX = "ffr_"
FREEFORM_REASON_RULE = (
    "left empty: ffr_ = freeform reason, free text for when validation of the field fails"
)


def _is_freeform_reason(name: str) -> bool:
    return name.lower().startswith(FREEFORM_REASON_PREFIX) and len(name) > len(
        FREEFORM_REASON_PREFIX
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


def _is_phone_number(name: str) -> bool:
    lowered = name.lower()
    return "phone" in lowered or lowered.startswith("ph_")


def _is_country_code(name: str) -> bool:
    lowered = name.lower()
    return "cntry" in lowered or "country" in lowered


def rule_for(
    field: EntityField,
    codes: list[str] | None = None,
    source: PicklistSource | None = None,
) -> str:
    if _is_freeform_reason(field.name):
        return FREEFORM_REASON_RULE
    if field.data_type in (FieldDataType.PICKLIST, FieldDataType.DEPENDENT_PICKLIST):
        rdm = field.lookup.rdm_entity if field.lookup else None
        if codes and source is PicklistSource.REFERENCE_360:
            return f"random Code from Reference 360 list {rdm}: " + ", ".join(codes)
        if codes and source is PicklistSource.REFERENCE_360_GUESSED:
            return (
                f"GUESS (metadata names no list; {rdm} matched by field name only): random "
                "Code from " + ", ".join(codes)
            )
        if codes:
            return "one of the Codes IDMC returned: " + ", ".join(codes)
        return "left empty: no documented call lists this picklist's values and none seen yet"
    if field.data_type is FieldDataType.INTEGER and _is_country_code(field.name):
        return "country code 1"
    if field.data_type is FieldDataType.INTEGER and _is_phone_number(field.name):
        return "Faker random 10-digit number"
    derived = _derived(field.name)
    if derived is not None:
        return f"this row's {derived[0]}, {derived[1]}"
    hint = _hint(field.name)
    if hint is not None and field.data_type in (FieldDataType.STRING, FieldDataType.UNKNOWN):
        return hint[1]
    return _BY_TYPE.get(field.data_type, "Faker word()")


def _fresh(fake: Faker, field: EntityField, codes: list[str] | None = None) -> FieldValue:
    value = _fresh_unbounded(fake, field, codes)
    if isinstance(value, str) and field.length is not None:
        return value[: field.length.max]
    return value


def _fresh_unbounded(fake: Faker, field: EntityField, codes: list[str] | None) -> FieldValue:
    hint = _hint(field.name)
    limit = field.length
    match field.data_type:
        case FieldDataType.PICKLIST | FieldDataType.DEPENDENT_PICKLIST:
            fitting = [c for c in codes or [] if limit is None or len(c) <= limit.max]
            return str(fake.random_element(fitting)) if fitting else None
        case FieldDataType.INTEGER if _is_country_code(field.name):
            return 1
        case FieldDataType.INTEGER if limit is not None and limit.exact:
            return int(fake.random_int(10 ** (limit.max - 1), 10**limit.max - 1))
        case FieldDataType.INTEGER if _is_phone_number(field.name):
            top = 9_999_999_999 if limit is None else min(9_999_999_999, 10**limit.max - 1)
            return int(fake.random_int(min(2_000_000_000, top), top))
        case FieldDataType.INTEGER:
            top = 1000 if limit is None else min(1000, 10**limit.max - 1)
            return int(fake.random_int(1, top))
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


def _row(
    fake: Faker, fields: list[EntityField], codes: dict[str, list[str]]
) -> dict[str, FieldValue]:
    """Plain fields first, so clns_ copies can use the row's own value. ffr_* stay empty."""
    by_name = {f.name.lower(): f for f in fields}
    values: dict[str, FieldValue] = {}
    for field in fields:
        if _is_freeform_reason(field.name):
            continue  # freeform reason: never generated
        if _derived(field.name) is None:
            values[field.name] = _fresh(fake, field, codes.get(field.name))
    for field in fields:
        derived = _derived(field.name)
        if derived is None:
            continue
        base_field = by_name.get(derived[0].lower())
        base = values.get(base_field.name) if base_field else None
        if base is None:
            base = _fresh(fake, field)
        values[field.name] = _cleanse(base, upper=True)
    return values


class GenerateBlockedError(ValueError):
    """Test rows cannot be generated without inventing data. Nothing was generated."""


def _blocking_picklists(fields: list[EntityField], codes: dict[str, list[str]]) -> list[str]:
    """Required picklist fields with no known codes (the generator never invents one)."""
    return [
        f.name
        for f in fields
        if f.mandatory
        and f.data_type in (FieldDataType.PICKLIST, FieldDataType.DEPENDENT_PICKLIST)
        and not codes.get(f.name)
    ]


def generate(
    entity: BusinessEntity,
    count: int,
    seed: int | None,
    stamp: datetime,
    lists: forms.Picklists | None = None,
) -> GeneratedRows:
    fake = Faker("en_US")
    if seed is not None:
        fake.seed_instance(seed)
    picks = lists or forms.Picklists()
    opts = picks.options

    def codes_for(group: str) -> dict[str, list[str]]:
        return {field: [o.code for o in found] for (g, field), found in opts.items() if g == group}

    root_codes = codes_for("")
    blocked_root = _blocking_picklists(entity.fields, root_codes)
    if blocked_root:
        raise GenerateBlockedError(
            f"Cannot generate {entity.name}: required picklist field(s) {', '.join(blocked_root)} "
            "have no known values (no documented call lists them), and the generator never "
            "invents codes. Use 'Type it', or make the field optional in the portal."
        )
    rows: list[NewRecord] = []
    for n in range(1, count + 1):
        values = _row(fake, entity.fields, root_codes)
        groups: list[NewGroupRows] = []
        for group in entity.field_groups:
            how_many = int(fake.random_int(1, 2)) if group.cardinality.value == "MANY" else 1
            group_codes = codes_for(group.name)
            if _blocking_picklists(group.fields, group_codes):
                groups.append(NewGroupRows(group=group.name, rows=[]))
                continue  # a required picklist has no known codes: skip the group, never invent
            groups.append(
                NewGroupRows(
                    group=group.name,
                    rows=[
                        NewGroupRow(values=_row(fake, group.fields, group_codes))
                        for _ in range(how_many)
                    ],
                )
            )
        cleaned = forms.validate_values(entity, values, n - 1)
        cleaned_groups = forms.validate_groups(entity, groups, n - 1)
        rows.append(
            NewRecord(source_pkey=make_source_pkey(stamp, n), values=cleaned, groups=cleaned_groups)
        )
    rules = [
        GeneratedFieldRule(
            field=f.name, rule=rule_for(f, root_codes.get(f.name), picks.sources.get(("", f.name)))
        )
        for f in entity.fields
    ]
    for group in entity.field_groups:
        group_codes = codes_for(group.name)
        how = "1-2 rows per record" if group.cardinality.value == "MANY" else "1 row"
        blocked = _blocking_picklists(group.fields, group_codes)
        if blocked:
            how = (
                f"group skipped: required picklist {', '.join(blocked)} has no known values; "
                "add rows by hand"
            )
        rules.extend(
            GeneratedFieldRule(
                field=f"{group.name}.{f.name}",
                rule=(
                    rule_for(f, group_codes.get(f.name), picks.sources.get((group.name, f.name)))
                    + f" ({how})"
                ),
            )
            for f in group.fields
        )
    return GeneratedRows(
        entity=entity.name,
        rows=rows,
        rules=rules,
        faker_version=FAKER_VERSION,
        note="Preview only: nothing was sent to IDMC. Edit or remove rows, then Send to B360.",
    )
