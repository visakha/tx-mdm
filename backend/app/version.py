"""App version and the top three things in it. GET /api/about returns exactly this."""

VERSION = "0.9.7"

HIGHLIGHTS: tuple[str, str, str] = (
    "B360 Data left pane lists the entities in backend/b360_entities.toml (zlv_guest today).",
    "Edit that TOML file and restart the backend to change them; unknown names show not found.",
    "Entity page is master-detail: root records on top, field groups stacked below; Metadata tab.",
)
