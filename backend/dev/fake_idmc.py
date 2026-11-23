"""A tiny fake IDMC for local demos and smoke tests. Not used in production.

Run:  uvicorn dev.fake_idmc:app --port 8900
Then start the backend with IDMC_LOGIN_URL=http://127.0.0.1:8900,
IDMC_MDM_URL=http://127.0.0.1:8900 and IDMC_PLATFORM_URL=http://127.0.0.1:8900/saas.
Jobs finish SUCCESS on the second status check.
The Monitor tab calls (activityMonitor?details=true, activityLog?rowLimit=N) get a fixed
demo set: one running taskflow with two child steps, plus a few finished runs.
"""

from datetime import UTC, datetime, timedelta
from typing import Any

from fastapi import FastAPI

app = FastAPI(title="fake IDMC")
_checks: dict[str, int] = {}


def _bump(key: str) -> int:
    _checks[key] = _checks.get(key, 0) + 1
    return _checks[key]


@app.post("/saas/public/core/v3/login")
def login() -> dict[str, Any]:
    return {
        "userInfo": {"sessionId": "fake-session"},
        "products": [{"baseApiUrl": "http://127.0.0.1:8900/saas"}],
    }


@app.get("/saas/public/core/v3/objects")
def objects(q: str) -> dict[str, Any]:
    if "MDM_JOB_DEFINITION" in q:
        return {
            "objects": [
                {"id": "A1", "path": "MDM/ingress_person"},
                {"id": "A2", "path": "MDM/egress_person"},
                {"id": "A3", "path": "MDM/never_run_job"},
            ]
        }
    if "MTT" in q:
        return {"objects": [{"id": "FED1", "path": "Default/mt_load_customers"}]}
    if "WORKFLOW" in q:
        return {"objects": [{"id": "FED2", "path": "Default/tf_load_all"}]}
    return {"objects": []}


@app.post("/saas/api/v2/job")
def run_cdi() -> dict[str, Any]:
    return {"runId": 7, "taskId": "T1", "taskType": "MTT"}


def _ago(minutes: float) -> str:
    return (datetime.now(UTC) - timedelta(minutes=minutes)).strftime("%Y-%m-%dT%H:%M:%S.000Z")


@app.get("/saas/api/v2/activity/activityMonitor")
def monitor(details: str = "false") -> list[dict[str, Any]]:
    if details == "true":  # Monitor tab
        return [
            {
                "taskId": "T2",
                "taskName": "tf_load_all",
                "type": "WORKFLOW",
                "runId": 41,
                "startTimeUtc": _ago(7.5),
                "executionState": "RUNNING",
                "startedBy": "VVamsi-IDMCDev",
                "runContextType": "REST-API",
                "entries": [
                    {
                        "taskName": "mt_load_customers",
                        "type": "MTT",
                        "runId": 42,
                        "startTimeUtc": _ago(7.4),
                        "executionState": "RUNNING",
                        "successSourceRows": 5400,
                        "successTargetRows": 5390,
                        "failedTargetRows": 10,
                    }
                ],
            },
            {
                "taskName": "someone_elses_task",
                "type": "MTT",
                "runId": 3,
                "startTimeUtc": _ago(2),
                "executionState": "QUEUED",
            },
        ]
    if _bump("cdi") < 2:
        return [{"runId": 7, "taskId": "T1", "executionState": "RUNNING"}]
    return []


@app.get("/saas/api/v2/activity/activityLog")
def activity_log(rowLimit: int | None = None) -> list[dict[str, Any]]:  # noqa: N803 (IDMC name)
    if rowLimit is not None:  # Monitor tab history
        return [
            {
                "objectName": "mt_load_customers",
                "type": "MTT",
                "runId": 40,
                "state": 1,
                "startTimeUtc": _ago(65),
                "endTimeUtc": _ago(52),
                "successSourceRows": 120000,
                "successTargetRows": 119990,
                "failedTargetRows": 10,
                "errorMsg": "No errors encountered.",
                "startedBy": "VVamsi-IDMCDev",
                "runContextType": "SCHEDULER",
            },
            {
                "objectName": "tf_load_all",
                "type": "WORKFLOW",
                "runId": 39,
                "state": 3,
                "startTimeUtc": _ago(180),
                "endTimeUtc": _ago(171),
                "errorMsg": "Step mt_load_customers failed",
                "startedBy": "VVamsi-IDMCDev",
                "runContextType": "UI",
                "entries": [
                    {
                        "objectName": "mt_load_customers",
                        "type": "MTT",
                        "runId": 38,
                        "state": 3,
                        "startTimeUtc": _ago(180),
                        "endTimeUtc": _ago(171),
                        "errorMsg": "Target table missing",
                    },
                ],
            },
            {
                "objectName": "someone_elses_task",
                "type": "MTT",
                "runId": 2,
                "state": 1,
                "startTimeUtc": _ago(30),
                "endTimeUtc": _ago(29),
            },
        ][:rowLimit]
    return [
        {
            "state": 1,
            "successSourceRows": 120,
            "successTargetRows": 118,
            "failedTargetRows": 2,
            "endTimeUtc": "2026-11-22T12:00:00Z",
        }
    ]


@app.post("/job/public/api/v1/search")
def job_search() -> dict[str, Any]:
    return {
        "totalPages": 1,
        "jobInstances": [
            {"jobType": "c360.ingress.load", "jobDefinition": {"id": "ingress_person"}},
            {"jobType": "c360.egress.export", "jobDefinition": {"id": "egress_person"}},
        ],
    }


@app.post("/job/public/api/v1/jobInstance/{kind}")
def run_mdm(kind: str) -> dict[str, Any]:
    return {"id": f"JI-{kind}"}


@app.get("/job/public/api/v1/jobInstance/{instance_id}")
def read_instance(instance_id: str) -> dict[str, Any]:
    done = _bump(instance_id) >= 2
    return {
        "id": instance_id,
        "jobLevelMetrics": [
            {"id": "NUM_OF_INCOMING_RECORDS", "value": 1000},
            {"id": "NUM_OF_REC_FAILED", "value": 3},
            {"id": "NUM_OF_REC_LOAD_CREATED", "value": 997},
            {"id": "NUM_OF_REC_LOAD_FAILED", "value": 3},
        ],
        "_meta": {
            "state": "SUCCESS" if done else "RUNNING",
            "startedAt": 1763800000000,
            "completedAt": 1763800300000 if done else None,
        },
    }
