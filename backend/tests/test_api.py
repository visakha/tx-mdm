"""Route-level checks with the services swapped for in-memory fakes via dependency_overrides."""

from fastapi.testclient import TestClient

from app.common.runs import RunRegistry, RunView
from app.dependencies import get_cdi_service
from app.main import create_app


class FakeCdiService:
    def __init__(self) -> None:
        self.registry = RunRegistry("cdi")

    def start(self, request: object) -> RunView:
        return self.registry.reserve("T1", "mt_load", "MTT")


def test_second_run_of_the_same_job_is_refused_with_409():
    app = create_app()
    fake = FakeCdiService()
    app.dependency_overrides[get_cdi_service] = lambda: fake
    client = TestClient(app)
    body = {"task_id": "T1", "task_type": "MTT", "task_name": "mt_load"}

    assert client.post("/api/cdi/runs", json=body).status_code == 200
    second = client.post("/api/cdi/runs", json=body)
    assert second.status_code == 409


def test_health():
    assert TestClient(create_app()).get("/api/health").json() == {"status": "ok"}
