"""0.9.13 (Vamsi 02:35 CST): "typed objects even under the backend ... no parsing by strings ...
regex ... It has to be typed. It has to be clean. It has to be objects ... declarative."

ONE place for name rules, as data: character sets, a NameRule table (MatchKind PREFIX | SUFFIX,
value, what a match means), and Transform rules for derived values. No regex anywhere in
backend/app (tests/test_no_string_parsing.py guards it).
"""

from dataclasses import dataclass
from enum import StrEnum
from typing import Annotated

from pydantic import AfterValidator

LETTERS = frozenset("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz")
DIGITS = frozenset("0123456789")
ALNUM = LETTERS | DIGITS
ID_CHARS = ALNUM | frozenset("._-")
SCHEMA_KEY_CHARS = ALNUM | frozenset("_")


def is_identifier(text: str, max_len: int) -> bool:
    """Letters, digits, '.', '_', '-' only; 1..max_len characters (IDMC ids, entity names)."""
    return 1 <= len(text) <= max_len and all(ch in ID_CHARS for ch in text)


def _identifier(max_len: int) -> AfterValidator:
    def check(text: str) -> str:
        if not is_identifier(text, max_len):
            raise ValueError(f"letters, digits, '.', '_', '-' only, 1-{max_len} characters")
        return text

    return AfterValidator(check)


# Typed identifiers for request parameters (FastAPI path / query params, Pydantic fields).
Identifier64 = Annotated[str, _identifier(64)]
Identifier128 = Annotated[str, _identifier(128)]


class Transform(StrEnum):
    """How a derived value is made from its source value."""

    UPPER_ALNUM = "UPPER_ALNUM"  # keep letters and digits, upper-case (clns_ cleansed twins)
    SLUG = "SLUG"  # lower-case; every run of other characters becomes one '_'; no edge '_'
    SCHEMA_KEY = "SCHEMA_KEY"  # every character outside letters, digits, '_' becomes '_'


def apply(transform: Transform, text: str) -> str:
    match transform:
        case Transform.UPPER_ALNUM:
            return "".join(ch for ch in text if ch in ALNUM).upper()
        case Transform.SCHEMA_KEY:
            return "".join(ch if ch in SCHEMA_KEY_CHARS else "_" for ch in text)
        case Transform.SLUG:
            out: list[str] = []
            for ch in text.lower():
                if ch in ALNUM:
                    out.append(ch)
                elif out and out[-1] != "_":
                    out.append("_")
            return "".join(out).strip("_")


class MatchKind(StrEnum):
    PREFIX = "PREFIX"
    SUFFIX = "SUFFIX"


@dataclass(frozen=True)
class NameRule[T]:
    """One row of a naming-convention table: names matching (kind, value) mean `meaning`.
    Matching ignores case unless exact_case (0.9.17: his own Design assets, lowercase "m_").
    The table order is the precedence: first match wins."""

    kind: MatchKind
    value: str
    meaning: T
    exact_case: bool = False

    def matches(self, name: str) -> bool:
        lowered = name.strip() if self.exact_case else name.strip().lower()
        wanted = self.value if self.exact_case else self.value.lower()
        match self.kind:
            case MatchKind.PREFIX:
                return lowered.startswith(wanted) and len(lowered) > len(wanted)
            case MatchKind.SUFFIX:
                return lowered.endswith(wanted) and len(lowered) > len(wanted)


def first_match[T](rules: tuple[NameRule[T], ...], name: str) -> NameRule[T] | None:
    return next((r for r in rules if r.matches(name)), None)


def strip_rule(rule: NameRule[object], name: str) -> str:
    """The name without the rule's prefix / suffix (exact case of the rest kept)."""
    size = len(rule.value)
    match rule.kind:
        case MatchKind.PREFIX:
            return name.strip()[size:]
        case MatchKind.SUFFIX:
            return name.strip()[:-size]
