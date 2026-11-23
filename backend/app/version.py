"""App version and the top three things in it. GET /api/about returns exactly this."""

VERSION = "0.9.6"

HIGHLIGHTS: tuple[str, str, str] = (
    "MDM child mapping tasks (mt_m_MDM_*, *_EGR, *_IGR) moved out of the CDI notebook.",
    "Business 360 Taskflows shows them read only, each linked to the taskflow it runs via.",
    "The backend refuses to start an MDM mapping task on its own (400, never sent to IDMC).",
)
