import respx

from app.common.idmc_session import IdmcHttp
from app.common.runs import RunRegistry, RunStatus
from app.mdm.client import MdmClient, snapshot_from_job_instance
from app.mdm.models import MdmJobAsset, MdmJobKind, MdmRunRequest
from app.mdm.resolver import (
    JobSearchResolver,
    definitions_from_instances,
    kind_from_job_type,
    match_assets,
)
from app.mdm.service import MdmService
from tests.conftest import MDM, PLATFORM

INSTANCES = [
    {"jobType": "c360.ingress.load", "jobDefinition": {"id": "ingress_person"}},
    {"jobType": "c360.egress.something", "jobDefinition": {"id": "egress_person"}},
    {
        "jobType": "c360.ingress.load",
        "jobDefinition": {"id": "internal.c360.ingress.fileImportJob"},
    },
    {"jobType": "c360.be.match.startTraining", "jobDefinition": {"id": "train"}},
]


def test_kind_from_job_type():
    assert kind_from_job_type("c360.ingress.load") is MdmJobKind.INGRESS
    assert kind_from_job_type("c360.be.matchmerge") is MdmJobKind.MATCH_MERGE
    assert kind_from_job_type("whatever.EGRESS.v2") is MdmJobKind.EGRESS
    assert kind_from_job_type("c360.be.match.startTraining") is MdmJobKind.UNKNOWN


def test_definitions_skip_console_imports_and_training():
    assert set(definitions_from_instances(INSTANCES)) == {"ingress_person", "egress_person"}


def test_match_assets_exact_or_normalised():
    definitions = definitions_from_instances(INSTANCES)
    assets = [
        MdmJobAsset(asset_id="a1", name="ingress_person", path="p/ingress_person"),
        MdmJobAsset(asset_id="a2", name="Egress Person", path="p/Egress Person"),
        MdmJobAsset(asset_id="a3", name="never_run", path="p/never_run"),
    ]
    resolved = match_assets(assets, definitions)
    assert resolved["a1"].kind is MdmJobKind.INGRESS
    assert resolved["a2"].job_definition_id == "egress_person"
    assert "a3" not in resolved


def test_resolver_caches_until_expiry():
    calls: list[int] = []
    now = [0.0]

    def search() -> list[dict[str, object]]:
        calls.append(1)
        return []

    resolver = JobSearchResolver(search, cache_seconds=60, clock=lambda: now[0])
    resolver.resolve([])
    resolver.resolve([])
    now[0] = 61
    resolver.resolve([])
    assert len(calls) == 2


def test_job_instance_snapshot_from_documented_sample():
    body = {
        "jobLevelMetrics": [
            {"id": "NUM_OF_INCOMING_RECORDS", "value": 10000},
            {"id": "NUM_OF_REC_FAILED", "value": 0},
            {"id": "NUM_OF_REC_LOAD_CREATED", "value": 10000},
            {"id": "NUM_OF_REC_LOAD_FAILED", "value": 0},
        ],
        "_meta": {"state": "SUCCESS", "startedAt": 1649151399754, "completedAt": 1649151874361},
    }
    snap = snapshot_from_job_instance(body)
    assert snap.status is RunStatus.SUCCESS
    assert snap.counts.source_success == 10000
    assert snap.counts.target_failed == 0
    assert snap.ended_at is not None


def test_ingress_run_end_to_end(idmc: respx.MockRouter, idmc_http: IdmcHttp):
    idmc.get(f"{PLATFORM}/public/core/v3/objects").respond(
        200, json={"objects": [{"id": "A1", "path": "MDM/ingress_person"}]}
    )
    idmc.post(f"{MDM}/job/public/api/v1/search").respond(
        200, json={"totalPages": 1, "jobInstances": INSTANCES}
    )
    run_route = idmc.post(f"{MDM}/job/public/api/v1/jobInstance/Ingress").respond(
        200, json={"id": "JI1"}
    )
    idmc.get(f"{MDM}/job/public/api/v1/jobInstance/JI1").respond(
        200,
        json={
            "_meta": {"state": "FAILED"},
            "steps": [{"name": "Load", "errorMessage": "Bad file"}],
        },
    )
    client = MdmClient(idmc_http, MDM)
    service = MdmService(
        client, JobSearchResolver(client.search_job_instances, 60), RunRegistry("mdm")
    )

    jobs = service.list_jobs()
    assert jobs[0].runnable and jobs[0].kind is MdmJobKind.INGRESS

    run = service.start(MdmRunRequest(asset_id="A1"))
    assert run_route.calls.last.request.content == b'{"jobDefinitionId":"ingress_person"}'
    run = service.refresh(run.run_key)
    assert run.status is RunStatus.FAILED
    assert run.errors == ["Bad file"]
