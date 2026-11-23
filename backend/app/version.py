"""App version and the top three things in it. GET /api/about returns exactly this."""

VERSION = "0.9.5"

HIGHLIGHTS: tuple[str, str, str] = (
    "New B360 Data notebook: business entities are discovered from your org's metadata APIs.",
    "Click an entity to see its first 10 records; click a record to see its field groups stacked.",
    "B360 metadata and records are strongly typed models end to end, with generated TS types.",
)
