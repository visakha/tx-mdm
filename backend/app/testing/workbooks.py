"""Write the template and result workbooks (.xlsx). Home is always the first sheet."""

from collections.abc import Sequence
from datetime import date
from io import BytesIO

from openpyxl import Workbook as XlsxBook
from openpyxl.styles import Font
from openpyxl.worksheet.worksheet import Worksheet

from app.testing.cases import UseCase
from app.testing.models import Comparison, RunView, TemplateMode
from app.testing.sheets import HOME, Cell, Row, group_sheets

BOLD = Font(bold=True)
HOW_TO = (
    "Fill one row per landing-table row. Keep the header row and the sheet names as they are.",
    "Expected: one row per CLIENTCODE. Blank cell = not checked. EXPECT_IN_MDM is Y or N.",
    "Rows sharing EXPECT_MASTER_GROUP must end on one master; different values = different.",
    "ExpectedPhones (TTF): one row per phone. A member with no rows here = expect zero phones.",
    "Clean up old test data yourself before re-running; the runner never deletes anything.",
)


def _home(ws: Worksheet, case: UseCase, extra: Sequence[tuple[str, str]]) -> None:
    ws.title = HOME
    head = [
        ("Test name", f"{case.group.value} {case.use_case} - {case.title}"),
        ("Use case id", case.use_case),
        ("Source", case.group.value),
        ("Template version", case.template_version),
        *extra,
    ]
    for key, value in head:
        ws.append([key, value])
        ws.cell(ws.max_row, 1).font = BOLD
    ws.append([])
    ws.append(["How to fill"])
    ws.cell(ws.max_row, 1).font = BOLD
    for line in HOW_TO:
        ws.append(["", line])
    for block in case.home:
        ws.append([])
        ws.append([f"[{block.label}]"])
        ws.cell(ws.max_row, 1).font = BOLD
        for line in block.lines:
            ws.append(["", line])
    ws.column_dimensions["A"].width = 22
    ws.column_dimensions["B"].width = 100


def _table(book: XlsxBook, title: str, header: Sequence[str], rows: Sequence[Row]) -> None:
    ws = book.create_sheet(title)
    ws.append(list(header))
    for cell in ws[1]:
        cell.font = BOLD
    for row in rows:
        ws.append([row.get(c) for c in header])
    for col in ws.iter_cols(min_row=2):
        for cell in col:
            if isinstance(cell.value, date):
                cell.number_format = "yyyy-mm-dd"
    for idx, name in enumerate(header, start=1):
        ws.column_dimensions[ws.cell(1, idx).column_letter].width = max(12, len(name) + 2)


def _save(book: XlsxBook) -> bytes:
    buf = BytesIO()
    book.save(buf)
    return buf.getvalue()


def _first(book: XlsxBook) -> Worksheet:
    sheet = book.active
    assert isinstance(sheet, Worksheet)
    return sheet


def template(case: UseCase, mode: TemplateMode, data: dict[str, list[Row]]) -> bytes:
    book = XlsxBook()
    rows = sum(len(v) for v in data.values())
    _home(_first(book), case, [("Template mode", mode.value), ("Rows generated", str(rows))])
    for spec in group_sheets(case.group):
        _table(book, spec.name, spec.names, data.get(spec.name, []))
    return _save(book)


def _text(value: Cell) -> str:
    return "" if value is None else str(value)


def result(
    case: UseCase,
    run: RunView,
    comparison: Comparison | None,
    actual: dict[str, list[Row]],
    uploaded: dict[str, list[Row]],
) -> bytes:
    book = XlsxBook()
    summary = [
        ("Run id", run.run_id),
        ("Path", run.path.value),
        ("Run state", run.state.value),
        ("Checks", str(comparison.checked) if comparison else "-"),
        ("Failed checks", str(comparison.failed) if comparison else "-"),
    ]
    _home(_first(book), case, summary)
    hs = [h.model_dump(mode="json") for h in run.handshakes]
    _table(book, "Handshakes", ["title", "answer", "source", "at", "verified"], hs)
    steps: list[Row] = [
        {
            "step": s.step.value,
            "status": s.status.value,
            "rows_in": s.rows_in,
            "rows_out": s.rows_out,
            "message": s.message,
            "errors": "; ".join(s.errors),
        }
        for s in run.steps
    ]
    _table(book, "Steps", ["step", "status", "rows_in", "rows_out", "message", "errors"], steps)
    cmp_rows: list[Row] = [
        {
            "check": r.check,
            "clientcode": r.clientcode,
            "field": r.field,
            "expected": r.expected,
            "actual": r.actual,
            "result": "PASS" if r.passed else "FAIL",
        }
        for r in (comparison.rows if comparison else [])
    ]
    header = ["check", "clientcode", "field", "expected", "actual", "result"]
    _table(book, "Comparison", header, cmp_rows)
    for title, rows in [*actual.items(), *uploaded.items()]:
        cols = list(rows[0]) if rows else ["(no rows)"]
        _table(book, title, cols, [{k: _text(v) for k, v in r.items()} for r in rows])
    return _save(book)
