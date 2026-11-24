"""App version and the top three things in it. GET /api/about returns exactly this."""

VERSION = "0.10.0"

HIGHLIGHTS: tuple[str, str, str] = (
    "Testing harness: /api/test/mock/{TTF|MDM} (SQLite + fake IDMC) and /api/test/{group} (real).",
    "roadrunner-py desktop runner: pytest-bdd features, [PAUSE] handshakes, result xlsx + run log.",
    "PUT /api/cdi/mapping-tasks/{id}/runtime-environment: move one task, partial POST, read back.",
)
