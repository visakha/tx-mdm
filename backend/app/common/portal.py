"""0.9.15 Addenda A + B (Vamsi 03:36 / 03:44 CST): "IDMC portal" deep links, built in ONE
typed place. Both patterns were taken from his browser - NOT documented APIs (UNVERIFIED-DOC).

A. MDM / Business 360 job instance page, his exact sample:
    https://usw1-mdm.dm1-us.informaticacloud.com/ui-config-app/main/jobDetails/1309450654674083840
  = {mdm_host}/ui-config-app/main/jobDetails/{instance_id}

B. CDI taskflow run (process instance) page, his exact sample:
    https://usw1.dm1-us.informaticacloud.com/diUI/products/integrationDesign/main/processinstance/
    1309453033490374656/tf_Ldg_MDM_CDI_TTF-1309453033490374656%7B%7D
  = {cdi_pod_host}/diUI/products/integrationDesign/main/processinstance/{run_id}/
    {taskflow_name}-{run_id}{}      (the last segment percent-encoded, so "{}" -> %7B%7D)

Plain mapping-task (MTT) runs: he has given NO pattern - mtt_run() always returns None.
"""

from urllib.parse import quote

import httpx

from app.common.naming import is_identifier

MDM_JOB_DETAILS_PATH = "/ui-config-app/main/jobDetails/{instance_id}"
CDI_PROCESS_INSTANCE_PATH = (
    "/diUI/products/integrationDesign/main/processinstance/{run_id}/{segment}"
)
CDI_INSTANCE_SUFFIX = "{}"  # literal braces after "<name>-<run id>"; encoded as %7B%7D
MTT_RUN_PATH: str | None = None  # typed slot: no pattern from Vamsi yet, never guessed
MAX_ID = 128


def _segment(value: str) -> str:
    """One URL path segment, percent-encoded (nothing left unencoded except unreserved)."""
    return quote(value, safe="")


class PortalLinks:
    """Builds portal URLs from the configured hosts + typed ids. Bad input -> None, never a
    half-built link."""

    def __init__(self, mdm_host: str, cdi_host: str = "") -> None:
        self._mdm = httpx.URL(mdm_host)
        self._cdi = httpx.URL(cdi_host) if cdi_host else None

    def mdm_job(self, instance_id: str | None) -> str | None:
        if instance_id is None or not is_identifier(instance_id, MAX_ID):
            return None
        path = MDM_JOB_DETAILS_PATH.format(instance_id=instance_id)
        return str(self._mdm.copy_with(path=path, query=None, fragment=None))

    def cdi_taskflow_run(self, taskflow_name: str | None, run_id: str | None) -> str | None:
        """Taskflow run page in Data Integration (process instance)."""
        if self._cdi is None or not taskflow_name or run_id is None:
            return None
        if not is_identifier(run_id, MAX_ID):
            return None
        segment = _segment(f"{taskflow_name}-{run_id}{CDI_INSTANCE_SUFFIX}")
        path = CDI_PROCESS_INSTANCE_PATH.format(run_id=_segment(run_id), segment=segment)
        return str(self._cdi.copy_with(raw_path=path.encode("ascii"), query=None, fragment=None))

    def mtt_run(self, run_id: str | None) -> str | None:
        """Slot for plain mapping-task runs (pattern not known yet: always None)."""
        return None if MTT_RUN_PATH is None or run_id is None else None
