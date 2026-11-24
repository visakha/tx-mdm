"""0.10.0: move one mapping task to another runtime environment - fake IDMC only, never his org."""

import copy
from collections.abc import Iterator

import httpx
import pytest
import respx
from fastapi.testclient import TestClient

from app.cdi.runtime_env import RuntimeEnvironmentService
from app.common.idmc_session import IdmcHttp
from app.dependencies import get_runtime_env_service
from app.main import create_app
from dev import fake_idmc
from tests.conftest import PLATFORM

FAKE = TestClient(fake_idmc.app)
TASK = "0100000Z000000000005"
URL = f"/api/cdi/mapping-tasks/{TASK}/runtime-environment"


def _forward(sent: list[httpx.Request], stale: bool) -> object:
    def forward(request: httpx.Request) -> httpx.Response:
        sent.append(request)
        mode = request.headers.get("Update-Mode", "FULL")
        reply = FAKE.request(
            request.method,
            request.url.path,
            params=dict(request.url.params),
            content=request.content,
            headers={"content-type": "application/json", "Update-Mode": mode},
        )
        if stale and request.method == "POST":
            fake_idmc._V2_MTTASK["FED5"]["runtimeEnvironmentId"] = "01000025000000000003"
        return httpx.Response(reply.status_code, content=reply.content)

    return forward


@pytest.fixture
def sent() -> Iterator[list[httpx.Request]]:
    saved = copy.deepcopy(fake_idmc._V2_MTTASK)
    yield []
    fake_idmc._V2_MTTASK.clear()
    fake_idmc._V2_MTTASK.update(saved)


def _api(
    idmc: respx.MockRouter, http: IdmcHttp, sent: list[httpx.Request], stale: bool = False
) -> TestClient:
    idmc.route(url__startswith=PLATFORM).mock(side_effect=_forward(sent, stale))
    app = create_app()
    service = RuntimeEnvironmentService(http, PLATFORM)
    app.dependency_overrides[get_runtime_env_service] = lambda: service
    return TestClient(app)


def test_read_then_partial_post_only_runtime_then_verified(
    idmc: respx.MockRouter, idmc_http: IdmcHttp, sent: list[httpx.Request]
) -> None:
    api = _api(idmc, idmc_http, sent)
    assert api.get(URL).json()["runtime_environment"] == {
        "id": "01000025000000000003",
        "name": "laptop",
    }
    body = api.put(URL, json={"runtime_environment": "hhsc4avmdm1d"}).json()
    assert body["before"]["name"] == "laptop" and body["after"]["name"] == "hhsc4avmdm1d"
    assert body["changed"] and body["verified"]
    [post] = [r for r in sent if r.method == "POST"]
    assert post.headers["Update-Mode"] == "PARTIAL"
    assert post.read() == b'{"@type":"mtTask","runtimeEnvironmentId":"01000025000000000004"}'
    assert fake_idmc._V2_MTTASK["FED5"]["mappingId"] == "01000017000000000005"  # rest untouched
    again = api.put(URL, json={"runtime_environment": "HHSC4AVMDM1D"}).json()
    assert again["changed"] is False and len([r for r in sent if r.method == "POST"]) == 1


def test_unknown_name_400_and_stale_read_back_409(
    idmc: respx.MockRouter, idmc_http: IdmcHttp, sent: list[httpx.Request]
) -> None:
    api = _api(idmc, idmc_http, sent, stale=True)
    bad = api.put(URL, json={"runtime_environment": "nope"})
    assert bad.status_code == 400 and "hhsc4avmdm1d" in bad.json()["detail"]
    assert not [r for r in sent if r.method == "POST"]
    refused = api.put(URL, json={"runtime_environment": "hhsc4avmdm1d"})
    assert refused.status_code == 409 and "not verified" in refused.json()["detail"]
