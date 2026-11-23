"""0.9.12: picklist allowed values from Reference 360 (rdm.value.be.* entities).

Every MDM call is forwarded to the fake IDMC app (dev/fake_idmc.py). Never his org.
"""

from collections.abc import Iterator

import httpx
import pytest
import respx
from fastapi.testclient import TestClient

from app.b360data import wire
from app.b360data.models import (
    BusinessEntitySummary,
    EntityCategory,
    EntityField,
    FieldDataType,
    FieldLookup,
    LookupStatus,
)
from app.b360data.service import B360DataService
from app.common.idmc_session import IdmcHttp
from app.dependencies import get_b360_data_service
from app.main import create_app
from dev import fake_idmc
from tests.conftest import MDM

FAKE = TestClient(fake_idmc.app)
BASE = "/api/b360/entities/zlv_guest"
RDM = "rdm.value.be._ent_phonetype"


@pytest.fixture
def api(idmc: respx.MockRouter, idmc_http: IdmcHttp) -> Iterator[TestClient]:
    def forward(request: httpx.Request) -> httpx.Response:
        reply = FAKE.request(
            request.method,
            request.url.path,
            params=dict(request.url.params),
            content=request.content,
            headers={"content-type": "application/json"},
        )
        return httpx.Response(reply.status_code, content=reply.content)

    idmc.route(url__startswith=MDM).mock(side_effect=forward)
    fake_idmc.RDM_SEARCHES.clear()
    fake_idmc._CREATED.clear()
    service = B360DataService(idmc_http, MDM)  # one instance: the 5-minute cache is per service
    app = create_app()
    app.dependency_overrides[get_b360_data_service] = lambda: service
    yield TestClient(app)


def _ph_typ(meta: dict[str, object]) -> dict[str, object]:
    groups = meta["field_groups"]
    assert isinstance(groups, list)
    phone = next(g for g in groups if g["name"] == "x_phone")
    return next(f for f in phone["fields"] if f["name"] == "ph_typ")


def test_metadata_shows_the_reference_list(api: TestClient) -> None:
    lookup = _ph_typ(api.get(f"{BASE}/metadata").json())["lookup"]
    assert lookup["code_list"] == "Enterprise PhoneType"
    assert lookup["found_in"] == "lookupCodeList"
    assert lookup["rdm_entity"] == RDM
    assert lookup["status"] == "LABEL_MATCH"
    assert "lookupCodeList" in lookup["raw_keys"]


def test_form_options_are_the_11_codes_and_cached(api: TestClient) -> None:
    for _ in range(2):
        schema = api.get(f"{BASE}/form-schema").json()
        phone = next(g for g in schema["groups"] if g["name"] == "x_phone")
        typ = next(f for f in phone["fields"] if f["name"] == "ph_typ")
        assert [o["code"] for o in typ["options"]] == fake_idmc._RDM_PHONETYPE_CODES
        assert typ["options_source"] == "REFERENCE_360"
    assert fake_idmc.RDM_SEARCHES == [RDM]  # second call served from the 5-minute cache


def test_generate_uses_real_codes_and_says_so(api: TestClient) -> None:
    rows = api.post(f"{BASE}/records/generate", json={"count": 5, "seed": 3}).json()
    phones = [
        r["values"]["ph_typ"]
        for row in rows["rows"]
        for g in row["groups"]
        if g["group"] == "x_phone"
        for r in g["rows"]
    ]
    assert phones and all(p in fake_idmc._RDM_PHONETYPE_CODES for p in phones)
    rule = next(r["rule"] for r in rows["rules"] if r["field"] == "x_phone.ph_typ")
    assert "Reference 360 list " + RDM in rule


def _field(lookup: FieldLookup) -> EntityField:
    return EntityField(
        name="ph_typ",
        label="Phone type",
        data_type=FieldDataType.PICKLIST,
        raw_type="LookupField",
        searchable=False,
        mandatory=True,
        lookup=lookup,
    )


_RDM_LIST = [
    BusinessEntitySummary(
        name=RDM,
        label="RDM values of list Enterprise PhoneType",
        category=EntityCategory.REFERENCE,
        focus=False,
    )
]


def test_no_named_list_is_a_labelled_guess() -> None:
    found = wire.resolve_lookup(_field(FieldLookup()), _RDM_LIST)
    assert found is not None
    assert found.rdm_entity == RDM and found.status is LookupStatus.GUESSED


def test_unknown_code_list_is_not_invented() -> None:
    found = wire.resolve_lookup(_field(FieldLookup(code_list="Nope List")), _RDM_LIST)
    assert found is not None
    assert found.rdm_entity is None and found.status is LookupStatus.NOT_FOUND


def test_raw_lookup_attribute_is_read() -> None:
    node = wire.WireNode.model_validate(
        {"eClass": "x#//LookupField", "name": "ph_typ", "lookupCodeList": "Enterprise PhoneType"}
    )
    lookup = wire.lookup_from_node(node)
    assert lookup.code_list == "Enterprise PhoneType" and lookup.found_in == "lookupCodeList"
    direct = wire.lookup_from_node(
        wire.WireNode.model_validate({"name": "x", "referenceEntity": {"guid": RDM}})
    )
    assert direct.rdm_entity == RDM and direct.status is LookupStatus.DECLARED
