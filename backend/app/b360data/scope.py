"""Which business entities the B360 Data notebook shows. ONE place for the rule.

Vamsi (voice, 2026-11-23 01:00-01:04 CST): "let's focus on ZLV guest only" and "what business
entity [to] be shown should be written to a config file or a toml file in the backend, so that
I'm just going to edit that."

So the focus list lives in backend/b360_entities.toml (or the file named by the env var
B360_ENTITIES_FILE), read once at startup with stdlib tomllib and validated into the typed
FocusConfig model. A bad file raises FocusConfigError at startup. Everything else (labels,
fields, field groups) still comes from the B360 metadata APIs.
"""

import os
import tomllib
from functools import lru_cache
from pathlib import Path

from pydantic import BaseModel, ConfigDict, Field, ValidationError, field_validator

from app.b360data.models import EntityCategory

ENV_VAR = "B360_ENTITIES_FILE"
DEFAULT_FILE = Path(__file__).resolve().parents[2] / "b360_entities.toml"


class FocusEntity(BaseModel):
    """One [[entity]] block of b360_entities.toml."""

    model_config = ConfigDict(extra="forbid")

    name: str = Field(min_length=1, max_length=128, pattern=r"^[A-Za-z0-9._-]+$")
    label: str | None = Field(default=None, min_length=1, max_length=128)

    @field_validator("name")
    @classmethod
    def _strip(cls, value: str) -> str:
        return value.strip()


class FocusConfig(BaseModel):
    """The whole b360_entities.toml file."""

    model_config = ConfigDict(extra="forbid")

    entity: list[FocusEntity] = Field(default_factory=list)

    def names(self) -> list[str]:
        return [e.name for e in self.entity]

    def label_override(self, name: str) -> str | None:
        wanted = name.strip().lower()
        for e in self.entity:
            if e.name.lower() == wanted:
                return e.label
        return None

    def contains(self, name: str) -> bool:
        wanted = name.strip().lower()
        return any(e.name.lower() == wanted for e in self.entity)


class FocusConfigError(RuntimeError):
    """b360_entities.toml is missing, not valid TOML, or not the expected shape."""


def config_path() -> Path:
    raw = os.environ.get(ENV_VAR, "").strip()
    return Path(raw) if raw else DEFAULT_FILE


def load_focus_config(path: Path) -> FocusConfig:
    try:
        text = path.read_text(encoding="ascii")
    except FileNotFoundError as exc:
        raise FocusConfigError(f"B360 entities file not found: {path} (set {ENV_VAR})") from exc
    except UnicodeDecodeError as exc:
        raise FocusConfigError(f"B360 entities file must be plain ASCII: {path}") from exc
    try:
        data = tomllib.loads(text)
    except tomllib.TOMLDecodeError as exc:
        raise FocusConfigError(f"B360 entities file is not valid TOML: {path}: {exc}") from exc
    try:
        config = FocusConfig.model_validate(data)
    except ValidationError as exc:
        problems = "; ".join(
            f"{'.'.join(str(p) for p in err['loc'])}: {err['msg']}" for err in exc.errors()
        )
        raise FocusConfigError(f"B360 entities file has errors: {path}: {problems}") from exc
    seen: set[str] = set()
    for e in config.entity:
        key = e.name.lower()
        if key in seen:
            raise FocusConfigError(f"B360 entities file lists {e.name} twice: {path}")
        seen.add(key)
    return config


@lru_cache(maxsize=1)
def focus_config() -> FocusConfig:
    """Read once per process (startup). Restart the backend to pick up edits."""
    return load_focus_config(config_path())


# Name prefix -> category (lower-case compare). Anything else is the org's own custom entity.
_PREFIX_CATEGORY: tuple[tuple[str, EntityCategory], ...] = (
    ("c360.", EntityCategory.OUT_OF_THE_BOX),
    ("rdm.", EntityCategory.REFERENCE),
    ("entity.", EntityCategory.TEMPLATE),
)


def category_of(name: str) -> EntityCategory:
    lowered = name.strip().lower()
    for prefix, category in _PREFIX_CATEGORY:
        if lowered.startswith(prefix):
            return category
    return EntityCategory.CUSTOM


def is_focus(name: str) -> bool:
    return focus_config().contains(name)
