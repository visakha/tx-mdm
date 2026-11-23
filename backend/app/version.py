"""App version and the top three things in it. GET /api/about returns exactly this."""

VERSION = "0.9.12"

HIGHLIGHTS: tuple[str, str, str] = (
    "Merge (M): merge 2-10 master records, winner per field (clns_ follows); Undo = Unmerge.",
    "Picklists from Reference 360: ph_typ offers the real Codes of the list the metadata names.",
    "API docs (typed): /openapi-typed.json + /docs-typed with concrete schemas per entity.",
)
