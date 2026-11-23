"""Fails when frontend/src/b360/api-types.ts drifts from the backend B360 models."""

from app.main import create_app
from dev import gen_ts_types


def test_generated_ts_types_match_backend_schema() -> None:
    expected = gen_ts_types.render(create_app().openapi())
    actual = gen_ts_types.OUT.read_text(encoding="ascii")
    assert actual == expected, "B360 TS types are stale: cd frontend && npm run gen:types"
