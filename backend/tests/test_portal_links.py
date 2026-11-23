"""0.9.15 Addendum A: IDMC portal deep links, one typed builder (app/common/portal.py)."""

import respx

from app.common.idmc_session import IdmcHttp
from app.common.portal import CDI_RUN_PATH, PortalLinks
from app.common.runs import RunView
from app.mdm.client import MdmClient
from app.mdm.monitor import MdmMonitor
from tests.conftest import MDM, PLATFORM

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


def test_cdi_slot_is_empty_until_he_gives_the_pattern() -> None:
    assert CDI_RUN_PATH is None
    assert PortalLinks(HIS_HOST).cdi_run("1309380263289049088") is None


def test_run_view_carries_the_typed_fields() -> None:
    fields = RunView.model_fields
    assert "portal_url" in fields and "idmc_instance_id" in fields


def test_monitor_lookup_has_portal_url(idmc: respx.MockRouter, idmc_http: IdmcHttp) -> None:
    idmc.get(f"{MDM}/job/public/api/v1/jobInstance/{HIS_ID}").respond(
        200, json={"id": HIS_ID, "jobType": "b360.egress", "_meta": {"state": "COMPLETED"}}
    )
    view = MdmMonitor(MdmClient(idmc_http, MDM, PLATFORM)).lookup(HIS_ID)
    assert view.portal_url == f"{MDM}/ui-config-app/main/jobDetails/{HIS_ID}"
