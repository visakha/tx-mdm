"""The mock path: SQLite stands in for the TTF source + egress tables, and an in-process fake MDM
plays ingress, match and merge, MDM jobs and egress. Every faked step can be scripted from the
use case's [mock] section (status SUCCESS / FAILED / SKIPPED + message).
"""

import sqlite3
from collections.abc import Iterator
from contextlib import contextmanager
from dataclasses import dataclass, field
from datetime import UTC, date, datetime
from pathlib import Path

from app.testing.cases import UseCase, load_config
from app.testing.models import Group, Step, StepStatus
from app.testing.sheets import Cell, Row, Workbook

TTF_SHEETS = ("CLIENTS", "FYCLIENTS", "DEMOGRAPHICS", "SUBMISSIONS")
XREF_COLS = (
    "CLIENTCODE",
    "SOURCE_SYSTEM",
    "FIRST_NAME",
    "LAST_NAME",
    "MIDDLE_NAME",
    "DOB",
    "ACTIVE",
    "VALIDATION_STATE",
    "VALIDATION_REASON",
    "MASTER_ID",
    "INDEXED",
    "SOFT_DELETED",
)
PHONE_COLS = (
    "CLIENTCODE",
    "CNTRY_CD",
    "PH_NUM",
    "PH_TYP",
    "NO_MRKT_CALLS",
    "VALIDATION_STATE",
    "VALIDATION_REASON",
)


@dataclass
class Outcome:
    status: StepStatus = StepStatus.SUCCESS
    rows_in: int | None = None
    rows_out: int | None = None
    message: str = ""
    errors: list[str] = field(default_factory=list)


def _sql(value: Cell) -> str | int | None:
    return value.isoformat() if isinstance(value, date) else value


def _q(column: str) -> str:
    return f'"{column}"'


def _txt(value: object) -> str:
    return "" if value is None else str(value)


