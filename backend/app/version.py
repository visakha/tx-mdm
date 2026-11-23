"""App version and the top three things in it. GET /api/about returns exactly this."""

VERSION = "0.9.12.1"

HIGHLIGHTS: tuple[str, str, str] = (
    "Merge (M): merge 2-10 master records, winner per field (clns_ follows); Undo = Unmerge.",
    "Picklists from Reference 360: ph_typ offers the real Codes of the list the metadata names.",
    "No more boxes above tables: click the row (or its id button) to open a record.",
)
