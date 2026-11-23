"""A tiny fake IDMC for local demos and smoke tests. Not used in production.

Run:  uvicorn dev.fake_idmc:app --port 8900
Then start the backend with IDMC_LOGIN_URL=http://127.0.0.1:8900,
IDMC_MDM_URL=http://127.0.0.1:8900 and IDMC_PLATFORM_URL=http://127.0.0.1:8900/saas.
Jobs finish SUCCESS on the second status check.
Advanced taskflow tf_demo_advanced (POST /active-bpel/rt/tf_demo_advanced) returns runId
900000000000000001: RUNNING on the first status check, SUCCESS with two child tasks after.
Run id 900000000000000002 is a SUSPENDED run with a failed child (a real failure shape).
Run id 900000000000000003 stays RUNNING until PUT /active-bpel/services/tf/terminate.
Session logs: /saas/api/v2/activity/activityLog/<id>/sessionLog.
The Monitor tab calls (activityMonitor?details=true, activityLog?rowLimit=N) get a fixed
demo set: one running taskflow with two child steps, plus a few finished runs.
B360 job search returns a fixed set incl. 800000000000007984, RUNNING, started from the
portal by another user (for the Business 360 Currently running view); status filters apply.
B360 Data: metadata tenantModel/datamodel lists c360.person, c360.organization, zlv_guest;
objects/businessEntity/<guid> gives fields + field groups; search returns 12 records each.
Design (0.9.15): v3 objects for MTT / TASKFLOW / WORKFLOW / DTEMPLATE / DSS carry updateTime /
updatedBy; objects/<id>/references (FED4 taskflow uses FED5 mapping task; FED5 uses MAP5 + a
connection); v2 mttask (frs/<id>, <id>), mapping (<id>, search?name=), runtimeEnvironment (laptop
+ Cloud Hosted Agent), connection (one Oracle row WITH fake secrets, to prove they never show).
"""

import json
import time
from datetime import UTC, datetime, timedelta
from typing import Annotated, Any

from fastapi import Body, FastAPI, Query, Response
from fastapi.responses import JSONResponse, PlainTextResponse

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
        return {"objects": [_DESIGN_OBJECTS["FED1"], _DESIGN_OBJECTS["FED5"]]}
    if "TASKFLOW" in q:
        return {"objects": [_DESIGN_OBJECTS["FED3"], _DESIGN_OBJECTS["FED4"]]}
    if "WORKFLOW" in q:
        return {"objects": [_DESIGN_OBJECTS["FED2"]]}
    if "DTEMPLATE" in q:
        # 0.9.17: two product-style mappings the own-name rule ("m_", exact case) must hide.
        return {
            "objects": [_DESIGN_OBJECTS["MAP5"], _DESIGN_OBJECTS["MAP8"], _DESIGN_OBJECTS["MAP9"]]
        }
    if "DSS" in q:
        return {"objects": [_DESIGN_OBJECTS["DSS1"]]}
    return {"objects": []}


# ---- 0.9.15 Design notebook: v3 rows, references, v2 mttask / mapping / runtime / connection ----
# Shapes follow the IICS REST API Reference (Nov 2025). Ids and names are made up.


def _obj(oid: str, path: str, kind: str, by: str, when: str, desc: str = "") -> dict[str, Any]:
    return {
        "id": oid,
        "path": path,
        "type": kind,
        "description": desc,
        "updatedBy": by,
        "updateTime": when,
        "tags": [],
    }


_DESIGN_OBJECTS: dict[str, dict[str, Any]] = {
    "FED1": _obj("FED1", "Default/mt_load_customers", "MTT", "fake.dev", "2026-11-20T15:00:00Z"),
    # The child mapping task of tf_MDM_ZLV_TTF_Guest_Basic_EGR (FED4), on the laptop agent group.
    "FED5": _obj(
        "FED5",
        "ZL_Vamsi/ZLV_CDI/mt_m_MDM_ZLV_TTF_Guest_Basic_EGR",
        "MTT",
        "VVamsi-idmcdev",
        "2026-11-22T21:30:00Z",
        "Guest egress to STAGING",
    ),
    "FED2": _obj("FED2", "Default/tf_load_all", "WORKFLOW", "fake.dev", "2026-11-19T10:00:00Z"),
    "FED3": _obj(
        "FED3", "Default/tf_demo_advanced", "TASKFLOW", "fake.dev", "2026-11-18T09:00:00Z"
    ),
    # A long real-style name + folder, for the full-width layout check (0.8.0).
    "FED4": _obj(
        "FED4",
        "ZL_Vamsi/ZLV_CDI/tf_MDM_ZLV_TTF_Guest_Basic_EGR",
        "TASKFLOW",
        "VVamsi-idmcdev",
        "2026-11-22T21:40:00Z",
    ),
    "MAP5": _obj(
        "MAP5",
        "ZL_Vamsi/ZLV_CDI/m_MDM_ZLV_TTF_Guest_Basic_EGR",
        "DTEMPLATE",
        "VVamsi-idmcdev",
        "2026-11-22T21:20:00Z",
    ),
    # 0.9.17: shipped with the product (his live org lists infacore_* etc.) and an upper-case
    # "M_" name; both hidden by the own-name rule.
    "MAP8": _obj(
        "MAP8", "Add-On Bundles/infacore_parse_name", "DTEMPLATE", "system", "2025-01-01T00:00:00Z"
    ),
    "MAP9": _obj("MAP9", "Default/M_Upper_Case", "DTEMPLATE", "fake.dev", "2026-11-01T00:00:00Z"),
    "DSS1": _obj("DSS1", "Default/dss_copy_guests", "DSS", "fake.dev", "2026-11-10T08:00:00Z"),
}

