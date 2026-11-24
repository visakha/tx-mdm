"""0.10.0 testing harness API: few tests on purpose - the roadrunner-py BDD features test it."""

import io
from pathlib import Path

import openpyxl
import pytest
from fastapi.testclient import TestClient

from app.main import create_app
from app.testing.runs import RunStore, get_store

MOCK = "/api/test/mock/TTF/use-case-9"


@pytest.fixture
def api(tmp_path: Path) -> TestClient:
    app = create_app()
    store = RunStore(tmp_path)
    app.dependency_overrides[get_store] = lambda: store
    return TestClient(app)


def _template(api: TestClient, base: str = MOCK) -> bytes:
    response = api.get(f"{base}/template", params={"mode": "generated", "rows": 4})
    assert response.status_code == 200
    return response.content


def test_template_home_first_and_round_trip_preflight(api: TestClient) -> None:
    data = _template(api)
    book = openpyxl.load_workbook(io.BytesIO(data))
    assert book.sheetnames[0] == "Home" and "ExpectedPhones" in book.sheetnames
    report = api.post(f"{MOCK}/preflight", files={"file": ("t.xlsx", data)}).json()
    assert report["ok"] and report["template_version"] == "1.0"
    del book["CLIENTS"]
    out = io.BytesIO()
    book.save(out)
    bad = api.post(f"{MOCK}/runs", files={"file": ("t.xlsx", out.getvalue())})
    assert bad.status_code == 422 and bad.json()["issues"][0]["sheet"] == "CLIENTS"


def test_mock_run_waits_at_manual_steps_then_passes_with_invalid_phone(api: TestClient) -> None:
    run = api.post(f"{MOCK}/runs", files={"file": ("t.xlsx", _template(api))}).json()
    for step in ("ingress", "egress"):
        assert run["state"] == "WAITING" and step in run["message"]
        url = f"{MOCK}/runs/{run['run_id']}/continue"
        run = api.post(url, json={"step": step, "answer": "done"}).json()
    assert run["state"] == "PASSED", run["message"]
    rows = api.get(f"{MOCK}/runs/{run['run_id']}/comparison").json()["rows"]
    assert any(r["field"] == "VALIDATION_REASON" and r["actual"] == "invalid phone" for r in rows)
    result = api.get(f"{MOCK}/runs/{run['run_id']}/result")
    names = openpyxl.load_workbook(io.BytesIO(result.content)).sheetnames
    assert names[:4] == ["Home", "Handshakes", "Steps", "Comparison"]


def test_real_path_reports_not_configured_and_never_calls_idmc(api: TestClient) -> None:
    real = "/api/test/TTF/use-case-1"
    run = api.post(f"{real}/runs", files={"file": ("t.xlsx", _template(api, real))}).json()
    assert run["path"] == "real" and run["state"] == "NOT_CONFIGURED"
    assert "not wired" in run["message"]
