"""Generated template data, shaped to the use case, with Expected pre-filled to match.

Names and DOBs are unique per member index, so only the pairs a shape builds on purpose can merge.
"""

from dataclasses import dataclass, field
from datetime import date, timedelta

from app.testing.cases import UseCase, load_config
from app.testing.models import Group
from app.testing.sheets import Row, SheetSpec, group_sheets

FIRSTS = (
    "ALICE",
    "BRIAN",
    "CARMEN",
    "DAVID",
    "ELENA",
    "FRANK",
    "GRACE",
    "HECTOR",
    "IRENE",
    "JAMES",
)
LASTS = ("ADAMS", "BAKER", "CRUZ", "DIAZ", "EVANS", "FLORES", "GARCIA", "HAYES", "IBARRA", "JONES")
MIDDLES = ("A", "B", "C", "D", "E")
LATEST = (2026, 10)


@dataclass
class Demo:
    year: int
    month: int
    first: str
    last: str | None
    dob: date | None
    phone: str | None


@dataclass
class Member:
    index: int
    first: str
    last: str
    dob: date
    active: int = 1
    orphan: bool = False
    demos: list[Demo] = field(default_factory=list)
    group: str = ""
    master_group: str = ""
    indexed: str = "Y"
    soft_deleted: str = "N"
    in_mdm: bool = True
    note: str = ""

    @property
    def code(self) -> str:
        return f"CL-{self.index + 1:04d}"