_V2_RUNTIME = [
    {
        "id": "01000025000000000003",
        "orgId": "fakeorg",
        "name": "laptop",
        "description": "Secure Agent group on len23",
        "createTime": "2026-10-01T12:00:00.000Z",
        "updateTime": "2026-11-15T12:00:00.000Z",
        "createdBy": "VVamsi-idmcdev",
        "updatedBy": "VVamsi-idmcdev",
        "agents": [{"id": "01000008000000000002", "name": "len23"}],
        "isShared": False,
        "federatedId": "RE1",
    },
    {
        "id": "01000025000000000001",
        "orgId": "fakeorg",
        "name": "Informatica Cloud Hosted Agent",
        "description": "",
        "createTime": "2026-09-01T12:00:00.000Z",
        "updateTime": "2026-09-01T12:00:00.000Z",
        "createdBy": "system",
        "updatedBy": "system",
        "agents": [],
        "isShared": True,
        "federatedId": "RE0",
    },
]

_V2_MTTASK: dict[str, dict[str, Any]] = {
    # key = v3 (federated) id; "id" = v2 id (the appContextId of a reference)
    "FED1": {
        "id": "0100000Z000000000001",
        "name": "mt_load_customers",
        "description": "",
        "createTime": "2026-11-01T10:00:00.000Z",
        "updateTime": "2026-11-20T15:00:00.000Z",
        "createdBy": "fake.dev",
        "updatedBy": "fake.dev",
        "agentId": "01000008000000000001",
        "runtimeEnvironmentId": "01000025000000000001",
        "mappingId": "0100001700000000000A",
    },
    "FED5": {
        "id": "0100000Z000000000005",
        "name": "mt_m_MDM_ZLV_TTF_Guest_Basic_EGR",
        "description": "Guest egress to STAGING",
        "createTime": "2026-11-14T18:05:00.000Z",
        "updateTime": "2026-11-22T21:30:00.000Z",
        "createdBy": "VVamsi-idmcdev",
        "updatedBy": "VVamsi-idmcdev",
        "agentId": "01000008000000000002",
        "runtimeEnvironmentId": "01000025000000000003",
        "mappingId": "01000017000000000005",
        "parameters": [],
    },
}

_V2_MAPPING: dict[str, dict[str, Any]] = {
    "01000017000000000005": {
        "id": "01000017000000000005",
        "name": "m_MDM_ZLV_TTF_Guest_Basic_EGR",
        "description": "",
        "createTime": "2026-11-14T17:50:00.000Z",
        "updateTime": "2026-11-22T21:20:00.000Z",
        "createdBy": "VVamsi-idmcdev",
        "updatedBy": "VVamsi-idmcdev",
        "valid": True,
        "tasks": 1,
    },
}

_V2_CONNECTION = [
    {
        "id": "0100000B000000000002",
        "orgId": "fakeorg",
        "name": "ORA_STAGING",
        "description": "Oracle STAGING schema",
        "createTime": "2026-10-02T12:00:00.000Z",
        "updateTime": "2026-11-12T12:00:00.000Z",
        "createdBy": "VVamsi-idmcdev",
        "updatedBy": "VVamsi-idmcdev",
        "agentId": "01000008000000000002",
        "runtimeEnvironmentId": "01000025000000000003",
        "type": "Oracle",
        "host": "db.example.invalid",
        "database": "ORCL",
        "port": 1521,
        "username": "fake_user",
        "password": "fake-secret-must-never-show",
        "securityToken": "fake-token-must-never-show",
        "federatedId": "CON2",
    },
]

_REFS_USES: dict[str, list[dict[str, Any]]] = {
    "FED4": [
        {
            "id": "FED5",
            "appContextId": "0100000Z000000000005",
            "path": "ZL_Vamsi/ZLV_CDI/mt_m_MDM_ZLV_TTF_Guest_Basic_EGR",
            "type": "MTT",
            "description": "Guest egress to STAGING",
            "updateTime": "2026-11-22T21:30:00Z",
        }
    ],
    "FED5": [
        {
            "id": "MAP5",
            "appContextId": "01000017000000000005",
            "path": "ZL_Vamsi/ZLV_CDI/m_MDM_ZLV_TTF_Guest_Basic_EGR",
            "type": "DTEMPLATE",
            "description": "",
            "updateTime": "2026-11-22T21:20:00Z",
        },
        {
            "id": "CON2",
            "appContextId": "0100000B000000000002",
            "path": "ORA_STAGING",
            "type": "Connection",
            "description": "Oracle STAGING schema",
            "updateTime": "2026-11-12T12:00:00Z",
        },
    ],
}
_REFS_USED_BY: dict[str, list[dict[str, Any]]] = {"MAP5": [_REFS_USES["FED4"][0]]}


@app.get("/saas/public/core/v3/objects/{object_id}/references")
def references(
    object_id: str,
    refType: str = "Uses",  # noqa: N803 (IDMC name)
    limit: int = 25,
    skip: int = 0,
) -> dict[str, Any]:
    table = _REFS_USED_BY if refType.lower() == "usedby" else _REFS_USES
    rows = table.get(object_id, [])[skip : skip + limit]
    return {"id": object_id, "count": len(rows), "references": rows}


def _not_found(what: str) -> JSONResponse:
    return JSONResponse(
        status_code=404, content={"error": {"code": "NotFound", "description": what}}
    )


@app.get("/saas/api/v2/mttask/frs/{federated_id}", response_model=None)
def mttask_frs(federated_id: str) -> dict[str, Any] | JSONResponse:
    task = _V2_MTTASK.get(federated_id)
    return task if task is not None else _not_found(f"mttask frs {federated_id}")


@app.get("/saas/api/v2/mttask/{task_id}", response_model=None)
def mttask_id(task_id: str) -> dict[str, Any] | JSONResponse:
    task = next((t for t in _V2_MTTASK.values() if t["id"] == task_id), None)
    return task if task is not None else _not_found(f"mttask {task_id}")


