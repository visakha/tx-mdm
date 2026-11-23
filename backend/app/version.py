"""App version and the top three things in it. GET /api/about returns exactly this."""

VERSION = "0.7.0"

HIGHLIGHTS: tuple[str, str, str] = (
    "Run a CDI taskflow by name with its input fields (jobInstanceId), then follow it by run id.",
    "Abort a running taskflow by run id (Abort button and POST .../terminate).",
    "OneNote-style layout: left pane with search and sections, contextual tabs on top.",
)
