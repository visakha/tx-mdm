"""App version and the top three things in it. GET /api/about returns exactly this."""

VERSION = "0.10.1"

HIGHLIGHTS: tuple[str, str, str] = (
    "POST/GET /api/mdm/publish-events/runs: start Publish Business Events, read its status.",
    "Testing harness: /api/test/mock/{TTF|MDM} (SQLite + fake IDMC) and /api/test/{group} (real).",
    "PUT /api/cdi/mapping-tasks/{id}/runtime-environment: move one task, partial POST, read back.",
)
