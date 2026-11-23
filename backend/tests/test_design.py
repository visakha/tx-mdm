"""0.9.15 Design notebook: /api/design/* on the REAL backend + the fake IDMC (never his org)."""

from collections.abc import Iterator

import httpx
import pytest
import respx
from fastapi.testclient import TestClient

from app.cdi.client import CdiClient
from app.cdi.service import CdiService
from app.common.idmc_session import IdmcHttp
from app.common.runs import RunRegistry
from app.dependencies import get_design_service
from app.design.client import DesignClient
from app.design.service import DesignService
from app.main import create_app
from dev import fake_idmc
from tests.conftest import PLATFORM

FAKE = TestClient(fake_idmc.app)
TF = "tf_MDM_ZLV_TTF_Guest_Basic_EGR"
CHILD = "mt_m_MDM_ZLV_TTF_Guest_Basic_EGR"


class Calls:
    def __init__(self) -> None:
        self.paths: list[str] = []


def _forward(calls: Calls, status: int | None) -> object:
    def forward(request: httpx.Request) -> httpx.Response:
        calls.paths.append(request.url.path)
        if status is not None:
            return httpx.Response(status, json={"error": {"description": "fake failure"}})
        reply = FAKE.request(
            request.method,
            request.url.path,
            params=dict(request.url.params),
            content=request.content,
            headers={"content-type": "application/json"},
        )
        return httpx.Response(reply.status_code, content=reply.content)

    return forward


def _api(
    idmc: respx.MockRouter, idmc_http: IdmcHttp, calls: Calls, status: int | None
) -> TestClient:
    idmc.route(url__startswith=PLATFORM).mock(side_effect=_forward(calls, status))
    app = create_app()
    service = DesignService(DesignClient(idmc_http, PLATFORM))
    app.dependency_overrides[get_design_service] = lambda: service
    return TestClient(app)


@pytest.fixture
def calls() -> Calls:
    return Calls()


@pytest.fixture
def api(idmc: respx.MockRouter, idmc_http: IdmcHttp, calls: Calls) -> Iterator[TestClient]:
    yield _api(idmc, idmc_http, calls, None)


def test_types_are_the_documented_set_mapping_task_first(api: TestClient) -> None:
    body = api.get("/api/design/types").json()
    kinds = [t["type"] for t in body["types"]]
    assert kinds == [
        "MTT",
        "TASKFLOW",
        "DTEMPLATE",
        "DSS",
        "WORKFLOW",
        "CONNECTION",
        "RUNTIME_ENVIRONMENT",
    ]
    labels = {t["type"]: t["label"] for t in body["types"]}
    assert labels["MTT"] == "Mapping task" and labels["TASKFLOW"] == "Taskflow"
    runtime = {t["type"]: t["has_runtime"] for t in body["types"]}
    assert runtime["MTT"] and not runtime["TASKFLOW"]


def test_list_mapping_tasks_name_path_updated(api: TestClient) -> None:
    response = api.get("/api/design/assets/MTT")
    assert response.status_code == 200 and response.headers.get("X-Idmc-Echo-Id")
    body = response.json()
    names = [a["name"] for a in body["assets"]]
    assert names == ["mt_load_customers", CHILD]
    child = body["assets"][1]
    assert child["path"] == f"ZL_Vamsi/ZLV_CDI/{CHILD}"
    assert child["updated_by"] == "VVamsi-idmcdev" and child["updated_at"].startswith("2026-11-22")
    assert body["from_cache"] is False
    assert api.get("/api/design/assets/MTT").json()["from_cache"] is True
    assert api.get("/api/design/assets/MTT?refresh=true").json()["from_cache"] is False


def test_mapping_task_detail_created_updated_runtime_name_mapping(api: TestClient) -> None:
    body = api.get("/api/design/assets/MTT/FED5").json()
    assert body["created_by"] == "VVamsi-idmcdev"
    assert body["created_at"].startswith("2026-11-14T18:05")
    assert body["updated_at"].startswith("2026-11-22T21:30")
    assert body["runtime_environment"] == {"id": "01000025000000000003", "name": "laptop"}
    assert body["mapping"]["name"] == "m_MDM_ZLV_TTF_Guest_Basic_EGR"
    uses = {u["name"]: u for u in body["uses"]}
    assert uses["m_MDM_ZLV_TTF_Guest_Basic_EGR"]["open_type"] == "DTEMPLATE"
    assert uses["ORA_STAGING"]["open_type"] == "CONNECTION"
    assert uses["ORA_STAGING"]["open_id"] == "0100000B000000000002"  # v2 id, as v2 needs


