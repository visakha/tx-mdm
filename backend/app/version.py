"""App version and the top three things in it. GET /api/about returns exactly this."""

VERSION = "0.9.11.1"

HIGHLIGHTS: tuple[str, str, str] = (
    "Hide fields: comment a line out of fields = [...] in b360_entities.toml (restart backend).",
    "Generate fixed: x_phone is skipped while ph_typ (required picklist) has no known values.",
    "Any backend error now says where and what (path, error type, message) instead of a bare 500.",
)
