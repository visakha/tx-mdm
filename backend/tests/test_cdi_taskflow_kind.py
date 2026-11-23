"""Vamsi's MDM / CDI taskflow naming rule (2026-11-23) and the run guard built on it."""

import pytest
import respx
from fastapi.testclient import TestClient

from app.cdi.client import CdiClient
from app.cdi.service import CdiService
from app.cdi.taskflow_kind import TaskDomain, parameter_problem, taskflow_domain
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
