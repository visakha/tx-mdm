"""0.9.15 Addendum A (Vamsi 03:36 CST): "IDMC portal" deep links, built in ONE typed place.

MDM / Business 360 job instance page, his exact sample (taken from his browser, NOT a documented
API - UNVERIFIED-DOC):
    https://usw1-mdm.dm1-us.informaticacloud.com/ui-config-app/main/jobDetails/1309450654674083840
  = {mdm_host}/ui-config-app/main/jobDetails/{instance_id}

CDI runs / taskflows: he is about to give a sample. Until then CDI_RUN_PATH is None and
cdi_run() always returns None - the pattern is deliberately NOT invented here.
"""

import httpx

from app.common.naming import is_identifier

MDM_JOB_DETAILS_PATH = "/ui-config-app/main/jobDetails/{instance_id}"
CDI_RUN_PATH: str | None = None  # typed slot: set from Vamsi's sample URL, never guessed
MAX_ID = 128


class PortalLinks:
    """Builds portal URLs from the configured hosts + a typed id. Bad input -> None, never a
    half-built link."""

    def __init__(self, mdm_host: str) -> None:
        self._mdm = httpx.URL(mdm_host)

    def mdm_job(self, instance_id: str | None) -> str | None:
        if instance_id is None or not is_identifier(instance_id, MAX_ID):
            return None
        path = MDM_JOB_DETAILS_PATH.format(instance_id=instance_id)
        return str(self._mdm.copy_with(path=path, query=None, fragment=None))

    def cdi_run(self, run_id: str | None) -> str | None:
        """Slot for the CDI portal link (pattern not known yet: always None)."""
        if CDI_RUN_PATH is None or run_id is None or not is_identifier(run_id, MAX_ID):
            return None
        return str(self._mdm.copy_with(path=CDI_RUN_PATH.format(run_id=run_id)))  # pragma: no cover
