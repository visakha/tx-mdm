"""GET /api/about: a version and exactly three highlights."""

from fastapi.testclient import TestClient

from app.main import create_app
from app.version import VERSION


def test_about_is_version_plus_three_highlights() -> None:
    body = TestClient(create_app()).get("/api/about").json()
    assert set(body) == {"version", "highlights"}
    assert body["version"] == VERSION
    assert len(body["highlights"]) == 3
    assert all(isinstance(h, str) and h for h in body["highlights"])
