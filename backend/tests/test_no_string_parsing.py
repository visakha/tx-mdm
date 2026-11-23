"""0.9.13 guard (Vamsi 02:35 CST): no regex in backend/app; no RegExp or .split on identifiers in
frontend/src. Name rules live as data in app/common/naming.py; the entity tree is typed
(FieldPath). Allowlisted: free-text search words (shell/search.ts) and tests."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BACKEND = ROOT / "backend" / "app"
FRONTEND = ROOT / "frontend" / "src"
FRONTEND_ALLOW = {"shell/search.ts"}  # free-text search: splitting words is the point


def test_no_regex_in_backend_app() -> None:
    bad = []
    for path in BACKEND.rglob("*.py"):
        for n, line in enumerate(path.read_text(encoding="ascii").splitlines(), start=1):
            text = line.strip()
            if text in ("import re",) or text.startswith(("import re ", "from re ")):
                bad.append(f"{path.relative_to(ROOT)}:{n}: {text}")
            if "pattern=r" in text:
                bad.append(f"{path.relative_to(ROOT)}:{n}: {text}")
    assert bad == [], "regex in backend/app (use app/common/naming.py rules):\n" + "\n".join(bad)


def test_no_regexp_or_split_in_frontend() -> None:
    bad = []
    for path in FRONTEND.rglob("*.ts*"):
        rel = path.relative_to(FRONTEND).as_posix()
        if rel in FRONTEND_ALLOW or ".test." in rel:
            continue
        for n, line in enumerate(path.read_text(encoding="ascii").splitlines(), start=1):
            if any(t in line for t in ("RegExp", ".split(", ".match(", ".replace(/", "/.test(")):
                bad.append(f"{rel}:{n}: {line.strip()}")
    assert bad == [], "string parsing in frontend/src (use typed objects):\n" + "\n".join(bad)
