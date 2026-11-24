"""Sheet layouts (from the idq-cli Oracle DDL, LDG_EXPORT_OCT_16.sql) and the typed workbook reader.

Pre-flight lives here: Home first, template version, sheets, columns, required keys and cell types.
"""

from dataclasses import dataclass, field
from datetime import date, datetime
from enum import StrEnum
from io import BytesIO

from openpyxl import load_workbook
from openpyxl.worksheet.worksheet import Worksheet

from app.testing.cases import UseCase, load_config
from app.testing.models import Group, Issue, PreflightReport

type Cell = str | int | date | None
type Row = dict[str, Cell]


class Col(StrEnum):
    INT = "INT"
    TEXT = "TEXT"
    DATE = "DATE"


@dataclass(frozen=True)
class SheetSpec:
    name: str
    columns: tuple[tuple[str, Col], ...]
    required: tuple[str, ...]
    yes_no: tuple[str, ...] = ()

    @property
    def names(self) -> list[str]:
        return [c for c, _ in self.columns]


T, N, D = Col.TEXT, Col.INT, Col.DATE
AUDIT = (("CREATEDDATE", D), ("CREATEDBYID", T), ("UPDATEDDATE", D), ("UPDATEDBYID", T))
INACTIVE = (("ACTIVE", N), ("INACTIVEDATE", D), ("INACTIVEBYID", T))

CLIENTS = SheetSpec(
    "CLIENTS",
    (
        ("ID", N),
        ("CLIENTCODE", T),
        ("SEXID", N),
        *AUDIT,
        *INACTIVE,
        ("ZIP", T),
        ("CONTRACTORID", N),
        ("REFERENCEID", N),
        ("MIDDLENAME", T),
        ("FIRSTNAME", T),
        ("LASTNAME", T),
        ("DATASOURCE", T),
        ("ETL_LOAD_DATE", D),
    ),
    ("ID", "CLIENTCODE"),
)
FYCLIENTS = SheetSpec(
    "FYCLIENTS",
    (
        ("ID", N),
        ("FY", N),
        ("CONTRACTID", N),
        ("CLIENTID", N),
        *AUDIT,
        *INACTIVE,
        ("REFERENCEID", N),
        ("ETL_LOAD_DATE", D),
    ),
    ("ID", "CLIENTID"),
)
DEMOGRAPHICS = SheetSpec(
    "DEMOGRAPHICS",
    (
        ("ID", N),
        ("YEAR", N),
        ("MONTH", N),
        ("FYCLIENTID", N),
        ("ZIP", T),
        ("SEXID", N),
        ("RETURNINGCLIENTID", N),
        ("MARITALSTATUSID", N),
        ("CLIENTTYPEID", N),
        ("HEALTHREGION", T),
        ("COUNTYID", N),
        ("GESTAGEATENROLLMENT", T),
        ("RACEETHNICITYID", N),
        ("NBREXISTINGCHILDREN", N),
        ("EDUCATIONLEVELID", N),
        ("SUBMISSIONID", N),
        *AUDIT,
        *INACTIVE,
        ("DATASOURCE", T),
        ("AGEATSERVICE", N),
        ("REFERENCEID", N),
        ("MEDICAIDID", T),
        ("EMPLOYMENTSTATUSID", N),
        ("INCOMELEVELID", N),
        ("FIRSTNAME", T),
        ("LASTNAME", T),
        ("MIDDLENAME", T),
        ("UPLOADEDSUBMISSIONID", N),
        ("MILITARYMEMBERID", N),
        ("DOB", D),
        ("PHONE", T),
        ("ETL_LOAD_DATE", D),
    ),
    ("ID", "YEAR", "MONTH", "FYCLIENTID"),
)
SUBMISSIONS = SheetSpec(
    "SUBMISSIONS",
    (
        ("ID", N),
        ("CONTRACTID", N),
        ("REPORTFORDATE", D),
        ("SUBMITDATE", D),
        ("ISRESET", N),
        ("RESETBYID", T),
        ("CONCURREDBYID", T),
        ("CONCURREDDATE", D),
        ("STATUSCODEID", N),
        ("FILEUPLOADTIMESTAMP", D),
        *AUDIT,
        *INACTIVE,
        ("PROCESSSTATUSID", N),
        ("ETL_LOAD_DATE", D),
    ),
    ("ID",),
)
MDM_RECORDS = SheetSpec(
    "MDM_RECORDS",
    (
        ("CLIENTCODE", T),
        ("SOURCE_SYSTEM", T),
        ("FIRST_NAME", T),
        ("LAST_NAME", T),
        ("DOB", D),
        ("PH_NUM", T),
        ("MASTER_GROUP", T),
        ("INDEXED", T),
        ("SOFT_DELETED", T),
    ),
    ("CLIENTCODE",),
    ("INDEXED", "SOFT_DELETED"),
)

TYPED_EXPECTED = {"DOB": D, "ACTIVE": N}


def expected_spec() -> SheetSpec:
    cols = load_config().expected_sheet.columns
    return SheetSpec(
        "Expected",
        tuple((c, TYPED_EXPECTED.get(c, T)) for c in cols),
        ("CLIENTCODE", "EXPECT_IN_MDM"),
        ("EXPECT_IN_MDM",),
    )


