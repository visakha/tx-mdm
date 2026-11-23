"""App version and the top three things in it. GET /api/about returns exactly this."""

VERSION = "0.9.4"

HIGHLIGHTS: tuple[str, str, str] = (
    "Business 360 taskflows (tf_MDM_*, *_EGR, *_IGR) moved to the Business 360 notebook.",
    "The CDI notebook now lists only CDI taskflows, and they run with no jobInstanceId.",
    "B360 taskflows need a jobInstanceId (no ABC123 default); the backend refuses a wrong one.",
)
