"""0.10.0: read or change the runtime environment of ONE mapping task (v2 mttask).

Change = GET the task, POST only runtimeEnvironmentId in partial mode (Update-Mode: PARTIAL,
IDMC REST API Reference July 2026 pp. 19 and 486), GET it again; refuse if the read-back differs.
"""

from enum import StrEnum

from pydantic import BaseModel, Field

from app.cdi import endpoints as ep
from app.common import idmc_registry as idmc
from app.common.idmc_registry import MtTaskRuntimePatch, MtTaskWire, RuntimeEnvironmentWire
from app.common.idmc_session import IdmcHttp
from app.design.client import DesignClient
from app.design.models import RuntimeEnvironmentRef


class TaskIdKind(StrEnum):
    V2 = "v2"  # mttask id (appContextId), e.g. 0100000Z000000000005
    FRS = "frs"  # federated (v3 / Design list) id


class RuntimeEnvironmentChange(BaseModel):
    runtime_environment: str = Field(
        min_length=1,
        description="Runtime environment name (e.g. hhsc4avmdm1d) or its id / federatedId.",
        examples=["hhsc4avmdm1d"],
    )


class MappingTaskRuntime(BaseModel):
    task_id: str = Field(description="v2 mttask id.")
    task_name: str
    runtime_environment: RuntimeEnvironmentRef | None


class RuntimeChangeResult(BaseModel):
    task_id: str
    task_name: str
    before: RuntimeEnvironmentRef | None
    after: RuntimeEnvironmentRef | None
    changed: bool = Field(description="False when the task already used the requested one.")
    verified: bool = Field(description="True when the read-back shows the requested id.")
    message: str


class RuntimeNotVerifiedError(Exception):
    """The POST went through but the read-back does not show the requested runtime."""


class RuntimeEnvironmentService:
    def __init__(self, http: IdmcHttp, platform_url_override: str = "") -> None:
        self._http = http
        self._design = DesignClient(http, platform_url_override)

    def _task(self, task_id: str, kind: TaskIdKind) -> MtTaskWire:
        match kind:
            case TaskIdKind.V2:
                return self._design.mttask_by_id(task_id)
            case TaskIdKind.FRS:
                return self._design.mttask_by_frs(task_id)

    def _ref(
        self, rt_id: str | None, envs: list[RuntimeEnvironmentWire]
    ) -> RuntimeEnvironmentRef | None:
        if rt_id is None:
            return None
        return RuntimeEnvironmentRef(
            id=rt_id, name=next((e.name for e in envs if e.id == rt_id), None)
        )

    def current(self, task_id: str, kind: TaskIdKind) -> MappingTaskRuntime:
        task = self._task(task_id, kind)
        envs = self._design.runtime_environments()
        return MappingTaskRuntime(
            task_id=task.id,
            task_name=task.name,
            runtime_environment=self._ref(task.runtimeEnvironmentId, envs),
        )

    def change(self, task_id: str, kind: TaskIdKind, target: str) -> RuntimeChangeResult:
        envs = self._design.runtime_environments()
        wanted = resolve(target, envs)
        task = self._task(task_id, kind)
        before = self._ref(task.runtimeEnvironmentId, envs)
        if task.runtimeEnvironmentId == wanted.id:
            return RuntimeChangeResult(
                task_id=task.id,
                task_name=task.name,
                before=before,
                after=before,
                changed=False,
                verified=True,
                message=f"already on {wanted.name}; nothing written",
            )
        url = self._design.platform_url() + ep.MTTASK_UPDATE.format(task_id=task.id)
        body = MtTaskRuntimePatch(runtimeEnvironmentId=wanted.id).model_dump(by_alias=True)
        self._http.request(idmc.MTTASK_SET_RUNTIME, url, json=body)
        back = self._design.mttask_by_id(task.id)
        after = self._ref(back.runtimeEnvironmentId, envs)
        if back.runtimeEnvironmentId != wanted.id:
            raise RuntimeNotVerifiedError(
                f"mapping task {task.name}: asked for {wanted.name} ({wanted.id}), read-back "
                f"shows {back.runtimeEnvironmentId}; not verified"
            )
        return RuntimeChangeResult(
            task_id=task.id,
            task_name=task.name,
            before=before,
            after=after,
            changed=True,
            verified=True,
            message=f"{task.name}: {_label(before)} -> {wanted.name} (read back)",
        )


def resolve(target: str, envs: list[RuntimeEnvironmentWire]) -> RuntimeEnvironmentWire:
    """Exact name, id or federatedId first; then a unique case-insensitive name."""
    exact = [e for e in envs if target in (e.name, e.id, e.federatedId)]
    loose = [e for e in envs if e.name.lower() == target.strip().lower()]
    found = exact or loose
    if len(found) != 1:
        names = ", ".join(sorted(e.name for e in envs)) or "(none)"
        why = "matches more than one" if found else "is not a runtime environment"
        raise LookupError(f"{target!r} {why} in this org; known: {names}")
    return found[0]


def _label(ref: RuntimeEnvironmentRef | None) -> str:
    return "(none)" if ref is None else ref.name or ref.id
