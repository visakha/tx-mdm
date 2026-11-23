"""0.10: per-entity `fields = [...]` in b360_entities.toml hides commented-out fields on the
records screens (Vamsi 02:01 CST). Fake IDMC metadata only."""

from pathlib import Path

import pytest

from app.b360data.scope import (
    FocusConfigError,
    load_focus_config,
    metadata_names,
    visibility_for,
)
from app.b360data.wire import business_entity_from_metadata
from dev import fake_idmc

ENTITY = business_entity_from_metadata(fake_idmc._B360_ENTITIES["zlv_guest"], "zlv_guest")
REPO_TOML = Path(__file__).resolve().parents[1] / "b360_entities.toml"


def test_no_list_shows_everything() -> None:
    vis = visibility_for(ENTITY, None)
    assert not vis.listed and vis.hidden == [] and vis.warnings == []


def test_commented_out_names_are_hidden_and_unknown_names_warn() -> None:
    names = metadata_names(ENTITY)
    keep = [n for n in names if n not in ("first_name", "x_phone")] + ["no_such_field"]
    vis = visibility_for(ENTITY, keep)
    assert vis.listed
    assert "first_name" in vis.hidden
    assert "x_phone" in vis.hidden
    assert all(h in vis.hidden for h in names if h.startswith("x_phone."))  # group hides fields
    assert "last_name" not in vis.hidden
    assert vis.warnings == [
        "zlv_guest: 'no_such_field' in b360_entities.toml is not in the metadata (ignored)"
    ]


def test_full_list_hides_nothing_case_insensitive() -> None:
    vis = visibility_for(ENTITY, [n.upper() for n in metadata_names(ENTITY)])
    assert vis.hidden == [] and vis.warnings == []


def test_repo_toml_lists_zlv_guest_live_fields_one_per_line() -> None:
    config = load_focus_config(REPO_TOML)
    fields = config.fields_for("zlv_guest")
    assert fields is not None
    for name in (
        "first_name",
        "ffr_first_name",
        "x_phone.ph_typ",
        "validationType",
        "_meta.lastUpdateDate",
    ):
        assert name in fields
    text = REPO_TOML.read_text(encoding="ascii")
    assert '  "x_phone.no_mrkt_calls",\n' in text  # own line, so it can be commented out


def test_duplicate_field_is_a_clear_startup_error(tmp_path: Path) -> None:
    bad = tmp_path / "e.toml"
    bad.write_text('[[entity]]\nname = "zlv_guest"\nfields = ["a", "A"]\n', encoding="ascii")
    with pytest.raises(FocusConfigError, match="listed twice"):
        load_focus_config(bad)


def test_records_page_carries_visibility(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    from app.b360data import scope

    cfg = tmp_path / "e.toml"
    cfg.write_text('[[entity]]\nname = "zlv_guest"\nfields = ["last_name"]\n', encoding="ascii")
    monkeypatch.setenv(scope.ENV_VAR, str(cfg))
    scope.focus_config.cache_clear()
    try:
        vis = scope.field_visibility(ENTITY)
        assert "first_name" in vis.hidden and "last_name" not in vis.hidden
    finally:
        scope.focus_config.cache_clear()
