"""Explicit wiring. One HTTP client for the process; CDI and MDM each get their own session,
registry and service. Tests override get_cdi_service / get_mdm_service via app.dependency_overrides.
"""

from functools import lru_cache

import httpx

from app.cdi.client import CdiClient
from app.cdi.service import CdiService
from app.common.idmc_session import IdmcHttp, IdmcSession
from app.common.runs import RunRegistry
from app.config import Settings, get_settings
from app.mdm.client import MdmClient
from app.mdm.resolver import JobSearchResolver
from app.mdm.service import MdmService


@lru_cache
def get_http_client() -> httpx.Client:
    return httpx.Client(timeout=get_settings().http_timeout_seconds)


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
