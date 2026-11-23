"""App version and the top three things in it. GET /api/about returns exactly this."""

VERSION = "0.9.8"

HIGHLIGHTS: tuple[str, str, str] = (
    "B360 Data Add records tab: type a record in a form built from a Pydantic model, then Save.",
    "Or Generate 1-100 Faker test rows, edit or remove them, then Send to B360 (asks first).",
    "Source systems come from [sources] in b360_entities.toml (zlv_ttf default); others refused.",
)
