"""App version and the top three things in it. GET /api/about returns exactly this."""

VERSION = "0.9.10"

HIGHLIGHTS: tuple[str, str, str] = (
    "Master vs Source tabs: Records (S) per master, Metadata (S), Edit records (S) via one PATCH.",
    "Field groups (e.g. x_phone) in Generate, Type it and Edit; picklists only from real values.",
    "No pop-ups anywhere; system columns in magenta; tables scroll with a sticky header.",
)