class MockPipeline:
    def __init__(self, db_path: Path, case: UseCase) -> None:
        self.db_path = db_path
        self.case = case
        self.cfg = load_config()

    @contextmanager
    def _db(self) -> Iterator[sqlite3.Connection]:
        con = sqlite3.connect(self.db_path)
        con.row_factory = sqlite3.Row
        try:
            yield con
            con.commit()
        finally:
            con.close()

    def run(self, step: Step, book: Workbook) -> Outcome:
        script = self.case.mock.steps.get(step)
        if script is not None and script.status != StepStatus.SUCCESS:
            return Outcome(status=script.status, message=script.message or "scripted by [mock]")
        try:
            return self._step(step, book)
        except sqlite3.OperationalError as exc:  # an earlier step was skipped: its table is missing
            return Outcome(
                status=StepStatus.FAILED, message=f"no input (earlier step skipped?): {exc}"
            )

    def _step(self, step: Step, book: Workbook) -> Outcome:
        with self._db() as con:
            match step:
                case Step.LOAD:
                    return self._load(con, book)
                case Step.LDG:
                    return self._ldg(con)
                case Step.STG:
                    return self._stg(con)
                case Step.INGRESS:
                    return self._ingress(con)
                case Step.MATCH_MERGE:
                    return self._merge(con, self.case.mock.match_rule)
                case Step.MDM_JOB:
                    return self._mdm_job(con)
                case Step.EGRESS:
                    return self._egress(con)
                case Step.READ:
                    n = sum(len(v) for v in self.actual().values())
                    return Outcome(rows_out=n, message=f"read {n} rows (egress / MDM search)")
                case Step.COMPARE:
                    return Outcome()

    def _table(self, con: sqlite3.Connection, name: str, cols: tuple[str, ...] | list[str]) -> None:
        con.execute(f'DROP TABLE IF EXISTS "{name}"')
        con.execute(f'CREATE TABLE "{name}" ({", ".join(_q(c) for c in cols)})')

    def _insert(self, con: sqlite3.Connection, name: str, rows: list[Row]) -> None:
        if not rows:
            return
        cols = list(rows[0])
        marks = ", ".join("?" for _ in cols)
        sql = f'INSERT INTO "{name}" ({", ".join(_q(c) for c in cols)}) VALUES ({marks})'
        con.executemany(sql, [[_sql(r[c]) for c in cols] for r in rows])

    def _rows(self, con: sqlite3.Connection, sql: str) -> list[dict[str, object]]:
        return [dict(r) for r in con.execute(sql).fetchall()]

    def _load(self, con: sqlite3.Connection, book: Workbook) -> Outcome:
        if self.case.group == Group.MDM:
            return self._seed_mdm(con, book.sheets.get("MDM_RECORDS", []))
        total = 0
        for sheet, table in zip(TTF_SHEETS, self.cfg.source_db.tables, strict=True):
            rows = book.sheets.get(sheet, [])
            self._table(con, table, list(rows[0]) if rows else ["ID"])
            self._insert(con, table, rows)
            total += len(rows)
        return Outcome(rows_in=total, rows_out=total, message="loaded into SQLite (mock source)")

    def _ldg(self, con: sqlite3.Connection) -> Outcome:
        total = 0
        for sheet, table in zip(TTF_SHEETS, self.cfg.source_db.tables, strict=True):
            con.execute(f'DROP TABLE IF EXISTS "STG_TTF_D_{sheet}"')
            con.execute(f'CREATE TABLE "STG_TTF_D_{sheet}" AS SELECT * FROM "{table}"')
            total += con.execute(f'SELECT COUNT(*) FROM "{table}"').fetchone()[0]
        name = self.cfg.pipeline[Group.TTF].ldg_taskflow
        return Outcome(rows_in=total, rows_out=total, message=f"mock {name}: SUCCESS")

    def _stg(self, con: sqlite3.Connection) -> Outcome:
        clients = {r["ID"]: r for r in self._rows(con, 'SELECT * FROM "STG_TTF_D_CLIENTS"')}
        fys = {r["ID"]: r for r in self._rows(con, 'SELECT * FROM "STG_TTF_D_FYCLIENTS"')}
        demos = self._rows(con, 'SELECT * FROM "STG_TTF_D_DEMOGRAPHICS" ORDER BY "ID"')
        errors: list[str] = []
        per_client: dict[object, list[dict[str, object]]] = {}
        for d in demos:
            fy = fys.get(d["FYCLIENTID"])
            if fy is None or fy["CLIENTID"] not in clients:
                errors.append(f"DEMOGRAPHICS ID {d['ID']}: orphan (FYCLIENTID {d['FYCLIENTID']})")
                continue
            per_client.setdefault(fy["CLIENTID"], []).append(d)
        members: list[Row] = []
        phones: list[Row] = []
        for cid, client in clients.items():
            code = str(client["CLIENTCODE"])
            rows = per_client.get(cid, [])
            if not rows:
                errors.append(f"{code}: no valid DEMOGRAPHICS row, not sent to MDM")
                continue
            latest = max((int(_txt(r["YEAR"])), int(_txt(r["MONTH"]))) for r in rows)
            last_rows = [r for r in rows if (int(_txt(r["YEAR"])), int(_txt(r["MONTH"]))) == latest]
            top = last_rows[-1]
            missing = [c for c in ("FIRSTNAME", "LASTNAME", "DOB") if top[c] in (None, "")]
            if missing:
                errors.append(f"{code}: missing {', '.join(missing)}, rejected")
                continue
            members.append(
                {
                    "CLIENTCODE": code,
                    "FIRST_NAME": _txt(top["FIRSTNAME"]),
                    "LAST_NAME": _txt(top["LASTNAME"]),
                    "MIDDLE_NAME": _txt(top["MIDDLENAME"]),
                    "DOB": _txt(top["DOB"]),
                    "ACTIVE": int(_txt(client["ACTIVE"]) or "1"),
                }
            )
            nums = [_txt(r["PHONE"]) for r in last_rows if r["PHONE"] not in (None, "")]
            phones += [
                {"CLIENTCODE": code, "PH_NUM": num, "SEQ": k}
                for k, num in enumerate(dict.fromkeys(nums))
            ]
        self._table(con, "MOCK_STG_MEMBER", list(members[0]) if members else ["CLIENTCODE"])
        self._insert(con, "MOCK_STG_MEMBER", members)
        self._table(con, "MOCK_STG_PHONE", ["CLIENTCODE", "PH_NUM", "SEQ"])
        self._insert(con, "MOCK_STG_PHONE", phones)
        name = self.cfg.pipeline[Group.TTF].stg_taskflow
        return Outcome(
            rows_in=len(demos),
            rows_out=len(members),
            message=f"mock {name}: {len(members)} members, {len(errors)} rejected",
            errors=errors,
        )

    def _mdm_tables(self, con: sqlite3.Connection) -> None:
        self._table(con, "MOCK_MDM_XREF", XREF_COLS)
        self._table(con, "MOCK_MDM_PHONE", PHONE_COLS)

    def _ingress(self, con: sqlite3.Connection) -> Outcome:
        verdicts = {v.ph_num: v for v in self.case.mock.phone_validation}
        mock = self.cfg.mock
        source = self.cfg.pipeline[Group.TTF].source
        members = self._rows(con, 'SELECT * FROM "MOCK_STG_MEMBER"')
        phones = self._rows(con, 'SELECT * FROM "MOCK_STG_PHONE" ORDER BY "CLIENTCODE", "SEQ"')
        self._mdm_tables(con)
        phone_rows: list[Row] = []
        failed: dict[str, str] = {}
        for p in phones:
            v = verdicts.get(_txt(p["PH_NUM"]))
            if v is not None and v.state == "FAILED":
                failed.setdefault(_txt(p["CLIENTCODE"]), v.reason)
            phone_rows.append(
                {
                    "CLIENTCODE": _txt(p["CLIENTCODE"]),
                    "CNTRY_CD": mock.country_code,
                    "PH_NUM": _txt(p["PH_NUM"]),
                    "PH_TYP": mock.phone_types[int(_txt(p["SEQ"])) % len(mock.phone_types)],
                    "NO_MRKT_CALLS": "N",
                    "VALIDATION_STATE": v.state if v else "PASSED",
                    "VALIDATION_REASON": v.reason if v else "",
                }
            )
        xrefs: list[Row] = [
            {
                **{
                    k: _txt(m[k])
                    for k in ("CLIENTCODE", "FIRST_NAME", "LAST_NAME", "MIDDLE_NAME", "DOB")
                },
                "SOURCE_SYSTEM": source,
                "ACTIVE": int(_txt(m["ACTIVE"])),
                "VALIDATION_STATE": "FAILED" if _txt(m["CLIENTCODE"]) in failed else "PASSED",
                "VALIDATION_REASON": failed.get(_txt(m["CLIENTCODE"]), ""),
                "MASTER_ID": None,
                "INDEXED": "Y",
                "SOFT_DELETED": "N",
            }
            for m in members
        ]
        self._insert(con, "MOCK_MDM_XREF", xrefs)
        self._insert(con, "MOCK_MDM_PHONE", phone_rows)
        name = self.cfg.pipeline[Group.TTF].ingress_job
        return Outcome(
            rows_in=len(members),
            rows_out=len(xrefs),
            message=f"mock {name}: {len(xrefs)} loaded, {len(failed)} failed validation",
        )

    def _merge(self, con: sqlite3.Connection, rule: str) -> Outcome:
        xrefs = self._rows(con, 'SELECT * FROM "MOCK_MDM_XREF" ORDER BY "CLIENTCODE"')
        masters: dict[tuple[str, ...], str] = {}
        for x in xrefs:
            key = (
                (_txt(x["FIRST_NAME"]).upper(), _txt(x["LAST_NAME"]).upper(), _txt(x["DOB"]))
                if rule == "name_dob"
                else (_txt(x["CLIENTCODE"]),)
            )
            master = masters.setdefault(key, f"M-{len(masters) + 1:04d}")
            con.execute(
                'UPDATE "MOCK_MDM_XREF" SET "MASTER_ID" = ? WHERE "CLIENTCODE" = ?',
                (master, x["CLIENTCODE"]),
            )
        return Outcome(
            rows_in=len(xrefs),
            rows_out=len(masters),
            message=f"mock match-merge ({rule}): {len(xrefs)} sources -> {len(masters)} masters",
        )

    def _seed_mdm(self, con: sqlite3.Connection, rows: list[Row]) -> Outcome:
        self._mdm_tables(con)
        xrefs: list[Row] = [
            {
                "CLIENTCODE": r["CLIENTCODE"],
                "SOURCE_SYSTEM": r["SOURCE_SYSTEM"],
                "FIRST_NAME": r["FIRST_NAME"],
                "LAST_NAME": r["LAST_NAME"],
                "MIDDLE_NAME": None,
                "DOB": r["DOB"],
                "ACTIVE": 1,
                "VALIDATION_STATE": "PASSED",
                "VALIDATION_REASON": "",
                "MASTER_ID": f"M-{r['MASTER_GROUP'] or r['CLIENTCODE']}",
                "INDEXED": r["INDEXED"] or "Y",
                "SOFT_DELETED": r["SOFT_DELETED"] or "N",
            }
            for r in rows
        ]
        self._insert(con, "MOCK_MDM_XREF", xrefs)
        return Outcome(rows_in=len(rows), rows_out=len(xrefs), message="seeded the mock MDM")

    def _mdm_job(self, con: sqlite3.Connection) -> Outcome:
        match self.case.mock.action:
            case "match_merge":
                return self._merge(con, self.case.mock.match_rule)
            case "reset_matched":
                return self._merge(con, "none")
            case "index":
                n = con.execute('UPDATE "MOCK_MDM_XREF" SET "INDEXED" = \'Y\'').rowcount
                return Outcome(rows_out=n, message=f"mock search indexing: {n} records indexed")
            case "purge":
                sql = 'DELETE FROM "MOCK_MDM_XREF" WHERE "SOFT_DELETED" = \'Y\''
                n = con.execute(sql).rowcount
                return Outcome(rows_out=n, message=f"mock purge: {n} soft-deleted records purged")
            case None:
                return Outcome(status=StepStatus.FAILED, message="[mock] action is not set")

    def _egress(self, con: sqlite3.Connection) -> Outcome:
        eg = self.cfg.egress
        xrefs = self._rows(con, 'SELECT * FROM "MOCK_MDM_XREF" ORDER BY "CLIENTCODE"')
        phones = self._rows(con, 'SELECT * FROM "MOCK_MDM_PHONE"')
        counts: dict[str, int] = {}
        for x in xrefs:
            counts[_txt(x["MASTER_ID"])] = counts.get(_txt(x["MASTER_ID"]), 0) + 1
        master = {_txt(x["CLIENTCODE"]): _txt(x["MASTER_ID"]) for x in xrefs}
        now = datetime.now(UTC).isoformat(timespec="seconds")
        parent: list[Row] = []
        for x in xrefs:
            full: dict[str, Cell] = {
                "MASTER_ID": _txt(x["MASTER_ID"]),
                "SOURCE_SYSTEM": _txt(x["SOURCE_SYSTEM"]),
                "SOURCE_PKEY": _txt(x["CLIENTCODE"]),
                "FIRST_NAME": _txt(x["FIRST_NAME"]),
                "LAST_NAME": _txt(x["LAST_NAME"]),
                "MIDDLE_NAME": _txt(x["MIDDLE_NAME"]),
                "DOB": _txt(x["DOB"]),
                "ACTIVE": int(_txt(x["ACTIVE"])),
                "VALIDATION_STATE": _txt(x["VALIDATION_STATE"]),
                "VALIDATION_REASON": _txt(x["VALIDATION_REASON"]),
                "MERGED_SOURCE_COUNT": counts[_txt(x["MASTER_ID"])],
                "EGRESS_TS": now,
            }
            parent.append({c: full.get(c) for c in eg.columns})
        child: list[Row] = []
        for p in phones:
            code = _txt(p["CLIENTCODE"])
            full = {
                "MASTER_ID": master.get(code, ""),
                "SOURCE_PKEY": code,
                **{
                    c: _txt(p[c])
                    for c in (
                        "CNTRY_CD",
                        "PH_NUM",
                        "PH_TYP",
                        "NO_MRKT_CALLS",
                        "VALIDATION_STATE",
                        "VALIDATION_REASON",
                    )
                },
            }
            child.append({c: full.get(c) for c in eg.phone_columns})
        self._table(con, eg.table, eg.columns)
        self._insert(con, eg.table, parent)
        self._table(con, eg.phone_table, eg.phone_columns)
        self._insert(con, eg.phone_table, child)
        name = self.cfg.pipeline[Group.TTF].egress_job
        return Outcome(
            rows_in=len(xrefs),
            rows_out=len(parent),
            message=f"mock {name}: {len(parent)} rows, {len(child)} phones",
        )

    def actual(self) -> dict[str, list[Row]]:
        """What the read step sees: egress tables (TTF) or an MDM name search (MDM group)."""
        if not self.db_path.exists():
            return {}
        eg = self.cfg.egress
        with self._db() as con:
            names = {r[0] for r in con.execute("SELECT name FROM sqlite_master WHERE type='table'")}
            if self.case.group == Group.MDM:
                if "MOCK_MDM_XREF" not in names:
                    return {}
                sql = (
                    'SELECT "MASTER_ID", "SOURCE_SYSTEM", "CLIENTCODE" AS "SOURCE_PKEY", '
                    '"FIRST_NAME", "LAST_NAME", "DOB", "VALIDATION_STATE", "VALIDATION_REASON" '
                    'FROM "MOCK_MDM_XREF" WHERE "INDEXED" = \'Y\' ORDER BY "CLIENTCODE"'
                )
                return {"MDM_SEARCH": self._typed(self._rows(con, sql))}
            return {
                t: self._typed(self._rows(con, f'SELECT * FROM "{t}"'))
                for t in (eg.table, eg.phone_table)
                if t in names
            }

    def _typed(self, rows: list[dict[str, object]]) -> list[Row]:
        return [
            {k: v if isinstance(v, int | str) or v is None else str(v) for k, v in r.items()}
            for r in rows
        ]
