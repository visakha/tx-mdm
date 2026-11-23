"""App version and the top three things in it. GET /api/about returns exactly this."""

VERSION = "0.9.1"

HIGHLIGHTS: tuple[str, str, str] = (
    "Taskflows Run tab: pick and run a taskflow, then scroll down for all its runs, running first.",
    "Each run in the history has Summary and Session log links; the Track run id tab is gone.",
    "Start several runs of one taskflow in parallel; a new run shows at the top straight away.",
)
