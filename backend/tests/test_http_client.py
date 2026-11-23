"""The outbound client must not break on proxy env vars httpx cannot parse."""

import httpx
import pytest

from app.config import Settings
from app.dependencies import build_http_client

BAD_NO_PROXY = "localhost,127.0.0.1,[::1]:,::1"


def _settings(**extra: object) -> Settings:
    return Settings(idmc_username="u", idmc_password="placeholder", **extra)  # type: ignore[arg-type]


@pytest.mark.parametrize("trust_env", [False, True])
def test_bad_no_proxy_env_does_not_break_client(
    monkeypatch: pytest.MonkeyPatch, trust_env: bool
) -> None:
    monkeypatch.setenv("HTTPS_PROXY", "http://proxy.invalid:3128")
    monkeypatch.setenv("NO_PROXY", BAD_NO_PROXY)
    client = build_http_client(_settings(http_trust_env=trust_env))
    assert isinstance(client, httpx.Client)
    client.close()


def test_explicit_proxy_setting_is_used() -> None:
    client = build_http_client(_settings(idmc_proxy_url="http://proxy.example:8080"))
    assert client._mounts  # a proxy transport was mounted
    client.close()
