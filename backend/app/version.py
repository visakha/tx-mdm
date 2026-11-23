"""App version and the top three things in it. GET /api/about returns exactly this."""

VERSION = "0.9.12.3"

HIGHLIGHTS: tuple[str, str, str] = (
    "Merge (M): merge 2-10 master records, winner per field (clns_ follows); Undo = Unmerge.",
    "Reference 360 picklists + lengths: ph_typ real Codes; cntry_cd 3, ph_num 10 digits.",
    "Records (S) / Metadata Source: tick source systems; one Metadata tab (Master | Source).",
)