def expected_phones_spec() -> SheetSpec:
    cols = load_config().expected_sheet.phone_columns
    return SheetSpec("ExpectedPhones", tuple((c, T) for c in cols), ("CLIENTCODE", "PH_NUM"))


def group_sheets(group: Group) -> list[SheetSpec]:
    match group:
        case Group.TTF:
            return [
                CLIENTS,
                FYCLIENTS,
                DEMOGRAPHICS,
                SUBMISSIONS,
                expected_spec(),
                expected_phones_spec(),
            ]
        case Group.MDM:
            return [MDM_RECORDS, expected_spec()]


HOME = "Home"
HOME_KEYS = ("Test name", "Use case id", "Source", "Template version")


@dataclass
class Workbook:
    template_version: str | None
    sheets: dict[str, list[Row]] = field(default_factory=dict)


def _cell(raw: object, col: Col) -> Cell:
    if raw is None or (isinstance(raw, str) and not raw.strip()):
        return None
    match col, raw:
        case Col.INT, bool():
            raise ValueError("not a number")
        case Col.INT, int():
            return raw
        case Col.INT, float() if raw.is_integer():
            return int(raw)
        case Col.INT, str():
            return int(raw.strip())
        case Col.DATE, datetime():
            return raw.date()
        case Col.DATE, date():
            return raw
        case Col.DATE, str():
            return datetime.fromisoformat(raw.strip()).date()
        case Col.TEXT, float() if raw.is_integer():
            return str(int(raw))
        case Col.TEXT, datetime():
            return raw.date().isoformat()
        case Col.TEXT, int() | str() | date():
            return str(raw).strip()
    raise ValueError(f"not a {col.value.lower()}")


def _home_version(ws: Worksheet) -> str | None:
    for key, value, *_ in ws.iter_rows(min_row=1, max_col=2, values_only=True):
        if key == "Template version" and value is not None:
            return str(value).strip()
    return None


def _read_sheet(ws: Worksheet, spec: SheetSpec, issues: list[Issue]) -> list[Row]:
    rows = list(ws.iter_rows(values_only=True))
    header = [str(h).strip() if h is not None else "" for h in (rows[0] if rows else ())]
    missing = [c for c in spec.names if c not in header]
    if missing:
        issues.append(Issue(sheet=spec.name, message=f"missing columns: {', '.join(missing)}"))
        return []
    out: list[Row] = []
    for n, values in enumerate(rows[1:], start=2):
        if all(v is None or (isinstance(v, str) and not v.strip()) for v in values):
            continue
        row: Row = {}
        for name, col in spec.columns:
            raw = values[header.index(name)] if header.index(name) < len(values) else None
            try:
                row[name] = _cell(raw, col)
            except ValueError as exc:
                issues.append(Issue(sheet=spec.name, row=n, column=name, message=str(exc)))
                row[name] = None
        for name in spec.required:
            if row[name] is None:
                issues.append(Issue(sheet=spec.name, row=n, column=name, message="required"))
        for name in spec.yes_no:
            if row[name] not in (None, "Y", "N"):
                issues.append(Issue(sheet=spec.name, row=n, column=name, message="Y or N"))
        out.append(row)
    return out


def _duplicates(spec: SheetSpec, rows: list[Row], issues: list[Issue]) -> None:
    key = spec.required[0]
    seen: set[Cell] = set()
    for row in rows:
        if spec.name != "ExpectedPhones" and row[key] is not None and row[key] in seen:
            issues.append(Issue(sheet=spec.name, column=key, message=f"duplicate {row[key]}"))
        seen.add(row[key])


def read_workbook(data: bytes, case: UseCase) -> tuple[Workbook, PreflightReport]:
    issues: list[Issue] = []
    try:
        wb = load_workbook(BytesIO(data), read_only=True, data_only=True)
    except Exception as exc:  # noqa: BLE001 - any unreadable upload is a pre-flight issue
        issue = Issue(sheet="-", message=f"not an .xlsx workbook ({type(exc).__name__})")
        return Workbook(None), PreflightReport(
            ok=False, template_version=None, rows_per_sheet={}, issues=[issue]
        )
    names = list(wb.sheetnames)
    version = None
    if not names or names[0] != HOME:
        issues.append(Issue(sheet=HOME, message="Home must be the first sheet"))
    if HOME in names:
        version = _home_version(wb[HOME])
    if version != case.template_version:
        issues.append(
            Issue(
                sheet=HOME,
                message=f"template version {version} does not match {case.template_version}",
            )
        )
    book = Workbook(version)
    for spec in group_sheets(case.group):
        if spec.name not in names:
            issues.append(Issue(sheet=spec.name, message="sheet missing"))
            continue
        book.sheets[spec.name] = _read_sheet(wb[spec.name], spec, issues)
        _duplicates(spec, book.sheets[spec.name], issues)
    wb.close()
    if "Expected" in book.sheets and not book.sheets["Expected"]:
        issues.append(Issue(sheet="Expected", message="no rows: nothing to compare against"))
    report = PreflightReport(
        ok=not issues,
        template_version=version,
        rows_per_sheet={k: len(v) for k, v in book.sheets.items()},
        issues=issues,
    )
    return book, report
