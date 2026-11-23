import httpx
import pytest
import respx

from app.common.idmc_session import IdmcHttp, IdmcRateLimitedError
from tests.conftest import LOGIN, PLATFORM


def test_sends_session_under_each_requested_header(idmc: respx.MockRouter, idmc_http: IdmcHttp):
    route = idmc.get(f"{PLATFORM}/x").respond(200, json={"ok": True})

    assert idmc_http.request("GET", f"{PLATFORM}/x", ("INFA-SESSION-ID",)) == {"ok": True}
    assert route.calls.last.request.headers["INFA-SESSION-ID"] == "S1"


def test_logs_in_again_once_on_401(idmc: respx.MockRouter, idmc_http: IdmcHttp):
    login = idmc.routes[0]
    idmc.get(f"{PLATFORM}/x").mock(
        side_effect=[httpx.Response(401), httpx.Response(200, json={"ok": True})]
    )

    assert idmc_http.request("GET", f"{PLATFORM}/x", ("icSessionId",)) == {"ok": True}
    assert login.call_count == 2


def test_429_is_a_hard_stop(idmc: respx.MockRouter, idmc_http: IdmcHttp):
    route = idmc.get(f"{PLATFORM}/x").respond(429)

    with pytest.raises(IdmcRateLimitedError):
        idmc_http.request("GET", f"{PLATFORM}/x", ("icSessionId",))
    assert route.call_count == 1


def test_login_failure_does_not_leak_the_password(idmc: respx.MockRouter, idmc_http: IdmcHttp):
    idmc.post(f"{LOGIN}/saas/public/core/v3/login").respond(403, text="bad")

    with pytest.raises(Exception) as caught:
        idmc_http.session.current()
    assert "not-a-real-password" not in str(caught.value)
