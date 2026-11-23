"""MdmService: picker list (metadata + resolver), runs, and status refresh."""

from app.common.idmc_session import IdmcError
from app.common.runs import RunRegistry, RunStatus, RunView
from app.mdm.client import MdmClient
from app.mdm.models import MdmJob, MdmJobKind, MdmRunRequest
from app.mdm.resolver import JobDefinitionResolver


class MdmService:
    def __init__(
        self, client: MdmClient, resolver: JobDefinitionResolver, registry: RunRegistry
    ) -> None:
        self._client = client
        self._resolver = resolver
        self._registry = registry
        self._instances: dict[str, str] = {}  # run_key -> job instance id

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

    def list_runs(self) -> list[RunView]:
        return self._registry.list_runs()
