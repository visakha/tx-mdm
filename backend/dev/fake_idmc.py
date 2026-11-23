"""A tiny fake IDMC for local demos and smoke tests. Not used in production.

Run:  uvicorn dev.fake_idmc:app --port 8900
Then start the backend with IDMC_LOGIN_URL=http://127.0.0.1:8900,
IDMC_MDM_URL=http://127.0.0.1:8900 and IDMC_PLATFORM_URL=http://127.0.0.1:8900/saas.
Jobs finish SUCCESS on the second status check.
"""

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
    return {"objects": []}


@app.post("/saas/api/v2/job")
def run_cdi() -> dict[str, Any]:
    return {"runId": 7, "taskId": "T1", "taskType": "MTT"}


@app.get("/saas/api/v2/activity/activityMonitor")
def monitor() -> list[dict[str, Any]]:
    if _bump("cdi") < 2:
        return [{"runId": 7, "taskId": "T1", "executionState": "RUNNING"}]
    return []


@app.get("/saas/api/v2/activity/activityLog")
def activity_log() -> list[dict[str, Any]]:
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