@app.get("/saas/api/v2/mapping/search", response_model=None)
def mapping_search(name: str) -> dict[str, Any] | JSONResponse:
    found = next((m for m in _V2_MAPPING.values() if m["name"] == name), None)
    return found if found is not None else _not_found(f"mapping {name}")


@app.get("/saas/api/v2/mapping/{mapping_id}", response_model=None)
def mapping_id(mapping_id: str) -> dict[str, Any] | JSONResponse:
    found = _V2_MAPPING.get(mapping_id)
    return found if found is not None else _not_found(f"mapping {mapping_id}")


@app.get("/saas/api/v2/runtimeEnvironment")
def runtime_environments() -> list[dict[str, Any]]:
    return _V2_RUNTIME


@app.get("/saas/api/v2/connection")
def connections() -> list[dict[str, Any]]:
    return _V2_CONNECTION


@app.get("/saas/api/v2/connection/{connection_id}", response_model=None)
def connection(connection_id: str) -> dict[str, Any] | JSONResponse:
    found = next((c for c in _V2_CONNECTION if c["id"] == connection_id), None)
    return found if found is not None else _not_found(f"connection {connection_id}")


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
        ][:rowLimit] + TF_LOG_ROWS
    return [
        {
            "state": 1,
            "successSourceRows": 120,
            "successTargetRows": 118,
            "failedTargetRows": 2,
            "endTimeUtc": "2026-11-22T12:00:00Z",
        }
    ]


# B360 job instances. PORTAL_RUNNING was started from the portal by another user (not by this
# app) and stays RUNNING, so "Currently running" must list it. The others are finished.
PORTAL_RUNNING = "800000000000007984"
_NOW_MS = int(datetime.now(tz=UTC).timestamp() * 1000)
_B360_INSTANCES: list[dict[str, Any]] = [
    {
        "id": PORTAL_RUNNING,
        "name": "zlv_ingr_guest_basic",
        "jobType": "b360.ingress.load",
        "jobDefinition": {"id": "ingress_person"},
        "jobLevelMetrics": None,
        "_meta": {
            "state": "RUNNING",
            "startedAt": _NOW_MS - 4 * 60_000,
            "startedBy": "someone.else",
            "completedAt": None,
            "isCompleted": False,
        },
    },
    {
        "id": "800000000000002720",
        "name": "egress_person",
        "jobType": "c360.egress.etl",
        "jobDefinition": {"id": "egress_person"},
        "jobLevelMetrics": [{"id": "NUM_OF_INCOMING_RECORDS", "value": 21}],
        "_meta": {
            "state": "SUCCESS",
            "startedAt": _NOW_MS - 30 * 60_000,
            "completedAt": _NOW_MS - 28 * 60_000,
            "startedBy": "vvamsi-idmcdev",
            "isCompleted": True,
        },
    },
    {
        "id": "800000000000001111",
        "name": "ingress_person",
        "jobType": "c360.ingress.load",
        "jobDefinition": {"id": "ingress_person"},
        "jobLevelMetrics": None,
        "_meta": {
            "state": "FAILED",
            "startedAt": _NOW_MS - 90 * 60_000,
            "completedAt": _NOW_MS - 89 * 60_000,
            "startedBy": "vvamsi-idmcdev",
            "isCompleted": True,
        },
    },
    {  # console upload: not a b360./c360. type, so it is counted but not listed
        "id": "800000000000000555",
        "name": "fileImport",
        "jobType": "internal.c360.ingress.fileImportJob",
        "jobDefinition": {"id": "internal.c360.ingress.fileImportJob"},
        "_meta": {"state": "RUNNING", "startedAt": _NOW_MS - 60_000, "startedBy": "console"},
    },
]


@app.post("/job/public/api/v1/search")
def job_search(body: dict[str, Any] = Body(default_factory=dict)) -> dict[str, Any]:  # noqa: B008
    items = list(_B360_INSTANCES)
    wanted = [
        str(f.get("fieldValue"))
        for f in ((body.get("filters") or {}).get("filter") or [])
        if f.get("fieldName") == "status"
    ]
    if wanted:
        items = [i for i in items if i["_meta"]["state"] in wanted]
    size = int(body.get("pageSize") or 25)
    return {
        "totalRecords": len(items),
        "totalPages": 1,
        "currentPage": 0,
        "jobInstances": items[:size],
    }


@app.post("/job/public/api/v1/jobInstance/{kind}")
def run_mdm(kind: str) -> dict[str, Any]:
    # A fresh instance id per start, so every run shows RUNNING first, then SUCCESS.
    return {"id": f"JI-{kind}-{_bump('mdm-start-' + kind)}"}


