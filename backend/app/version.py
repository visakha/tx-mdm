"""App version and the top three things in it. GET /api/about returns exactly this."""

VERSION = "0.9.18"

HIGHLIGHTS: tuple[str, str, str] = (
    "Modern styling: tabs, text boxes, buttons and tables restyled (CSS only, no markup changes).",
    "Side-by-side fields line up: labels above their box, inputs and buttons share one height.",
    "Agent bridge untouched: same roles, aria-labels and components; shipped without tests.",
)
