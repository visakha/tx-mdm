"""DesignClient: the read-only IDMC calls of the Design notebook (0.9.15). Every call is a
registry row (app/common/idmc_registry.py), so it shows in /docs-idmc and Copy IDMC curl.
Replies are parsed into the registry's typed wire models; fields not modelled are dropped
(for connections that is how secrets never enter tx-mdm)."""

from enum import StrEnum

from pydantic import TypeAdapter

from app.cdi import endpoints as cdi_ep
from app.common import idmc_registry as idmc
from app.common.idmc_registry import (
    ConnectionWire,
    MappingWire,
    MtTaskWire,
    RuntimeEnvironmentWire,
    V3ObjectRow,
    V3ObjectsResponse,
    V3ReferenceRow,
    V3ReferencesResponse,
)
from app.common.idmc_session import IdmcHttp
from app.design import endpoints as ep


class RefType(StrEnum):
    """refType values of v3 references (doc example spells Uses; usedBy per the table)."""

    USES = "Uses"
    USED_BY = "usedBy"


_RUNTIME_LIST = TypeAdapter(list[RuntimeEnvironmentWire])
_CONNECTION_LIST = TypeAdapter(list[ConnectionWire])
_MAPPING_ONE_OR_MANY = TypeAdapter(MappingWire | list[MappingWire])


class DesignClient:
    def __init__(self, http: IdmcHttp, platform_url_override: str = "") -> None:
        self._http = http
        self._platform_url_override = platform_url_override.rstrip("/")

    def platform_url(self) -> str:
        """baseApiUrl from the v3 login (.../saas); v2 calls use it too (INFERRED, as CDI)."""
        return self._platform_url_override or self._http.session.current().base_api_url.rstrip("/")

    # ---- v3 ----

    def list_objects(self, type_value: str) -> list[V3ObjectRow]:
        found: list[V3ObjectRow] = []
        skip = 0
        while True:
            body = self._http.request(
                idmc.PLATFORM_OBJECTS,
                self.platform_url() + cdi_ep.OBJECTS,
                params={"q": f"type=='{type_value}'", "limit": cdi_ep.PAGE_SIZE, "skip": skip},
            )
            page = V3ObjectsResponse.model_validate(body or {}).objects
            found.extend(page)
            if len(page) < cdi_ep.PAGE_SIZE:  # count can lag, so page until a short page
                return found
            skip += cdi_ep.PAGE_SIZE

    def references(self, object_id: str, ref_type: RefType) -> list[V3ReferenceRow]:
        found: list[V3ReferenceRow] = []
        skip = 0
        url = self.platform_url() + ep.OBJECT_REFERENCES.format(object_id=object_id)
        while True:
            body = self._http.request(
                idmc.OBJECT_REFERENCES,
                url,
                params={"refType": ref_type.value, "limit": ep.REFERENCES_PAGE_SIZE, "skip": skip},
            )
            page = V3ReferencesResponse.model_validate(body or {}).references
            found.extend(page)
            if len(page) < ep.REFERENCES_PAGE_SIZE:
                return found
            skip += ep.REFERENCES_PAGE_SIZE

    # ---- v2 ----

    def mttask_by_frs(self, federated_id: str) -> MtTaskWire:
        url = self.platform_url() + ep.MTTASK_BY_FRS.format(federated_id=federated_id)
        return MtTaskWire.model_validate(self._http.request(idmc.MTTASK_BY_FRS, url))

    def mttask_by_id(self, task_id: str) -> MtTaskWire:
        url = self.platform_url() + ep.MTTASK_BY_ID.format(task_id=task_id)
        return MtTaskWire.model_validate(self._http.request(idmc.MTTASK_BY_ID, url))

    def mapping_by_id(self, mapping_id: str) -> MappingWire:
        url = self.platform_url() + ep.MAPPING_BY_ID.format(mapping_id=mapping_id)
        return MappingWire.model_validate(self._http.request(idmc.MAPPING_BY_ID, url))

    def mappings_by_name(self, name: str) -> list[MappingWire]:
        body = self._http.request(
            idmc.MAPPING_SEARCH, self.platform_url() + ep.MAPPING_SEARCH, params={"name": name}
        )
        parsed = _MAPPING_ONE_OR_MANY.validate_python(body)
        return parsed if isinstance(parsed, list) else [parsed]

    def runtime_environments(self) -> list[RuntimeEnvironmentWire]:
        body = self._http.request(
            idmc.RUNTIME_ENVIRONMENTS, self.platform_url() + ep.RUNTIME_ENVIRONMENTS
        )
        return _RUNTIME_LIST.validate_python(body or [])

    def connections(self) -> list[ConnectionWire]:
        body = self._http.request(idmc.CONNECTIONS, self.platform_url() + ep.CONNECTIONS)
        return _CONNECTION_LIST.validate_python(body or [])

    def connection(self, connection_id: str) -> ConnectionWire:
        url = self.platform_url() + ep.CONNECTION_BY_ID.format(connection_id=connection_id)
        return ConnectionWire.model_validate(self._http.request(idmc.CONNECTION_BY_ID, url))
