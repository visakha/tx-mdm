"""App version and the top three things in it. GET /api/about returns exactly this."""

VERSION = "0.9.12.2"

HIGHLIGHTS: tuple[str, str, str] = (
    "Merge (M): merge 2-10 master records, winner per field (clns_ follows); Undo = Unmerge.",
    "Reference 360 picklists + lengths: ph_typ real Codes; cntry_cd 3, ph_num 10 digits.",
    "API docs (typed) at /openapi-typed.json; no more boxes above tables (click the row).",
)
