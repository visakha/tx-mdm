"""Shared test fixtures: a fake IDMC behind respx, no network, no real credentials."""

import httpx
import pytest
import respx
from pydantic import SecretStr

from app.common.idmc_session import IdmcHttp, IdmcSession

LOGIN = "https://login.example.com"
PLATFORM = "https://pod.example.com/saas"
MDM = "https://pod-mdm.example.com"


@pytest.fixture
def idmc() -> respx.MockRouter:
    with respx.mock(assert_all_called=False) as router:
        router.post(f"{LOGIN}/saas/public/core/v3/login").respond(
            200,
            json={"userInfo": {"sessionId": "S1"}, "products": [{"baseApiUrl": PLATFORM}]},
        )
        yield router


@pytest.fixture
def idmc_http(idmc: respx.MockRouter) -> IdmcHttp:
    client = httpx.Client(trust_env=False)  # ignore sandbox proxy env vars
    session = IdmcSession(client, LOGIN, "tester", SecretStr("not-a-real-password"))
    return IdmcHttp(client, session)
