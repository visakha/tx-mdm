"""App version and the top three things in it. GET /api/about returns exactly this."""

VERSION = "0.9.14"

HIGHLIGHTS: tuple[str, str, str] = (
    "API docs IDMC (/docs-idmc): only the IDMC calls we make, from one typed call registry.",
    "Merge (M) + Merge history (M)/(S); Reference 360 picklists + lengths; source checkboxes.",
    "Aligned Add / Edit forms; Save on first change; Ctrl+C row copy; IDMC curl to clipboard.",
)
