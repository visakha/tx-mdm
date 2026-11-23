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
"""

import json
import time
from datetime import UTC, datetime, timedelta
from typing import Any

from fastapi import Body, FastAPI, Response
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
        return {"objects": [{"id": "FED1", "path": "Default/mt_load_customers"}]}
    if "TASKFLOW" in q:
        return {
            "objects": [
                {"id": "FED3", "path": "Default/tf_demo_advanced"},
                # A long real-style name + folder, for the full-width layout check (0.8.0).
                {"id": "FED4", "path": "ZL_Vamsi/ZLV_CDI/tf_MDM_ZLV_TTF_Guest_Basic_EGR"},
            ]
        }
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
            _fg("Stay", "Stays", [_f("hotel", "Hotel"), _f("nights", "Nights", "IntegerField")]),
        ],
    },
}


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
        if guid == "c360.person":
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
                    f"{prefix}.Stay": [{"hotel": "Leander Inn", "nights": i}],
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
    return _fake_records(guid) + _CREATED.get(guid, []) if guid in _B360_ENTITIES else []


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
def read_master_record(guid: str, business_id: str) -> dict[str, Any] | JSONResponse:
    """Read Master Record by Business ID (pp. 56-58): unprefixed field keys + _meta."""
    for record in _all_records(guid):
        if record.get("_meta", {}).get("businessId") == business_id:
            return {
                **{k.split(".", 1)[1]: v for k, v in record.items() if "." in k},
                "_meta": record["_meta"],
            }
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
