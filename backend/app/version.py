"""App version and the top three things in it. GET /api/about returns exactly this."""

VERSION = "0.9.13"

HIGHLIGHTS: tuple[str, str, str] = (
    "Merge (M) with per-field winners; Merge history (M) / (S): who contributes what now.",
    "Reference 360 picklists + lengths; Records (S) / Metadata Source by ticked source systems.",
    "Copy IDMC curl (PowerShell / bash vs IDMC); 0.9.13 typed cleanup: no regex, typed paths.",
)
