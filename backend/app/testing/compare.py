"""Compare actual (egress tables or MDM search) with the Expected / ExpectedPhones sheets.

Blank expected cell = not checked. EXPECT_MASTER_GROUP: same value -> one master, different
values -> different masters. Phones are compared as a set per member.
"""

from datetime import date

from app.testing.models import CompareRow, Comparison
from app.testing.sheets import Cell, Row

NOT_FIELDS = {"CLIENTCODE", "EXPECT_IN_MDM", "EXPECT_MASTER_GROUP", "NOTES"}


def _s(value: Cell | object) -> str:
    match value:
        case None:
            return ""
        case date():
            return value.isoformat()
        case _:
            return str(value).strip()


def compare(
    run_id: str,
    expected: list[Row],
    expected_phones: list[Row] | None,
    actual: list[Row],
    actual_phones: list[Row] | None,
) -> Comparison:
    rows: list[CompareRow] = []
    by_code = {_s(a["SOURCE_PKEY"]): a for a in actual}
    groups: dict[str, set[str]] = {}
    for exp in expected:
        code = _s(exp["CLIENTCODE"])
        want = _s(exp["EXPECT_IN_MDM"]) == "Y"
        got = by_code.get(code)
        rows.append(
            CompareRow(
                check="member",
                clientcode=code,
                field="in MDM",
                expected="Y" if want else "N",
                actual="Y" if got else "N",
                passed=want == (got is not None),
            )
        )
        if not (want and got):
            continue
        for col, value in exp.items():
            if col in NOT_FIELDS or value is None or col not in got:
                continue
            rows.append(
                CompareRow(
                    check="field",
                    clientcode=code,
                    field=col,
                    expected=_s(value),
                    actual=_s(got[col]),
                    passed=_s(value) == _s(got[col]),
                )
            )
        group = _s(exp.get("EXPECT_MASTER_GROUP"))
        if group:
            groups.setdefault(group, set()).add(_s(got.get("MASTER_ID")))
        if expected_phones is not None and actual_phones is not None:
            rows += _phones(code, expected_phones, actual_phones)
    owner: dict[str, str] = {}
    for group, masters in sorted(groups.items()):
        clash = [owner[m] for m in masters if m in owner]
        rows.append(
            CompareRow(
                check="master_group",
                clientcode=group,
                field="MASTER_ID",
                expected="one master, not shared",
                actual=",".join(sorted(masters)),
                passed=len(masters) == 1 and not clash,
            )
        )
        owner.update(dict.fromkeys(masters, group))
    failed = sum(not r.passed for r in rows)
    return Comparison(
        run_id=run_id, passed=failed == 0, checked=len(rows), failed=failed, rows=rows
    )


def _phones(code: str, expected: list[Row], actual: list[Row]) -> list[CompareRow]:
    want = {_s(p["PH_NUM"]): p for p in expected if _s(p["CLIENTCODE"]) == code}
    got = {_s(p["PH_NUM"]): p for p in actual if _s(p["SOURCE_PKEY"]) == code}
    rows = [
        CompareRow(
            check="phone",
            clientcode=code,
            field="PH_NUM set",
            expected=",".join(sorted(want)) or "(none)",
            actual=",".join(sorted(got)) or "(none)",
            passed=set(want) == set(got),
        )
    ]
    for num, exp in want.items():
        if num not in got:
            continue
        for col, value in exp.items():
            if col in ("CLIENTCODE", "PH_NUM") or value is None or col not in got[num]:
                continue
            rows.append(
                CompareRow(
                    check="phone",
                    clientcode=code,
                    field=f"{num}.{col}",
                    expected=_s(value),
                    actual=_s(got[num][col]),
                    passed=_s(value) == _s(got[num][col]),
                )
            )
    return rows
