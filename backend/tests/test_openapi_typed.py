"""0.9.12: /openapi-typed.json and /docs-typed. Fake IDMC only, never his org."""

from collections.abc import Iterator

import httpx
import pytest
import respx
from fastapi.testclient import TestClient

from app.b360data.service import B360DataService
from app.common.idmc_session import IdmcHttp
from app.dependencies import get_b360_data_service
from app.main import create_app
from dev import fake_idmc
from tests.conftest import MDM

FAKE = TestClient(fake_idmc.app)


def _client(idmc: respx.MockRouter, idmc_http: IdmcHttp, broken: bool) -> TestClient:
    def forward(request: httpx.Request) -> httpx.Response:
        if broken:
            return httpx.Response(500, json={"message": "down"})
        reply = FAKE.request(
            request.method,
            request.url.path,
            params=dict(request.url.params),
            content=request.content,
            headers={"content-type": "application/json"},
        )
        return httpx.Response(reply.status_code, content=reply.content)

    idmc.route(url__startswith=MDM).mock(side_effect=forward)
    app = create_app()
    app.dependency_overrides[get_b360_data_service] = lambda: B360DataService(idmc_http, MDM)
    return TestClient(app)


@pytest.fixture
def api(idmc: respx.MockRouter, idmc_http: IdmcHttp) -> Iterator[TestClient]:
    yield _client(idmc, idmc_http, broken=False)


def test_typed_spec_has_concrete_zlv_guest(api: TestClient) -> None:
    spec = api.get("/openapi-typed.json").json()
    schemas = spec["components"]["schemas"]
    record = schemas["Record_zlv_guest"]["properties"]
    assert record["first_name"]["type"] == "string"
    phone = record["x_phone"]
    assert phone["type"] == "array"
    assert phone["items"]["$ref"] == "#/components/schemas/Row_zlv_guest_x_phone"
    row = schemas["Row_zlv_guest_x_phone"]["properties"]
    assert row["cntry_cd"]["type"] == "integer" and row["ph_num"]["type"] == "integer"
    assert row["no_mrkt_calls"]["type"] == "boolean"
    assert row["ph_typ"]["enum"] == fake_idmc._RDM_PHONETYPE_CODES
    assert row["ph_typ"]["x-reference-360"] == "rdm.value.be._ent_phonetype"
    assert record["_meta"]["readOnly"] is True and record["_meta"]["x-origin"] == "SYSTEM"
    post = spec["paths"]["/api/b360/entities/zlv_guest/records"]["post"]
    ref = post["requestBody"]["content"]["application/json"]["schema"]["$ref"]
    assert ref == "#/components/schemas/CreateRequest_zlv_guest"
    assert spec["x-typed-warnings"] == []
    # the plain spec stays generic and separate (his choice)
    assert "Record_zlv_guest" not in api.get("/openapi.json").json()["components"]["schemas"]


def test_metadata_failure_still_returns_base_spec(
    idmc: respx.MockRouter, idmc_http: IdmcHttp
) -> None:
    client = _client(idmc, idmc_http, broken=True)
    reply = client.get("/openapi-typed.json")
    assert reply.status_code == 200
    spec = reply.json()
    assert "BusinessEntity" in spec["components"]["schemas"]
    assert spec["x-typed-warnings"] and "zlv_guest" in spec["x-typed-warnings"][0]


def test_docs_typed_points_at_typed_spec(api: TestClient) -> None:
    html = api.get("/docs-typed").text
    assert "/openapi-typed.json" in html
