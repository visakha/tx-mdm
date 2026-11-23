from datetime import UTC, date, datetime

import respx
from fastapi.testclient import TestClient

from app.b360data.models import Cardinality, FieldDataType
from app.b360data.service import B360DataService
from app.b360data.wire import (
    business_entity_from_metadata,
    entities_from_datamodel,
    record_from_search,
    typed_value,
)
from app.common.idmc_session import IdmcHttp
from app.dependencies import get_b360_data_service
from app.main import create_app
from dev import fake_idmc
from tests.conftest import MDM

PERSON = fake_idmc._B360_ENTITIES["c360.person"]


def test_entities_derived_from_datamodel_only() -> None:
    entities = entities_from_datamodel(fake_idmc.datamodel())
    assert [e.name for e in entities] == ["c360.organization", "c360.person", "zlv.guest"]
    assert entities[2].label == "ZLV Guest"


def test_entities_found_by_eclass_anywhere() -> None:
    body = {
        "x": {
            "y": [
                {
                    "eClass": "http://informatica.com/mdm/v2/Core#//BusinessEntity",
                    "guid": "custombe1",
                    "label": {"en": "Custom"},
                }
            ]
        }
    }
    assert [e.name for e in entities_from_datamodel(body)] == ["custombe1"]


def test_metadata_splits_fields_and_field_groups() -> None:
    meta = business_entity_from_metadata(PERSON, "c360.person")
    assert [f.name for f in meta.fields] == ["firstName", "lastName", "gender", "designation"]
    assert meta.fields[0].searchable is True
    assert meta.fields[2].data_type is FieldDataType.PICKLIST
    assert meta.field_groups[1].cardinality is Cardinality.MANY
    assert [g.name for g in meta.field_groups] == ["PostalAddress", "Phone", "Email"]
    assert [f.name for f in meta.field_groups[0].fields][:2] == ["addressLine1", "city"]


def test_metadata_paged_content_form() -> None:
    meta = business_entity_from_metadata({"content": [PERSON]}, "c360.person")
    assert meta.label == "Person"


def test_record_rows_and_groups() -> None:
    meta = business_entity_from_metadata(PERSON, "c360.person")
    rec = record_from_search(fake_idmc._fake_records("c360.person")[0], meta)
    assert rec.values["gender"] == "Female"
    groups = {g.group: g.rows for g in rec.groups}
    assert groups["Phone"] == [{"phoneNumber": "512-555-0001"}, {"phoneNumber": "737-555-0001"}]
    assert groups["PostalAddress"][0]["state"] == "Texas"


def test_guest_integer_group_value_is_int() -> None:
    meta = business_entity_from_metadata(fake_idmc._B360_ENTITIES["zlv.guest"], "zlv.guest")
    rec = record_from_search(fake_idmc._fake_records("zlv.guest")[2], meta)
    assert rec.groups[0].rows[0]["nights"] == 3


def test_typed_values_follow_data_type() -> None:
    assert typed_value({"Name": "Male", "Code": "M"}, FieldDataType.PICKLIST) == "Male"
    assert typed_value(7, FieldDataType.INTEGER) == 7
    assert typed_value(2, FieldDataType.DOUBLE) == 2.0
    assert typed_value("true", FieldDataType.BOOLEAN) is True
    assert typed_value("2023-04-20", FieldDataType.DATE) == date(2023, 4, 20)
    assert typed_value(0, FieldDataType.DATETIME) == datetime(1970, 1, 1, tzinfo=UTC)
    assert typed_value(None, FieldDataType.STRING) is None
    assert typed_value("x", FieldDataType.UNKNOWN) == "x"


def test_api_end_to_end(idmc: respx.MockRouter, idmc_http: IdmcHttp) -> None:
    idmc.get(f"{MDM}/metadata/api/v2/objects/tenantModel/datamodel").respond(
        200, json=fake_idmc.datamodel()
    )
    idmc.get(f"{MDM}/metadata/api/v2/objects/businessEntity/c360.person").respond(200, json=PERSON)
    search = idmc.post(f"{MDM}/search/public/api/v1/search").respond(
        200, json=fake_idmc.be_search({"entityType": "c360.person", "recordsToReturn": 10})
    )
    app = create_app()
    app.dependency_overrides[get_b360_data_service] = lambda: B360DataService(idmc_http, MDM)
    client = TestClient(app)
    assert len(client.get("/api/b360/entities").json()["entities"]) == 3
    page = client.get("/api/b360/entities/c360.person/records?limit=10").json()
    assert len(page["records"]) == 10
    assert page["hits"] == 12
    assert [g["name"] for g in page["entity"]["field_groups"]] == [
        "PostalAddress",
        "Phone",
        "Email",
    ]
    sent = search.calls.last.request
    assert b'"entityType":"c360.person"' in sent.content.replace(b" ", b"")
    assert client.get("/api/b360/entities/c360.person/metadata").json()["label"] == "Person"


def test_429_passed_through(idmc: respx.MockRouter, idmc_http: IdmcHttp) -> None:
    route = idmc.get(f"{MDM}/metadata/api/v2/objects/tenantModel/datamodel").respond(429)
    app = create_app()
    app.dependency_overrides[get_b360_data_service] = lambda: B360DataService(idmc_http, MDM)
    assert TestClient(app).get("/api/b360/entities").status_code == 429
    assert route.call_count == 1


def test_openapi_has_typed_schemas() -> None:
    schemas = create_app().openapi()["components"]["schemas"]
    for name in ("BusinessEntity", "FieldGroup", "EntityField", "FieldDataType", "RecordPage"):
        assert name in schemas


def test_bad_entity_name_rejected() -> None:
    app = create_app()
    app.dependency_overrides[get_b360_data_service] = lambda: None
    assert TestClient(app).get("/api/b360/entities/bad%20name/records").status_code == 422
