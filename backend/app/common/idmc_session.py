"""IDMC login + an HTTP helper that re-logs in once on 401 and stops hard on 429.

CDI and MDM each create their *own* IdmcSession, so their session handling stays separate.
"""

import threading
from dataclasses import dataclass
from typing import Any

import httpx
from pydantic import SecretStr

from app.common import idmc_echo
from app.common.idmc_registry import LOGIN, IdmcCallSpec

V3_LOGIN_PATH = LOGIN.path


class IdmcError(Exception):
    """Informatica answered with an error we show to the user as-is."""

    def __init__(self, status_code: int, message: str) -> None:
        super().__init__(f"IDMC {status_code}: {message}")
        self.status_code = status_code
        self.message = message


class IdmcRateLimitedError(IdmcError):
    """HTTP 429. Hard stop: we never retry this automatically."""


@dataclass(frozen=True)
class LoginResult:
    session_id: str
    base_api_url: str  # products[0].baseApiUrl, e.g. https://usw1.dm1-us.informaticacloud.com/saas


class IdmcSession:
    """Holds one v3 session. Thread-safe lazy login; invalidate() forces a fresh login."""

    def __init__(
        self, http: httpx.Client, login_url: str, username: str, password: SecretStr
    ) -> None:
        self._http = http
        self._login_url = login_url.rstrip("/")
        self._username = username
        self._password = password
        self._current: LoginResult | None = None
        self._lock = threading.Lock()

    @property
    def username(self) -> str:
        return self._username

    @property
    def login_url(self) -> str:
        return self._login_url

    def current(self) -> LoginResult:
        with self._lock:
            if self._current is None:
                self._current = self._login()
            return self._current

    def invalidate(self) -> None:
        with self._lock:
            self._current = None

    def _login(self) -> LoginResult:
        response = self._http.post(
            self._login_url + V3_LOGIN_PATH,
            json={"username": self._username, "password": self._password.get_secret_value()},
            headers={"Accept": "application/json"},
        )
        if response.status_code != 200:
            # Never echo the request body: it carries the password.
            raise IdmcError(response.status_code, "login failed")
        body = response.json()
        products = body.get("products") or []
        base_api_url = products[0].get("baseApiUrl", "") if products else ""
        return LoginResult(session_id=body["userInfo"]["sessionId"], base_api_url=base_api_url)


class IdmcHttp:
    """Sends a request with session headers; on 401 logs in again and retries that request once.

    A 401 means the call never ran, so retrying it is not a job retry.
    """

    def __init__(self, http: httpx.Client, session: IdmcSession) -> None:
        self._http = http
        self.session = session

    def request(
        self,
        spec: IdmcCallSpec,
        url: str,
        json: Any = None,
        params: dict[str, Any] | None = None,
    ) -> Any:
        """0.9.14: every IDMC call names its registry row (method + session header come from it),
        so /openapi-idmc.json and Copy IDMC curl cannot drift from the code."""
        response = self._send(spec, url, json, params)
        if response.status_code == 401:
            self.session.invalidate()
            response = self._send(spec, url, json, params)
        return _parse(response)

    def request_bytes(
        self,
        spec: IdmcCallSpec,
        url: str,
        params: dict[str, Any] | None = None,
    ) -> tuple[str, bytes]:
        """GET a non-JSON body (e.g. a session log). Returns (content type, raw bytes).

        Same 401 re-login and 429 hard stop as request().
        """
        response = self._send(spec, url, None, params, accept="*/*")
        if response.status_code == 401:
            self.session.invalidate()
            response = self._send(spec, url, None, params, accept="*/*")
        if response.status_code == 429:
            raise IdmcRateLimitedError(429, "rate limited by Informatica; not retrying")
        if response.status_code >= 400:
            raise IdmcError(response.status_code, response.text[:500])
        return response.headers.get("content-type", ""), response.content

    def _send(
        self,
        spec: IdmcCallSpec,
        url: str,
        json: Any,
        params: dict[str, Any] | None,
        accept: str = "application/json",
    ) -> httpx.Response:
        session_id = self.session.current().session_id
        # Copy IDMC curl: header NAMES only, never the session id value.
        full_url = str(httpx.URL(url, params=params)) if params else url
        method = spec.method.value
        session_headers = spec.session_headers
        idmc_echo.record(
            spec,
            full_url,
            accept,
            json,
            self.session.login_url,
            self.session.username,
        )
        headers = {"Accept": accept, "Content-Type": "application/json"}
        headers.update({name: session_id for name in session_headers})
        headers.update(dict(spec.extra_headers))
        return self._http.request(method, url, headers=headers, json=json, params=params)


def _parse(response: httpx.Response) -> Any:
    if response.status_code == 429:
        raise IdmcRateLimitedError(429, "rate limited by Informatica; not retrying")
    if response.status_code >= 400:
        raise IdmcError(response.status_code, response.text[:500])
    if not response.content:
        return None
    return response.json()
