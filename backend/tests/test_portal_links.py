"""0.9.15 Addendum A: IDMC portal deep links, one typed builder (app/common/portal.py)."""

import respx
from fastapi.testclient import TestClient

from app.cdi.client import CdiClient
from app.cdi.service import CdiService
from app.common.idmc_session import IdmcHttp
from app.common.portal import MTT_RUN_PATH, PortalLinks
from app.common.runs import RunRegistry, RunView
from app.dependencies import get_cdi_service
from app.main import create_app
from app.mdm.client import MdmClient
from app.mdm.monitor import MdmMonitor
from tests.conftest import MDM, PLATFORM
from tests.test_cdi_taskflow_runs import POD, RUN, SUSPENDED

HIS_HOST = "https://usw1-mdm.dm1-us.informaticacloud.com"
HIS_ID = "1309450654674083840"
HIS_SAMPLE = (
    "https://usw1-mdm.dm1-us.informaticacloud.com/ui-config-app/main/jobDetails/1309450654674083840"
)


def test_exactly_his_sample_url() -> None:
    assert PortalLinks(HIS_HOST).mdm_job(HIS_ID) == HIS_SAMPLE
    assert PortalLinks(HIS_HOST + "/").mdm_job(HIS_ID) == HIS_SAMPLE


def test_bad_or_missing_id_gives_no_link() -> None:
    links = PortalLinks(HIS_HOST)
    assert links.mdm_job(None) is None
    assert links.mdm_job("") is None
    assert links.mdm_job("12/../x") is None


CDI_HOST = "https://usw1.dm1-us.informaticacloud.com"
CDI_SAMPLE = (
    "https://usw1.dm1-us.informaticacloud.com/diUI/products/integrationDesign/main/"
    "processinstance/1309453033490374656/tf_Ldg_MDM_CDI_TTF-1309453033490374656%7B%7D"
)


def test_exactly_his_taskflow_sample_url() -> None:
    links = PortalLinks(HIS_HOST, CDI_HOST)
    assert links.cdi_taskflow_run("tf_Ldg_MDM_CDI_TTF", "1309453033490374656") == CDI_SAMPLE
    assert (
        PortalLinks(HIS_HOST, CDI_HOST + "/").cdi_taskflow_run(
            "tf_Ldg_MDM_CDI_TTF", "1309453033490374656"
        )
        == CDI_SAMPLE
    )


def test_taskflow_name_is_path_encoded() -> None:
    url = PortalLinks(HIS_HOST, CDI_HOST).cdi_taskflow_run("tf a/b", "7")
    assert url is not None and url.endswith("/processinstance/7/tf%20a%2Fb-7%7B%7D")


def test_no_taskflow_link_without_host_name_or_good_id() -> None:
    assert PortalLinks(HIS_HOST).cdi_taskflow_run("tf_x", "1") is None
    links = PortalLinks(HIS_HOST, CDI_HOST)
    assert links.cdi_taskflow_run("", "1") is None
    assert links.cdi_taskflow_run("tf_x", None) is None
    assert links.cdi_taskflow_run("tf_x", "1/2") is None


def test_mapping_task_slot_is_empty_until_he_gives_the_pattern() -> None:
    assert MTT_RUN_PATH is None
    assert PortalLinks(HIS_HOST, CDI_HOST).mtt_run("1309380263289049088") is None


def test_run_view_carries_the_typed_fields() -> None:
    fields = RunView.model_fields
    assert "portal_url" in fields and "idmc_instance_id" in fields


def test_monitor_lookup_has_portal_url(idmc: respx.MockRouter, idmc_http: IdmcHttp) -> None:
    idmc.get(f"{MDM}/job/public/api/v1/jobInstance/{HIS_ID}").respond(
        200, json={"id": HIS_ID, "jobType": "b360.egress", "_meta": {"state": "COMPLETED"}}
    )
    view = MdmMonitor(MdmClient(idmc_http, MDM, PLATFORM)).lookup(HIS_ID)
    assert view.portal_url == f"{MDM}/ui-config-app/main/jobDetails/{HIS_ID}"


def test_taskflow_status_start_and_runs_carry_go_to_idmc(
    idmc: respx.MockRouter, idmc_http: IdmcHttp
) -> None:
    service = CdiService(CdiClient(idmc_http), RunRegistry("cdi"), PortalLinks(HIS_HOST, CDI_HOST))
    app = create_app()
    app.dependency_overrides[get_cdi_service] = lambda: service
    client = TestClient(app)
    idmc.get(f"{PLATFORM}/public/core/v3/objects").respond(
        200, json={"objects": [{"id": "FED9", "path": "ZL_Vamsi/tf_Ldg_MDM_CDI_TTF"}]}
    )
    idmc.post(f"{POD}/active-bpel/rt/tf_Ldg_MDM_CDI_TTF").respond(200, json={"RunId": RUN})
    started = client.post("/api/cdi/taskflows/tf_Ldg_MDM_CDI_TTF/run").json()
    expected = (
        f"{CDI_HOST}/diUI/products/integrationDesign/main/processinstance/"
        f"{RUN}/tf_Ldg_MDM_CDI_TTF-{RUN}%7B%7D"
    )
    assert started["portal_url"] == expected
    runs = client.get("/api/cdi/runs").json()
    assert runs[0]["portal_url"] == expected

    idmc.get(f"{POD}/active-bpel/services/tf/status/{RUN}").respond(200, json=SUSPENDED)
    status = client.get(f"/api/cdi/taskflows/runs/{RUN}?details=false").json()
    name = status["taskflow_name"]
    assert status["portal_url"].endswith(f"/processinstance/{RUN}/{name}-{RUN}%7B%7D")
