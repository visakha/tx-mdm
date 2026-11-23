"""App version and the top three things in it. GET /api/about returns exactly this."""

VERSION = "0.9.3"

HIGHLIGHTS: tuple[str, str, str] = (
    "Summary and Session log links now sit right after the run id on every run history row.",
    "Child mapping-task rows link to their taskflow run; Session log opens with that child picked.",
    "Clear buttons on Run history, Summary and Session log - view only, nothing in IDMC is touched.",
)