def _person(i: int) -> tuple[str, str, date]:
    last = LASTS[i % len(LASTS)] + ("" if i < len(LASTS) else str(i // len(LASTS)))
    return FIRSTS[(i * 3) % len(FIRSTS)], last, date(1975, 1, 1) + timedelta(days=97 * i + 11)


def _phone(i: int, k: int = 0) -> str:
    return f"512{5550000 + i * 7 + k:07d}"


def _single(i: int, phone: str | None = None) -> Member:
    first, last, dob = _person(i)
    m = Member(i, first, last, dob, group=f"G{i + 1}")
    m.demos = [Demo(*LATEST, first, last, dob, _phone(i) if phone is None else phone)]
    return m


def _members(case: UseCase, n: int) -> list[Member]:
    match case.mock.shape:
        case "new_member" | "mdm_index":
            ms = [_single(i) for i in range(n)]
            if case.mock.shape == "mdm_index":
                for m in ms:
                    m.indexed = "N"
            return ms
        case "update":
            ms = [_single(i) for i in range(n)]
            for m in ms:
                old = Demo(2026, 9, m.first, m.last, m.dob, _phone(m.index, 5))
                m.last = m.last + "SON"
                m.demos = [old, Demo(*LATEST, m.first, m.last, m.dob, _phone(m.index))]
            return ms
        case "duplicate_pairs" | "not_duplicate_pairs" | "mdm_match_merge" | "mdm_reset":
            ms = [_single(i) for i in range(n + n % 2)]
            for a, b in zip(ms[::2], ms[1::2], strict=True):
                b.first, b.last = a.first, a.last
                if case.mock.shape != "not_duplicate_pairs":
                    b.dob, b.group = a.dob, a.group
                b.demos = [Demo(*LATEST, b.first, b.last, b.dob, _phone(b.index))]
                if case.mock.shape == "mdm_reset":
                    a.master_group = b.master_group = a.group
                    b.group = f"G{b.index + 1}"
            return ms
        case "inactive":
            ms = [_single(i) for i in range(n)]
            for m in ms[1::2]:
                m.active = 0
            return ms
        case "missing_field" | "orphan":
            ms = [_single(i) for i in range(max(n, 2))]
            for k, m in enumerate(ms[1:]):
                m.in_mdm = False
                if case.mock.shape == "orphan":
                    m.orphan, m.note = True, "orphan DEMOGRAPHICS row: rejected at staging"
                elif k % 2 == 0:
                    m.demos[0].dob, m.note = None, "missing DOB: rejected at staging"
                else:
                    m.demos[0].last, m.note = None, "missing LASTNAME: rejected at staging"
            return ms
        case "multi_month":
            ms = [_single(i) for i in range(n)]
            for m in ms:
                m.demos = [
                    Demo(2026, month, m.first, f"{m.last}{tag}", m.dob, _phone(m.index, k))
                    for k, (month, tag) in enumerate(((8, "X"), (9, "Y"), (10, "")))
                ]
            return ms
        case "junk_phone":
            junk = [v.ph_num for v in case.mock.phone_validation] or ["2222222222"]
            return [_single(0)] + [_single(i, junk[(i - 1) % len(junk)]) for i in range(1, n)]
        case "no_phone":
            ms = [_single(i) for i in range(n)]
            for m in ms:
                m.demos[0].phone = None
            return ms
        case "multi_phone":
            ms = [_single(i) for i in range(n)]
            for m in ms:
                m.demos = [
                    Demo(*LATEST, m.first, m.last, m.dob, _phone(m.index, k))
                    for k in range(2 + m.index % 2)
                ]
            return ms
        case "mdm_purge":
            ms = [_single(i) for i in range(n)]
            for m in ms[1::2]:
                m.soft_deleted, m.in_mdm, m.note = "Y", False, "soft-deleted: purged"
            return ms
    raise LookupError(f"unknown mock shape {case.mock.shape}")


def _blank(spec: SheetSpec) -> Row:
    return dict.fromkeys(spec.names)


def _put(spec: SheetSpec, values: Row) -> Row:
    row = _blank(spec)
    row.update({k: v for k, v in values.items() if k in row})
    return row


def _phones(case: UseCase, m: Member) -> list[tuple[str, str, str, str]]:
    cfg = load_config().mock
    verdicts = {v.ph_num: v for v in case.mock.phone_validation}
    latest = max((d.year, d.month) for d in m.demos)
    nums = [d.phone for d in m.demos if (d.year, d.month) == latest and d.phone]
    out = []
    for k, num in enumerate(dict.fromkeys(nums)):
        v = verdicts.get(num)
        typ = cfg.phone_types[k % len(cfg.phone_types)]
        out.append((num, typ, v.state if v else "PASSED", v.reason if v else ""))
    return out


def _expected(case: UseCase, m: Member) -> tuple[Row, list[Row]]:
    if not m.in_mdm:
        return {"CLIENTCODE": m.code, "EXPECT_IN_MDM": "N", "NOTES": m.note}, []
    phones = _phones(case, m) if case.group == Group.TTF else []
    failed = [p for p in phones if p[2] == "FAILED"]
    row: Row = {
        "CLIENTCODE": m.code,
        "EXPECT_IN_MDM": "Y",
        "EXPECT_MASTER_GROUP": m.group,
        "FIRST_NAME": m.first,
        "LAST_NAME": m.last,
        "DOB": m.dob,
        "VALIDATION_STATE": "FAILED" if failed else "PASSED",
        "VALIDATION_REASON": failed[0][3] if failed else None,
        "NOTES": m.note or None,
    }
    if case.group == Group.TTF:
        row["ACTIVE"] = m.active
    cc = load_config().mock.country_code
    phone_rows: list[Row] = [
        {
            "CLIENTCODE": m.code,
            "PH_NUM": num,
            "PH_TYP": typ,
            "CNTRY_CD": cc,
            "VALIDATION_STATE": state,
            "VALIDATION_REASON": reason or None,
        }
        for num, typ, state, reason in phones
    ]
    return row, phone_rows


def _ttf_rows(m: Member, demo_id: int) -> dict[str, list[Row]]:
    client_id, fy_id = 1000 + m.index, 2000 + m.index
    client: Row = {
        "ID": client_id,
        "CLIENTCODE": m.code,
        "SEXID": 1,
        "ACTIVE": m.active,
        "INACTIVEDATE": date(2026, 10, 15) if m.active == 0 else None,
        "ZIP": "78701",
        "FIRSTNAME": m.first,
        "LASTNAME": m.last,
        "MIDDLENAME": MIDDLES[m.index % len(MIDDLES)],
        "DATASOURCE": "TTF",
    }
    fy: Row = {"ID": fy_id, "FY": 2026, "CONTRACTID": 77, "CLIENTID": client_id, "ACTIVE": 1}
    demos: list[Row] = [
        {
            "ID": demo_id + k,
            "YEAR": d.year,
            "MONTH": d.month,
            "SUBMISSIONID": 4000,
            "FYCLIENTID": 90000 + m.index if m.orphan else fy_id,
            "FIRSTNAME": d.first,
            "LASTNAME": d.last,
            "MIDDLENAME": client["MIDDLENAME"],
            "DOB": d.dob,
            "PHONE": d.phone,
            "ACTIVE": 1,
            "ZIP": "78701",
            "DATASOURCE": "TTF",
        }
        for k, d in enumerate(m.demos)
    ]
    return {"CLIENTS": [client], "FYCLIENTS": [fy], "DEMOGRAPHICS": demos}


def generate(case: UseCase, rows: int) -> dict[str, list[Row]]:
    specs = {s.name: s for s in group_sheets(case.group)}
    out: dict[str, list[Row]] = {name: [] for name in specs}
    demo_id = 3000
    for m in _members(case, max(rows, 1)):
        if case.group == Group.TTF:
            for sheet, sheet_rows in _ttf_rows(m, demo_id).items():
                out[sheet] += [_put(specs[sheet], r) for r in sheet_rows]
            demo_id += len(m.demos)
        else:
            out["MDM_RECORDS"].append(
                _put(
                    specs["MDM_RECORDS"],
                    {
                        "CLIENTCODE": m.code,
                        "SOURCE_SYSTEM": load_config().pipeline[case.group].source,
                        "FIRST_NAME": m.first,
                        "LAST_NAME": m.last,
                        "DOB": m.dob,
                        "PH_NUM": _phone(m.index),
                        "MASTER_GROUP": m.master_group or None,
                        "INDEXED": m.indexed,
                        "SOFT_DELETED": m.soft_deleted,
                    },
                )
            )
        expected, phones = _expected(case, m)
        out["Expected"].append(_put(specs["Expected"], expected))
        if "ExpectedPhones" in specs:
            out["ExpectedPhones"] += [_put(specs["ExpectedPhones"], p) for p in phones]
    if case.group == Group.TTF:
        out["SUBMISSIONS"].append(
            _put(
                specs["SUBMISSIONS"],
                {
                    "ID": 4000,
                    "CONTRACTID": 77,
                    "REPORTFORDATE": date(2026, 10, 1),
                    "SUBMITDATE": date(2026, 11, 5),
                    "STATUSCODEID": 1,
                    "ACTIVE": 1,
                },
            )
        )
    return out
