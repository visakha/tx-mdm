"""App version and the top three things in it. GET /api/about returns exactly this."""

VERSION = "0.9.16"

HIGHLIGHTS: tuple[str, str, str] = (
    'Design notebook: asset name + "Go to IDMC" open the mapping / mapping task / taskflow page.',
    "Design notebook: CDI asset types -> assets -> created/updated/by + runtime environment.",
    'IDMC portal links: B360 job ids, and "Go to IDMC" beneath each taskflow run id.',
)
