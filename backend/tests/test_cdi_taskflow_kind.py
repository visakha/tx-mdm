"""Vamsi's MDM / CDI taskflow naming rule (2026-11-23) and the run guard built on it."""

import pytest
import respx
from fastapi.testclient import TestClient

from app.cdi.client import CdiClient, to_cdi_task
from app.cdi.models import CdiTaskType
from app.cdi.service import CdiService
from app.cdi.taskflow_kind import (
    TaskDomain,
    mapping_task_domain,
    parameter_problem,
    taskflow_domain,
)
from app.common.idmc_session import IdmcHttp
from app.common.runs import RunRegistry
from app.dependencies import get_cdi_service
from app.main import create_app
from tests.conftest import PLATFORM


@pytest.mark.parametrize(
    ("name", "domain"),
    [
        ("tf_MDM_ZLV_TTF_Guest_Basic", TaskDomain.MDM),
        ("tf_MDM_ZLV_TTF_Guest_Basic_EGR", TaskDomain.MDM),
        ("x_IGR", TaskDomain.MDM),
        ("tf_something_egr", TaskDomain.MDM),
        ("tf_Ldg_MDM_CDI_TTF", TaskDomain.CDI),
        ("tf_Stg_MDM_CDI_TTF", TaskDomain.CDI),
        ("tf_Stg_orders_EGR", TaskDomain.CDI),
        ("tf_orders", TaskDomain.CDI),
    ],
)
def test_domain_by_name(name: str, domain: TaskDomain) -> None:
    assert taskflow_domain(name) is domain


def test_mdm_taskflow_needs_job_instance_id() -> None:
    assert parameter_problem("tf_MDM_ZLV_TTF_Guest_Basic", None) is not None
    assert parameter_problem("tf_MDM_ZLV_TTF_Guest_Basic", {"jobInstanceId": "  "}) is not None
    assert parameter_problem("tf_MDM_ZLV_TTF_Guest_Basic", {"jobInstanceId": "123"}) is None


def test_cdi_taskflow_refuses_job_instance_id() -> None:
    assert parameter_problem("tf_Stg_MDM_CDI_TTF", {"jobInstanceId": "ABC123"}) is not None
    assert parameter_problem("tf_Stg_MDM_CDI_TTF", {"JOBINSTANCEID": "x"}) is not None
    assert parameter_problem("tf_Stg_MDM_CDI_TTF", None) is None
    assert parameter_problem("tf_Stg_MDM_CDI_TTF", {"other": "x"}) is None


def test_tasks_carry_domain_and_run_guard_never_calls_idmc(
    idmc: respx.MockRouter, idmc_http: IdmcHttp
) -> None:
    objects = {
        "objects": [
            {"id": "A", "path": "F/tf_MDM_ZLV_TTF_Guest_Basic"},
            {"id": "B", "path": "F/tf_Stg_MDM_CDI_TTF"},
        ]
    }
    idmc.get(f"{PLATFORM}/public/core/v3/objects").respond(200, json=objects)
    rt = idmc.post(url__regex=r".*/active-bpel/rt/.*").respond(200, json={"RunId": "1"})
    app = create_app()
    service = CdiService(CdiClient(idmc_http), RunRegistry("cdi"))
    app.dependency_overrides[get_cdi_service] = lambda: service
    client = TestClient(app)
    tasks = client.get("/api/cdi/tasks", params={"types": "TASKFLOW"}).json()
    assert {t["name"]: t["domain"] for t in tasks} == {
        "tf_MDM_ZLV_TTF_Guest_Basic": "mdm",
        "tf_Stg_MDM_CDI_TTF": "cdi",
    }
    missing = client.post("/api/cdi/taskflows/tf_MDM_ZLV_TTF_Guest_Basic/run")
    extra = client.post(
        "/api/cdi/taskflows/tf_Stg_MDM_CDI_TTF/run",
        json={"parameters": {"jobInstanceId": "ABC123"}},
    )
    assert missing.status_code == 400 and "jobInstanceId" in missing.json()["detail"]
    assert extra.status_code == 400 and "CDI taskflow" in extra.json()["detail"]
    assert not rt.called


# ---- 0.9.6: child mapping tasks of the MDM taskflows ---------------------------------------


@pytest.mark.parametrize(
    ("name", "domain"),
    [
        ("mt_m_MDM_ZLV_TTF_Guest_Basic", TaskDomain.MDM),
        ("mt_m_MDM_ZLV_TTF_Guest_Basic_EGR", TaskDomain.MDM),
        ("mt_m_something_IGR", TaskDomain.MDM),
        ("mt_m_Ldg_MDM_CDI_TTF_CLIENTS", TaskDomain.CDI),
        ("mt_m_Stg_MDM_CDI_TTF_SN_DEM_ALL", TaskDomain.CDI),
        ("mt_m_Stg_orders_EGR", TaskDomain.CDI),
    ],
)
def test_mapping_task_domain_by_name(name: str, domain: TaskDomain) -> None:
    assert mapping_task_domain(name) is domain


def test_mdm_mapping_task_tagged_and_never_started_alone(
    idmc: respx.MockRouter, idmc_http: IdmcHttp
) -> None:
    client = CdiClient(idmc_http)
    task = to_cdi_task({"id": "M", "path": "F/mt_m_MDM_ZLV_TTF_Guest_Basic_EGR"}, CdiTaskType.MTT)
    assert task.domain is TaskDomain.MDM
    cdi = to_cdi_task({"id": "C", "path": "F/mt_m_Stg_MDM_CDI_TTF_CLIENTS"}, CdiTaskType.MTT)
    assert cdi.domain is TaskDomain.CDI
    job = idmc.post(url__regex=r".*/api/v2/job$").respond(200, json={"runId": 1})
    app = create_app()
    service = CdiService(client, RunRegistry("cdi"))
    app.dependency_overrides[get_cdi_service] = lambda: service
    body = {"task_id": "M", "task_type": "MTT", "task_name": "mt_m_MDM_ZLV_TTF_Guest_Basic_EGR"}
    reply = TestClient(app).post("/api/cdi/runs", json=body)
    assert reply.status_code == 400
    assert "runs via its taskflow" in reply.json()["detail"]
    assert not job.called
