"""App version and the top three things in it. GET /api/about returns exactly this."""

VERSION = "0.9.15"

HIGHLIGHTS: tuple[str, str, str] = (
    "Design notebook: CDI asset types -> assets -> created/updated/by + runtime environment.",
    "Taskflow -> its mapping tasks via IDMC references (replaces the tf_ -> mt_m_ name guess).",
    "B360 job instance ids link to the IDMC portal job page (new tab), built by the backend.",
)
