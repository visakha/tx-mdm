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
import re
import tomllib
from functools import lru_cache
from pathlib import Path

from pydantic import BaseModel, ConfigDict, Field, ValidationError, field_validator

from app.b360data.models import BusinessEntity, EntityCategory, FieldVisibility

ENV_VAR = "B360_ENTITIES_FILE"
_SOURCE_ID = re.compile(r"[A-Za-z0-9._-]{1,128}")
_FIELD_NAME = re.compile(r"[A-Za-z0-9._-]{1,256}")
DEFAULT_FILE = Path(__file__).resolve().parents[2] / "b360_entities.toml"


class FocusEntity(BaseModel):
    """One [[entity]] block of b360_entities.toml."""

    model_config = ConfigDict(extra="forbid")

    name: str = Field(min_length=1, max_length=128, pattern=r"^[A-Za-z0-9._-]+$")
    label: str | None = Field(default=None, min_length=1, max_length=128)
    fields: list[str] | None = Field(
        default=None,
        description="0.10: every field / group / system name, one per line; comment one out with "
        "# to hide it on the records screens. Missing list = show all.",
    )

    @field_validator("name")
    @classmethod
    def _strip(cls, value: str) -> str:
        return value.strip()

    @field_validator("fields")
    @classmethod
    def _field_names(cls, value: list[str] | None) -> list[str] | None:
        if value is None:
            return None
        out = [v.strip() for v in value]
        for item in out:
            if not _FIELD_NAME.fullmatch(item):
                raise ValueError(f"bad field name {item!r} (letters, digits, . _ - only)")
        if len({v.lower() for v in out}) != len(out):
            raise ValueError("a field is listed twice")
        return out


class SourcesConfig(BaseModel):
    """The [sources] table: source systems the Add records tab may send to. EXACT case.

    Vamsi, 2026-11-23 01:10 CST: his source systems are zlv_ttf and zlv_eci, all lowercase, plus
    c360.default.system. There is no documented API that lists source systems, so this list is
    the gate: the backend refuses any sourceSystem not in it (400). The file is never written
    from code; he edits it.
    """

    model_config = ConfigDict(extra="forbid")

    allowed: list[str] = Field(default_factory=list)
    default: str | None = None

    @field_validator("allowed")
    @classmethod
    def _ids(cls, value: list[str]) -> list[str]:
        for item in value:
            if not _SOURCE_ID.fullmatch(item):
                raise ValueError(f"bad source system id {item!r} (letters, digits, . _ - only)")
        if len(set(value)) != len(value):
            raise ValueError("a source system is listed twice")
        return value

    def default_source(self) -> str | None:
        if self.default is not None:
            return self.default
        return self.allowed[0] if self.allowed else None

    def is_allowed(self, source_system: str) -> bool:
        return source_system in self.allowed  # case-sensitive on purpose


class FocusConfig(BaseModel):
    """The whole b360_entities.toml file."""

    model_config = ConfigDict(extra="forbid")

    entity: list[FocusEntity] = Field(default_factory=list)
    sources: SourcesConfig = Field(default_factory=SourcesConfig)

    def names(self) -> list[str]:
        return [e.name for e in self.entity]

    def label_override(self, name: str) -> str | None:
        wanted = name.strip().lower()
        for e in self.entity:
            if e.name.lower() == wanted:
                return e.label
        return None

    def fields_for(self, name: str) -> list[str] | None:
        wanted = name.strip().lower()
        for e in self.entity:
            if e.name.lower() == wanted:
                return e.fields
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
    sources = config.sources
    if sources.default is not None and sources.default not in sources.allowed:
        raise FocusConfigError(
            f"B360 entities file: [sources] default {sources.default!r} is not in allowed: {path}"
        )
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


def metadata_names(entity: BusinessEntity) -> list[str]:
    """Every name a fields list may carry, in metadata order: root fields, groups and their
    fields (group.field), system fields, system groups (_meta) and their fields (_meta.x)."""
    names: list[str] = [f.name for f in entity.fields]
    for g in entity.field_groups:
        names.append(g.name)
        names.extend(f"{g.name}.{f.name}" for f in g.fields)
    names.extend(f.name for f in entity.system_fields)
    for g in entity.system_field_groups:
        names.append(g.name)
        names.extend(f"{g.name}.{f.name}" for f in g.fields)
    return names


def visibility_for(entity: BusinessEntity, listed: list[str] | None) -> FieldVisibility:
    """Hidden = metadata names not in the list (a hidden group hides all its fields); TOML
    names the metadata does not know become warnings. Compared case-insensitively."""
    if listed is None:
        return FieldVisibility()
    known = metadata_names(entity)
    keep = {n.lower() for n in listed}
    groups = {g.name.lower() for g in [*entity.field_groups, *entity.system_field_groups]}
    hidden: list[str] = []
    for name in known:
        head = name.split(".", 1)[0].lower() if "." in name else None
        group_hidden = head is not None and head in groups and head not in keep
        if name.lower() not in keep or group_hidden:
            hidden.append(name)
    known_lower = {n.lower() for n in known}
    warnings = [
        f"{entity.name}: '{n}' in b360_entities.toml is not in the metadata (ignored)"
        for n in listed
        if n.lower() not in known_lower
    ]
    return FieldVisibility(listed=True, hidden=hidden, warnings=warnings)


def field_visibility(entity: BusinessEntity) -> FieldVisibility:
    return visibility_for(entity, focus_config().fields_for(entity.name))
