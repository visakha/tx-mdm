"""Explicit wiring. One HTTP client for the process; CDI and MDM each get their own session,
registry and service. Tests override get_cdi_service / get_mdm_service via app.dependency_overrides.
"""

import logging
from functools import lru_cache

import httpx

from app.b360data.service import B360DataService
from app.cdi.client import CdiClient
from app.cdi.service import CdiService
from app.common.idmc_session import IdmcHttp, IdmcSession
from app.common.runs import RunRegistry
from app.config import Settings, get_settings
from app.mdm.client import MdmClient
from app.mdm.monitor import MdmMonitor
from app.mdm.resolver import JobSearchResolver
from app.mdm.service import MdmService

log = logging.getLogger(__name__)


def build_http_client(settings: Settings) -> httpx.Client:
    """Proxy comes from settings, not from ambient env vars, unless HTTP_TRUST_ENV=true.

    If env-var proxy config is requested but httpx cannot parse it (e.g. NO_PROXY with an
    IPv6 entry -> InvalidURL "Invalid port"), fall back to the explicit setting and say so.
    """
    proxy = settings.idmc_proxy_url or None
    if settings.http_trust_env:
        try:
            return httpx.Client(timeout=settings.http_timeout_seconds, trust_env=True)
        except (httpx.InvalidURL, ValueError) as err:
            log.warning(
                "Ignoring proxy env vars httpx cannot parse (%s); using IDMC_PROXY_URL", err
            )
    return httpx.Client(timeout=settings.http_timeout_seconds, trust_env=False, proxy=proxy)


@lru_cache
def get_http_client() -> httpx.Client:
    return build_http_client(get_settings())


def _new_session(settings: Settings) -> IdmcSession:
    return IdmcSession(
        get_http_client(), settings.idmc_login_url, settings.idmc_username, settings.idmc_password
    )


@lru_cache
def get_cdi_service() -> CdiService:
    settings = get_settings()
    http = IdmcHttp(get_http_client(), _new_session(settings))
    client = CdiClient(http, settings.idmc_platform_url)
    return CdiService(client, RunRegistry("cdi"))


@lru_cache
def get_mdm_service() -> MdmService:
    settings = get_settings()
    http = IdmcHttp(get_http_client(), _new_session(settings))
    client = MdmClient(http, settings.idmc_mdm_url, settings.idmc_platform_url)
    resolver = JobSearchResolver(client.search_job_instances, settings.mdm_resolver_cache_seconds)
    return MdmService(client, resolver, RunRegistry("mdm"))


@lru_cache
def get_mdm_monitor() -> MdmMonitor:
    """Read-only B360 job search; its own client on the MDM session settings."""
    settings = get_settings()
    http = IdmcHttp(get_http_client(), _new_session(settings))
    return MdmMonitor(MdmClient(http, settings.idmc_mdm_url, settings.idmc_platform_url))


@lru_cache
def get_b360_data_service() -> B360DataService:
    """Read-only B360 Data notebook: metadata + search on the MDM host, its own session."""
    settings = get_settings()
    http = IdmcHttp(get_http_client(), _new_session(settings))
    return B360DataService(http, settings.idmc_mdm_url)
