"""App version and the top three things in it. GET /api/about returns exactly this."""

VERSION = "0.9.11"

HIGHLIGHTS: tuple[str, str, str] = (
    "Hide fields: comment a line out of fields = [...] in b360_entities.toml (restart backend).",
    "Generated rows leave ffr_* (freeform reason) empty; field groups like x_phone are generated.",
    "API docs link in the title bar; Master vs Source tabs; no pop-ups anywhere.",
)
