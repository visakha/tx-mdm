"""App version and the top three things in it. GET /api/about returns exactly this."""

VERSION = "0.9.17"

HIGHLIGHTS: tuple[str, str, str] = (
    "Design notebook: only your own assets - mappings m_, mapping tasks mt_, taskflows tf_.",
    "Design lists: Up / Down / Home / End move the highlight, Enter opens the asset.",
    "Design lists: Ctrl+C copies the highlighted asset as labelled lines (with its detail).",
)
