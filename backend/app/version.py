"""App version and the top three things in it. GET /api/about returns exactly this."""

VERSION = "0.8.0"

HIGHLIGHTS: tuple[str, str, str] = (
    "Left-pane search now finds tasks, taskflows and jobs by name and opens them in one click.",
    "Run results show a progress bar and a clock that changes colour on every 15 s status check.",
    "Taskflows: Run by name and Track a run id are stacked full width; an abort shows as Aborted.",
)
