"""App version and the top three things in it. GET /api/about returns exactly this."""

VERSION = "0.9.9"

HIGHLIGHTS: tuple[str, str, str] = (
    "B360 Records: 10 per page with Prev / Next and Page X of Y (N records) from the Search API.",
    "Filter by first / last name (starts with) or exact Business ID; Last updated column sorts.",
    "Metadata tab also lists system fields and field groups, in magenta with a system label.",
)