def test_taskflow_detail_lists_its_mapping_tasks_with_their_metadata(api: TestClient) -> None:
    body = api.get("/api/design/assets/TASKFLOW/FED4").json()
    assert body["runtime_environment"] is None
    assert "no runtime environment of its own" in body["runtime_note"]
    assert body["created_at"] is None  # not documented for taskflows; said in notes
    assert any("Created time / by are not available" in n for n in body["notes"])
    [child] = body["uses"]
    assert child["name"] == CHILD and child["open_type"] == "MTT" and child["open_id"] == "FED5"
    assert child["created_by"] == "VVamsi-idmcdev" and child["created_at"].startswith("2026-11-14")
    assert child["runtime_environment"]["name"] == "laptop"


def test_mapping_detail_by_name_and_used_by(api: TestClient) -> None:
    body = api.get("/api/design/assets/DTEMPLATE/MAP5").json()
    assert body["v2_id"] == "01000017000000000005" and body["created_by"] == "VVamsi-idmcdev"
    assert [u["name"] for u in body["used_by"]] == [CHILD]


def test_connections_never_carry_secrets(api: TestClient) -> None:
    listed = api.get("/api/design/assets/CONNECTION")
    detail = api.get("/api/design/assets/CONNECTION/0100000B000000000002")
    assert listed.status_code == 200 and detail.status_code == 200
    for text in (listed.text, detail.text):
        assert "fake-secret" not in text and "fake-token" not in text and "fake_user" not in text
    body = detail.json()
    assert body["connection_type"] == "Oracle"
    assert body["runtime_environment"]["name"] == "laptop"


def test_runtime_environment_names_are_cached(api: TestClient, calls: Calls) -> None:
    api.get("/api/design/assets/MTT/FED5")
    api.get("/api/design/assets/MTT/FED1")
    runtime_calls = [p for p in calls.paths if p.endswith("/runtimeEnvironment")]
    assert len(runtime_calls) == 1
    listed = api.get("/api/design/assets/RUNTIME_ENVIRONMENT").json()
    assert listed["from_cache"] is True and "laptop" in [a["name"] for a in listed["assets"]]
    detail = api.get("/api/design/assets/RUNTIME_ENVIRONMENT/01000025000000000003").json()
    assert detail["name"] == "laptop" and detail["is_shared"] is False


def test_unknown_id_is_404_with_words_and_bad_type_is_422(api: TestClient) -> None:
    missing = api.get("/api/design/assets/MTT/NOPE")
    assert missing.status_code == 404 and "No Mapping task with id NOPE" in missing.json()["detail"]
    assert api.get("/api/design/assets/BANANA").status_code == 422


def test_design_routes_are_get_only() -> None:
    spec = create_app().openapi()
    ops = [m for p, item in spec["paths"].items() if p.startswith("/api/design") for m in item]
    assert ops and set(ops) == {"get"}


def test_rate_limit_is_a_hard_stop(idmc: respx.MockRouter, idmc_http: IdmcHttp) -> None:
    calls = Calls()
    api = _api(idmc, idmc_http, calls, 429)
    assert api.get("/api/design/assets/MTT").status_code == 429
    assert len(calls.paths) == 1  # never retried


def test_idmc_error_is_502_with_detail(idmc: respx.MockRouter, idmc_http: IdmcHttp) -> None:
    api = _api(idmc, idmc_http, Calls(), 500)
    response = api.get("/api/design/assets/TASKFLOW")
    assert response.status_code == 502 and response.json()["detail"]


def test_taskflow_history_children_come_from_references(
    idmc: respx.MockRouter, idmc_http: IdmcHttp
) -> None:
    """0.9.15: the tf_ -> mt_m_ guess is replaced by the documented references call."""
    idmc.route(url__startswith=PLATFORM).mock(side_effect=_forward(Calls(), None))
    service = CdiService(CdiClient(idmc_http, PLATFORM), RunRegistry("cdi"))
    history = service.taskflow_history(TF, row_limit=50)
    assert history.child_tasks == [CHILD]
    assert history.child_names_source == "references" and not history.child_names_guessed
    assert not any("is a guess" in n for n in history.notes)