@app.get("/job/public/api/v1/jobInstance/{instance_id}", response_model=None)
def read_instance(instance_id: str) -> dict[str, Any] | JSONResponse:
    known = next((i for i in _B360_INSTANCES if i["id"] == instance_id), None)
    if known is not None:
        return known
    if not instance_id.startswith("JI-"):
        return JSONResponse(
            status_code=404, content={"error": f"job instance {instance_id} not found"}
        )
    done = _bump(instance_id) >= 2
    return {
        "id": instance_id,
        "jobType": "c360.ingress.load",
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


# ---- advanced taskflows -------------------------------------------------------------------

TF_OK = "900000000000000001"
TF_BAD = "900000000000000002"
TF_LONG = "900000000000000003"  # RUNNING until terminated, then FAILED


@app.post("/active-bpel/rt/{api_name}")
def run_taskflow(api_name: str) -> dict[str, Any]:
    return {"RunId": TF_OK}


def _child(
    name: str, run_id: str, status: str, ok: int, bad: int, error: str = ""
) -> dict[str, Any]:
    return {
        "assetName": name,
        "assetType": "MTT",
        "duration": "42",
        "startTime": _ago(6),
        "endTime": _ago(5),
        "errorMessage": error,
        "errorRows": str(bad),
        "location": "Default",
        "rowsProcessed": str(ok + bad),
        "runId": run_id,
        "startedBy": "VVamsi-idmcdev",
        "status": status,
        "subtasks": "0",
        "successRows": str(ok),
        "updateTime": _ago(5),
    }


@app.get("/active-bpel/services/tf/status/{run_id}")
def taskflow_status(run_id: str, subtaskDetails: str = "No") -> dict[str, Any]:  # noqa: N803
    base = {
        "assetName": "tf_demo_advanced",
        "assetType": "TASKFLOW",
        "location": "Default",
        "runId": int(run_id) if run_id.isdigit() else run_id,
        "runtimeEnv": "tf_runtime",
        "startTime": _ago(7),
        "startedBy": "VVamsi-idmcdev",
        "updateTime": _ago(4),
    }
    if run_id == TF_LONG and run_id not in TERMINATED:
        return base | {"status": "RUNNING", "subtasks": 1, "subtaskDetails": {"details": {}}}
    if run_id == TF_LONG:
        # Same shape as seen live 2026-11-22 23:21 CST after a terminate.
        child_error = "The job was stopped by user vvamsi-idmcdev using the API."
        tasks = [_child("mt_demo_load", "14", "STOPPED", 10, 0, child_error)]
        return base | {
            "status": "FAILED",
            "errorMessage": json.dumps(
                {
                    "reason": '"Manual Process Termination"',
                    "code": "processManuallyTerminated",
                    "details": "",
                }
            ),
            "subtasks": 1,
            "subtaskDetails": {"details": {"tasks": tasks}},
        }
    if run_id == TF_OK and _bump(run_id) == 1:
        return base | {"status": "RUNNING", "subtasks": 2, "subtaskDetails": {"details": {}}}
    if run_id == TF_OK:
        tasks = [
            _child("mt_demo_load", "11", "COMPLETED", 1200, 3),
            _child("mt_demo_stage", "12", "COMPLETED", 1197, 0),
        ]
        return base | {
            "status": "SUCCESS",
            "endTime": _ago(4),
            "duration": "180",
            "errorMessage": "",
            "subtasks": 2,
            "subtaskDetails": {"details": {"tasks": tasks}},
        }
    if run_id == TF_BAD:
        error = "[FATAL] Invalid/Default JobInstanceId is passed as runtime parameter"
        tasks = [_child("mt_demo_load", "13", "FAILED", 0, 0, error)]
        return base | {
            "status": "SUSPENDED",
            "errorMessage": error,
            "subtasks": 1,
            "subtaskDetails": {"details": {"tasks": tasks}},
        }
    return {"status": "No status available."}


TF_LOG_ROWS: list[dict[str, Any]] = [
    {
        "id": "LOG11",
        "objectName": "mt_demo_load",
        "runId": 11,
        "state": 1,
        "successSourceRows": 1203,
        "failedSourceRows": 0,
        "successTargetRows": 1200,
        "failedTargetRows": 3,
    },
    {
        "id": "LOG12",
        "objectName": "mt_demo_stage",
        "runId": 12,
        "state": 1,
        "successSourceRows": 1197,
        "successTargetRows": 1197,
        "failedTargetRows": 0,
    },
    {
        "id": "LOG13",
        "objectName": "mt_demo_load",
        "runId": 13,
        "state": 3,
        "errorMsg": "[FATAL] Invalid/Default JobInstanceId is passed as runtime parameter",
    },
]


@app.get("/saas/api/v2/activity/activityLog/{log_id}/sessionLog", response_class=PlainTextResponse)
def session_log(log_id: str) -> str:
    return (
        f"Session log for {log_id}\n"
        "READER_1_1_1> Reading rows from source...\n"
        "WRITER_1_*_1> Committed 1200 rows, rejected 3.\n"
    )


TERMINATED: set[str] = set()


@app.put("/active-bpel/services/tf/terminate", response_model=None)
def terminate(body: dict[str, Any] = Body(...)) -> Response:  # noqa: B008
    ids = [str(i) for i in body.get("runid", [])]
    known = {TF_OK, TF_BAD, TF_LONG}
    if not ids or any(i not in known for i in ids):
        return JSONResponse({"error": "Invalid run id(s): " + ", ".join(ids)}, status_code=500)
    TERMINATED.update(ids)
    return Response(status_code=204)


# ---- B360 Data notebook: metadata + search (documented JSON style, see app/b360data) --------

_CORE = "http://informatica.com/mdm/v2/Core#//"


def _f(name: str, label: str, kind: str = "TextField", searchable: bool = False) -> dict[str, Any]:
    return {
        "eClass": _CORE + kind,
        "name": name,
        "label": {"eClass": _CORE + "LocalizedText", "en": label},
        "allowMany": False,
        "options": {"eClass": _CORE + "FieldOptions", "searchable": searchable},
    }


def _fg(name: str, label: str, fields: list[dict[str, Any]]) -> dict[str, Any]:
    return {
        "eClass": _CORE + "FieldGroup",
        "name": name,
        "label": {"eClass": _CORE + "LocalizedText", "en": label},
        "allowMany": True,
        "field": fields,
    }


_B360_ENTITIES: dict[str, dict[str, Any]] = {
    "c360.person": {
        "eClass": _CORE + "BusinessEntity",
        "guid": "c360.person",
        "name": "Person",
        "label": {"eClass": _CORE + "LocalizedText", "en": "Person"},
        "field": [
            _f("firstName", "First Name", searchable=True),
            _f("lastName", "Last Name", searchable=True),
            _f("gender", "Gender", "LookupField"),
            _f("designation", "Designation"),
            _fg(
                "PostalAddress",
                "Postal Address",
                [
                    _f("addressLine1", "Address Line 1"),
                    _f("city", "City"),
                    _f("state", "State", "LookupField"),
                    _f("postalCode", "Postal Code"),
                ],
            ),
            _fg("Phone", "Phone", [_f("phoneNumber", "Phone Number")]),
            _fg("Email", "Email", [_f("emailAddress", "Email Address")]),
        ],
    },
    "c360.organization": {
        "eClass": _CORE + "BusinessEntity",
        "guid": "c360.organization",
        "name": "Organization",
        "label": {"eClass": _CORE + "LocalizedText", "en": "Organization"},
        "field": [
            _f("organizationName", "Organization Name", searchable=True),
            _f("companyType", "Company Type", "LookupField"),
            _fg(
                "PostalAddress",
                "Postal Address",
                [_f("city", "City"), _f("postalCode", "Postal Code")],
            ),
        ],
    },
    "zlv_guest": {
        "eClass": _CORE + "BusinessEntity",
        "guid": "zlv_guest",
        "name": "Guest",
        "label": {"eClass": _CORE + "LocalizedText", "en": "ZLV Guest"},
        "field": [
            _f("guestId", "Guest Id", searchable=True),
            _f("fullName", "Full Name", searchable=True),
            _f("first_name", "First Name", searchable=True),
            _f("last_name", "Last Name", searchable=True),
            _f("clns_first_name", "Clns First Name"),
            _f("clns_last_name", "Clns Last Name"),
            _fg("Stay", "Stays", [_f("hotel", "Hotel"), _f("nights", "Nights", "IntegerField")]),
            # like his live x_phone (read 2026-11-23 01:40 CST): MANY, 2 integers, picklist, bool
            _fg(
                "x_phone",
                "Phone",
                [
                    _f("cntry_cd", "Country code", "IntegerField"),
                    _f("ph_num", "Phone number", "IntegerField"),
                    # 0.9.12: names its Reference 360 list with the attribute the reference
                    # documents for picklist fields (lookupCodeList, pp. 148-150). The live
                    # attribute name is UNVERIFIED until his Metadata (M) shows raw keys.
                    {
                        **_f("ph_typ", "Phone type", "LookupField"),
                        "lookupCodeList": "Enterprise PhoneType",
                    },
                    _f("no_mrkt_calls", "No marketing calls", "BooleanField"),
                ],
            ),
        ],
    },
}

# 0.9.12 Reference 360 value entities, like his live org (read 2026-11-23 02:27 CST via his
# backend): rdm.value.be._ent_phonetype, label "RDM values of list Enterprise PhoneType",
# fields Name / Code, these 11 codes.
_RDM_PHONETYPE = "rdm.value.be._ent_phonetype"
_RDM_PHONETYPE_CODES = [
    "VoIP", "Cell", "Contaminated", "Fax", "Freephone", "LandLine",
    "Marine", "Mobile", "Pager", "Special", "Telephone",
]  # fmt: skip
_B360_ENTITIES[_RDM_PHONETYPE] = {
    "eClass": _CORE + "BusinessEntity",
    "guid": _RDM_PHONETYPE,
    "name": "_ent_phonetype",
    "label": {"eClass": _CORE + "LocalizedText", "en": "RDM values of list Enterprise PhoneType"},
    "field": [_f("Name", "Name", searchable=True), _f("Code", "Code", searchable=True)],
}
RDM_SEARCHES: list[str] = []  # entityType of each rdm.* search received, for tests


_BASE_UPDATE_MS = 1_793_491_200_000  # 2026-11-01T00:00:00Z


def _fake_records(guid: str) -> list[dict[str, Any]]:
    prefix = guid.replace(".", "")
    rows: list[dict[str, Any]] = []
    for i in range(1, 13):
        meta = {
            "businessId": f"3000000000000000000000{i:05d}",
            "businessEntity": guid,
            "status": "ACTIVE",
            # epoch ms as a string, like the reference sample (p. 27); record i updated i hours
            # after 2026-11-01 so newest-first order is 12, 11, ... 1.
            "lastUpdateDate": str(_BASE_UPDATE_MS + i * 3_600_000),
            "updatedBy": "fake.loader",
        }
        if guid == _RDM_PHONETYPE:
            if i <= len(_RDM_PHONETYPE_CODES):
                code = _RDM_PHONETYPE_CODES[i - 1]
                rows.append({"_meta": meta, f"{prefix}.Code": code, f"{prefix}.Name": code})
        elif guid == "c360.person":
            rows.append(
                {
                    "_meta": meta,
                    f"{prefix}.firstName": f"First{i}",
                    f"{prefix}.lastName": f"Last{i}",
                    f"{prefix}.gender": {"Name": "Female" if i % 2 else "Male"},
                    f"{prefix}.designation": "Analyst",
                    f"{prefix}.PostalAddress": [
                        {
                            "addressLine1": f"{i} Main St",
                            "city": "Austin",
                            "state": {"Name": "Texas"},
                            "postalCode": "78701",
                        }
                    ],
                    f"{prefix}.Phone": [
                        {"phoneNumber": f"512-555-{i:04d}"},
                        {"phoneNumber": f"737-555-{i:04d}"},
                    ],
                    f"{prefix}.Email": [{"emailAddress": f"p{i}@example.com"}],
                }
            )
        elif guid == "c360.organization":
            rows.append(
                {
                    "_meta": meta,
                    f"{prefix}.organizationName": f"Org {i}",
                    f"{prefix}.companyType": {"Name": "Chartered"},
                    f"{prefix}.PostalAddress": [{"city": "Dallas", "postalCode": "75201"}],
                }
            )
        else:
            rows.append(
                {
                    "_meta": meta,
                    f"{prefix}.guestId": f"G{i:03d}",
                    f"{prefix}.fullName": f"Guest {i}",
                    f"{prefix}.first_name": ["Anna", "Ben", "Carla"][i % 3] + str(i),
                    f"{prefix}.last_name": "Smith" if i % 2 else "Jones",
                    f"{prefix}.clns_first_name": (["Anna", "Ben", "Carla"][i % 3] + str(i)).upper(),
                    f"{prefix}.clns_last_name": "SMITH" if i % 2 else "JONES",
                    f"{prefix}.Stay": [{"hotel": "Leander Inn", "nights": i}],
                    # FAKE picklist codes (fake IDMC only): odd records have a phone row
                    **(
                        {
                            f"{prefix}.x_phone": [
                                {
                                    "_id": f"ph{i:03d}",
                                    "cntry_cd": 1,
                                    "ph_num": 5125550000 + i,
                                    "ph_typ": (
                                        {"Code": "MOB", "Name": "Mobile"}
                                        if i % 3
                                        else {"Code": "HOME", "Name": "Home"}
                                    ),
                                    "no_mrkt_calls": False,
                                }
                            ]
                        }
                        if i % 2
                        else {}
                    ),
                }
            )
    return rows


@app.get("/metadata/api/v2/objects/tenantModel/datamodel")
def datamodel() -> dict[str, Any]:
    return {"eClass": _CORE + "TenantModel", "businessEntity": list(_B360_ENTITIES.values())}


@app.get("/metadata/api/v2/objects/businessEntity/{guid}", response_model=None)
def business_entity(guid: str) -> dict[str, Any] | JSONResponse:
    if guid not in _B360_ENTITIES:
        return JSONResponse(status_code=404, content={"message": f"unknown entity {guid}"})
    return _B360_ENTITIES[guid]


def _all_records(guid: str) -> list[dict[str, Any]]:
    """Seed + created records, minus merged-away ones, with master overrides (0.9.12) applied."""
    if guid not in _B360_ENTITIES:
        return []
    prefix = guid.replace(".", "")
    out: list[dict[str, Any]] = []
    for record in _fake_records(guid) + _CREATED.get(guid, []):
        bid = record.get("_meta", {}).get("businessId")
        if (guid, bid) in _MERGED_INTO:
            continue
        edits = _MASTER_EDITS.get((guid, bid))
        if edits:
            record = {**record, **{f"{prefix}.{k}": v for k, v in edits.items()}}
            record = {k: v for k, v in record.items() if v is not _REMOVED}
        out.append(record)
    return out


# ---- 0.9.12 Merge (M) state -----------------------------------------------------------------
_MERGED_INTO: dict[tuple[str, str], str] = {}  # (guid, merged-away id) -> surviving id
_MASTER_EDITS: dict[tuple[str, str], dict[str, Any]] = {}
_REMOVED = object()
MERGES: list[list[dict[str, Any]]] = []  # Merge API bodies received, for tests
MASTER_PATCHES: list[dict[str, Any]] = []  # {"business_id", "sourceSystem", "body"}
UNMERGES: list[dict[str, Any]] = []
APPROVAL_REQUIRED = {"merge": False}  # tests flip it to see the approval path


def _matches(record: dict[str, Any], flt: dict[str, Any]) -> bool:
    value = str(record.get(str(flt.get("fieldName")), "") or "").lower()
    wanted = str(flt.get("fieldValue") or "").lower()
    match str(flt.get("comparator")):
        case "STARTS_WITH":
            return value.startswith(wanted)
        case "EQUALS":
            return value == wanted
        case _:
            return True


@app.post("/search/public/api/v1/search")
def be_search(body: dict[str, Any] = Body(default_factory=dict)) -> dict[str, Any]:  # noqa: B008
    """Honours recordOffset / recordsToReturn, filters (STARTS_WITH, EQUALS, case-insensitive)
    and a sort on _meta.lastUpdateDate, the way the 0.9.9 Records page sends them."""
    guid = str(body.get("entityType") or "")
    if guid.startswith("rdm."):
        RDM_SEARCHES.append(guid)
    records = _all_records(guid)
    filters = body.get("filters") or {}
    for flt in filters.get("filter", []) if isinstance(filters, dict) else []:
        records = [r for r in records if _matches(r, flt)]
    for item in body.get("sort") or []:
        if item.get("fieldName") == "_meta.lastUpdateDate":
            records = sorted(
                records,
                key=lambda r: int(r.get("_meta", {}).get("lastUpdateDate") or 0),
                reverse=item.get("order") == "DESCENDING",
            )
    size = int(body.get("recordsToReturn") or body.get("pageSize") or 25)
    offset = int(body.get("recordOffset") or 0)
    return {
        "searchResult": {
            "hits": len(records),
            "pageSize": size,
            "pageOffset": 0,
            "recordOffset": offset,
            "recordsToReturn": size,
            "records": records[offset : offset + size],
        }
    }


@app.get("/business-entity/public/api/v1/entity/{guid}/{business_id}", response_model=None)
def read_master_record(
    guid: str,
    business_id: str,
    show_content_meta: Annotated[bool, Query(alias="_showContentMeta")] = False,
) -> dict[str, Any] | JSONResponse:
    """Read Master Record by Business ID (pp. 56-58): unprefixed field keys + _meta.
    _showContentMeta=true adds _contentMeta.trust.fieldData (p. 19, example shape pp. 56-58)."""
    for record in _all_records(guid):
        if record.get("_meta", {}).get("businessId") == business_id:
            out: dict[str, Any] = {
                **{k.split(".", 1)[1]: v for k, v in record.items() if "." in k},
                "_meta": record["_meta"],
            }
            if show_content_meta:
                n = business_id[-2:]
                when = record["_meta"].get("lastUpdateDate")
                out["_contentMeta"] = {
                    "trust": {
                        "fieldData": [
                            _trust("/", "zlv_ttf", f"TTF-{n}", 0.9, when),
                            _trust("last_name", "zlv_eci", f"ECI-{n}", 0.7, when),
                        ]
                    }
                }
            return out
    return JSONResponse(status_code=404, content={"message": f"no record {business_id}"})


# ---- 0.9.8 Add records ----------------------------------------------------------------------
# Create Master Record (reference pp. 51-55). Created rows are kept in memory and show up in the
# search above, so the Records view refreshes with them. Test hooks by sourcePKey:
# containing "FAIL400" -> 400, containing "RATE429" -> 429.
_CREATED: dict[str, list[dict[str, Any]]] = {}
_FAKE_SOURCE_SYSTEMS = ["c360.default.system", "zlv_ttf", "zlv_eci", "salesforce"]


@app.get("/metadata/api/v2/objects/sourceSystem")
def source_systems() -> dict[str, Any]:
    """Undocumented on the real org (UNVERIFIED); the fake answers in the metadata style."""
    return {
        "content": [
            {"eClass": _CORE + "SourceSystem", "guid": g, "name": g} for g in _FAKE_SOURCE_SYSTEMS
        ]
    }


@app.post("/business-entity/public/api/v1/entity/{guid}", response_model=None)
def create_master_record(
    guid: str,
    sourceSystem: str,  # noqa: N803 - IDMC query parameter name
    sourcePKey: str = "",  # noqa: N803
    body: dict[str, Any] = Body(default_factory=dict),  # noqa: B008
) -> dict[str, Any] | JSONResponse:
    if guid not in _B360_ENTITIES:
        return JSONResponse(status_code=404, content={"message": f"unknown entity {guid}"})
    if "RATE429" in sourcePKey:
        return JSONResponse(status_code=429, content={"message": "Too many requests"})
    if "FAIL400" in sourcePKey or sourceSystem not in _FAKE_SOURCE_SYSTEMS:
        return JSONResponse(status_code=400, content={"message": f"rejected {sourcePKey}"})
    rows = _CREATED.setdefault(guid, [])
    business_id = f"TX{len(rows) + 1:013d}"
    prefix = guid.replace(".", "")
    record: dict[str, Any] = {
        "_meta": {
            "businessId": business_id,
            "businessEntity": guid,
            "lastUpdateDate": str(int(time.time() * 1000)),
            "updatedBy": "tx-mdm",
        }
    }
    record.update({f"{prefix}.{key}": value for key, value in body.items()})
    rows.append(record)
    return {"approvalRequired": False, "id": business_id, "businessId": business_id}


# ---- 0.9.10 source (xref) records ------------------------------------------------------------
# Every fake master record has two source records: zlv_ttf / TTF-<n> and zlv_eci / ECI-<n>.
_XREF_EDITS: dict[tuple[str, str, str], dict[str, Any]] = {}
PATCHES: list[list[dict[str, Any]]] = []  # bodies the fake received, for tests


def _xref_seed(guid: str) -> dict[tuple[str, str, str], dict[str, Any]]:
    out: dict[tuple[str, str, str], dict[str, Any]] = {}
    for record in _all_records(guid):
        meta = record.get("_meta", {})
        bid = str(meta.get("businessId"))
        n = bid[-2:]
        plain = {k.split(".", 1)[1]: v for k, v in record.items() if "." in k}
        for system, pkey in (("zlv_ttf", f"TTF-{n}"), ("zlv_eci", f"ECI-{n}")):
            out[(guid, system, pkey)] = {
                **json.loads(json.dumps(plain)),
                "_meta": {
                    "businessId": bid,
                    "businessEntity": guid,
                    "sourceSystem": system,
                    "sourcePrimaryKey": pkey,
                    "xrefType": "DATA",
                    "lastUpdateDate": meta.get("lastUpdateDate"),
                    "sourceLastUpdatedDate": meta.get("lastUpdateDate"),
                    "creationDate": meta.get("creationDate", meta.get("lastUpdateDate")),
                    "updatedBy": "fake.loader",
                    "states": {"base": "ACTIVE", "consolidation": "CONSOLIDATED"},
                },
            }
    return out


def _xref(guid: str, system: str, pkey: str) -> dict[str, Any] | None:
    key = (guid, system, pkey)
    if key in _XREF_EDITS:
        return _XREF_EDITS[key]
    return _xref_seed(guid).get(key)


@app.get("/business-entity/public/api/v1/entity-member/{guid}/{business_id}", response_model=None)
def entity_members(guid: str, business_id: str) -> dict[str, Any] | JSONResponse:
    """Read Source Records by Master Record (p. 70-71)."""
    members = [
        {"sourcePKey": pkey, "sourceSystem": system}
        for (g, system, pkey), rec in _xref_seed(guid).items()
        if g == guid and rec["_meta"]["businessId"] == business_id
    ]
    if not members:
        return JSONResponse(status_code=404, content={"message": f"no master {business_id}"})
    return {"content": members}


def _trust(ref: str, system: str, pkey: str, score: float, when: Any) -> dict[str, Any]:
    return {
        "fieldRef": ref,
        "lastUpdatedDate": when,
        "manualOverride": False,
        "sourcePrimaryKey": pkey,
        "sourceSystem": system,
        "trustRule": "SourceRanking",
        "trustScore": score,
    }


@app.get("/business-entity/public/api/v1/entity-xref/{guid}/{system}/{pkey}", response_model=None)
def read_source_record(
    guid: str,
    system: str,
    pkey: str,
    show_content_meta: Annotated[bool, Query(alias="_showContentMeta")] = False,
) -> dict[str, Any] | JSONResponse:
    """Read Source Record (pp. 80-84): plain keys, groups with _id, xref _meta."""
    if "RATE429" in pkey:
        return JSONResponse(status_code=429, content={"message": "Too many requests"})
    record = _xref(guid, system, pkey)
    if record is None:
        return JSONResponse(status_code=404, content={"message": f"no source {system}/{pkey}"})
    if show_content_meta:
        score = 0.9 if system == "zlv_ttf" else 0.7
        when = record["_meta"].get("lastUpdateDate")
        return {
            **record,
            "_contentMeta": {"trust": {"fieldData": [_trust("/", system, pkey, score, when)]}},
        }
    return record


def _apply(record: dict[str, Any], op: dict[str, Any]) -> None:
    path = str(op.get("path"))
    kind = op.get("op")
    if "[" in path:
        group, rest = path.split("[", 1)
        row_id, _, field = rest.partition("]")
        rows = record.setdefault(group, [])
        row = next((r for r in rows if r.get("_id") == row_id), None)
        if row is None:
            return
        if not field:
            rows.remove(row)
        elif kind == "remove":
            row.pop(field.lstrip("."), None)
        else:
            row[field.lstrip(".")] = op.get("value")
    elif kind == "add" and isinstance(op.get("value"), list):
        record.setdefault(path, []).extend(op["value"])
    elif kind == "remove":
        record.pop(path, None)
    else:
        record[path] = op.get("value")


@app.patch("/business-entity/public/api/v1/entity-xref/{guid}/{system}/{pkey}", response_model=None)
def update_source_record_field(
    guid: str,
    system: str,
    pkey: str,
    body: list[dict[str, Any]] = Body(default_factory=list),  # noqa: B008
) -> dict[str, Any] | JSONResponse:
    """Update Source Record Field (pp. 88-90): [{op, path, value}]."""
    if "RATE429" in pkey:
        return JSONResponse(status_code=429, content={"message": "Too many requests"})
    record = _xref(guid, system, pkey)
    if record is None:
        return JSONResponse(status_code=404, content={"message": f"no source {system}/{pkey}"})
    record = json.loads(json.dumps(record))
    for op in body:
        _apply(record, op)
    record["_meta"]["lastUpdateDate"] = int(time.time() * 1000)
    _XREF_EDITS[(guid, system, pkey)] = record
    PATCHES.append(body)
    return {"approvalRequired": False}


# ---- 0.9.12 Merge (M) -------------------------------------------------------------------------
# Merge API p. 106, Update Master Record Field pp. 67-68, Unmerge API pp. 107-110. The first id in
# the merge body survives (the real survivor choice is IDMC's; the app always uses the returned
# businessId). Test hooks: a businessId containing "RATE429" -> 429; unknown id -> 400.


def reset_merge_state() -> None:
    _MERGED_INTO.clear()
    _MASTER_EDITS.clear()
    MERGES.clear()
    MASTER_PATCHES.clear()
    UNMERGES.clear()
    APPROVAL_REQUIRED["merge"] = False


@app.post("/business-entity/public/api/v1/entity-group/{guid}", response_model=None)
def merge_records(
    guid: str,
    body: list[dict[str, Any]] = Body(default_factory=list),  # noqa: B008
) -> dict[str, Any] | JSONResponse:
    ids = [str(item.get("businessId")) for item in body]
    if any("RATE429" in i for i in ids):
        return JSONResponse(status_code=429, content={"message": "Too many requests"})
    known = {r.get("_meta", {}).get("businessId") for r in _all_records(guid)}
    if len(ids) < 2 or len(ids) > 10 or any(i not in known for i in ids):
        return JSONResponse(status_code=400, content={"message": f"cannot merge {ids}"})
    MERGES.append(body)
    survivor = ids[0]
    if not APPROVAL_REQUIRED["merge"]:
        for other in ids[1:]:
            _MERGED_INTO[(guid, other)] = survivor
    return {"approvalRequired": APPROVAL_REQUIRED["merge"], "businessId": survivor}


@app.patch("/business-entity/public/api/v1/entity/{guid}/{business_id}", response_model=None)
def update_master_record_field(
    guid: str,
    business_id: str,
    sourceSystem: str,  # noqa: N803 - IDMC query parameter name
    body: list[dict[str, Any]] = Body(default_factory=list),  # noqa: B008
) -> dict[str, Any] | JSONResponse:
    if business_id not in {r.get("_meta", {}).get("businessId") for r in _all_records(guid)}:
        return JSONResponse(status_code=404, content={"message": f"no record {business_id}"})
    edits = _MASTER_EDITS.setdefault((guid, business_id), {})
    for op in body:
        edits[str(op.get("path"))] = _REMOVED if op.get("op") == "remove" else op.get("value")
    MASTER_PATCHES.append({"business_id": business_id, "sourceSystem": sourceSystem, "body": body})
    return {"approvalRequired": False}


@app.post("/business-entity/public/api/v1/entity-group/{guid}/{business_id}", response_model=None)
def unmerge_records(
    guid: str,
    business_id: str,
    _keepRelsWith: str = "REMAINS",  # noqa: N803
    _allowMergeBack: str = "NEVER_MERGE",  # noqa: N803
    body: list[dict[str, Any]] = Body(default_factory=list),  # noqa: B008
) -> dict[str, Any]:
    UNMERGES.append(
        {
            "business_id": business_id,
            "keepRelsWith": _keepRelsWith,
            "allowMergeBack": _allowMergeBack,
            "body": body,
        }
    )
    for key, survivor in list(_MERGED_INTO.items()):
        if key[0] == guid and survivor == business_id:
            del _MERGED_INTO[key]
    return {"approvalRequired": False}
