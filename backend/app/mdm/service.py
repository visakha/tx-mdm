"""MdmService: picker list (metadata + resolver), runs, and status refresh."""

from datetime import UTC, datetime

from app.common.idmc_session import IdmcError
from app.common.portal import PortalLinks
from app.common.runs import RunRegistry, RunStatus, RunView
from app.mdm.client import MdmClient
from app.mdm.models import (
    MdmJob,
    MdmJobKind,
    MdmRunRequest,
    PublishRunRequest,
    PublishRunStarted,
)
from app.mdm.monitor import MdmJobInstanceView, view_from_instance
from app.mdm.resolver import JobDefinitionResolver


class MdmService:
    def __init__(
        self,
        client: MdmClient,
        resolver: JobDefinitionResolver,
        registry: RunRegistry,
        publish_job_name: str = "mdm_zlv_guest_pub_evts_001",
    ) -> None:
        self._client = client
        self._publish_job_name = publish_job_name
        self._resolver = resolver
        self._registry = registry
        self._instances: dict[str, str] = {}  # run_key -> job instance id
        self._portal = PortalLinks(client.mdm_url)

    def list_jobs(self) -> list[MdmJob]:
        assets = self._client.list_job_definitions()
        resolved = self._resolver.resolve(assets)
        jobs: list[MdmJob] = []
        for asset in assets:
            definition = resolved.get(asset.asset_id)
            job = MdmJob(**asset.model_dump())
            if definition is None:
                job.note = "Internal id not resolved yet (no past run found). Not runnable here."
            else:
                job.job_definition_id = definition.job_definition_id
                job.job_type = definition.job_type
                job.kind = definition.kind
                job.runnable = definition.kind is not MdmJobKind.UNKNOWN
            jobs.append(job)
        return jobs

    def start(self, request: MdmRunRequest) -> RunView:
        job = next((j for j in self.list_jobs() if j.asset_id == request.asset_id), None)
        if job is None:
            raise LookupError(f"No MDM job definition {request.asset_id}")
        if not job.runnable or job.job_definition_id is None:
            raise LookupError(f"{job.name} is not runnable: {job.note or 'kind unknown'}")
        run = self._registry.reserve(job.asset_id, job.name, job.kind.value)
        try:
            instance_id = self._client.start(job.kind, job.job_definition_id)
        except (IdmcError, ValueError, KeyError) as exc:
            self._registry.fail(run, str(exc))  # recorded, never retried
            return run
        self._instances[run.run_key] = instance_id
        run.idmc_instance_id = instance_id
        run.portal_url = self._portal.mdm_job(instance_id)
        self._registry.update_status(
            run, RunStatus.QUEUED, f"Accepted by B360, job instance {instance_id}"
        )
        return run

    def refresh(self, run_key: str) -> RunView:
        run = self._registry.get(run_key)
        instance_id = self._instances.get(run_key)
        if instance_id is None or run.status.is_terminal:
            return run
        snapshot = self._client.check(instance_id)
        run.counts = snapshot.counts
        if snapshot.started_at is not None:
            run.idmc_started_at = snapshot.started_at
        for error in snapshot.errors:
            if error not in run.errors:
                run.errors.append(error)
        self._registry.update_status(run, snapshot.status, snapshot.note)
        if snapshot.ended_at is not None and snapshot.status.is_terminal:
            run.ended_at = snapshot.ended_at
        return run

    def start_publish(self, request: PublishRunRequest) -> PublishRunStarted:
        """Start the Publish Business Events job by name. One active run per job (409)."""
        name = request.job_name or self._publish_job_name
        job = next((j for j in self.list_jobs() if j.name == name), None)
        if job is None:
            raise LookupError(f"No B360 job definition named {name}")
        if job.kind is not MdmJobKind.PUBLISH_EVENTS or job.job_definition_id is None:
            raise LookupError(f"{name} is not a resolved Publish Business Events job: {job.note}")
        run = self.start(MdmRunRequest(asset_id=job.asset_id))
        if run.idmc_instance_id is None:  # start failed; the error is on the run, never retried
            raise LookupError(f"Publish job {name} did not start: {'; '.join(run.errors)}")
        return PublishRunStarted(
            instance_id=run.idmc_instance_id,
            run_key=run.run_key,
            job_name=name,
            job_definition_id=job.job_definition_id,
            job_type=job.job_type or "",
            run_path_kind=self._client.run_path_kind(job.kind),
            started_at=run.started_at or datetime.now(tz=UTC),
            portal_url=run.portal_url,
        )

    def publish_status(self, instance_id: str) -> MdmJobInstanceView:
        """Read any job instance; also refreshes this backend's run record when it started it."""
        view = view_from_instance(self._client.read_instance(instance_id), datetime.now(tz=UTC))
        if view.instance_id == "":
            view.instance_id = instance_id
        view.portal_url = self._portal.mdm_job(view.instance_id)
        run_key = next((k for k, v in self._instances.items() if v == instance_id), None)
        if run_key is not None:
            self.refresh(run_key)  # keeps the one-active-run guard in step with IDMC
        return view

    def list_runs(self) -> list[RunView]:
        return self._registry.list_runs()
