"""App version and the top three things in it. GET /api/about returns exactly this."""

VERSION = "0.9.2"

HIGHLIGHTS: tuple[str, str, str] = (
    "Run history groups each taskflow run with its child mapping tasks on the rows right under it.",
    "Child mapping-task rows are indented under their taskflow run; no colour coding.",
    "Each row is labelled taskflow or mapping task; a child with no matching run says so.",
)
