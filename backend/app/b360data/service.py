"""B360 Data: business entities -> metadata -> first N records. Read-only, never retried.

IDMC JSON is parsed into typed models in app.b360data.wire, right where it arrives.
"""

import time

from app.b360data import endpoints as ep
from app.b360data import wire
from app.b360data.models import BusinessEntity, BusinessEntityList, RecordPage
from app.common.idmc_session import IdmcHttp


class B360DataService:
    def __init__(self, http: IdmcHttp, mdm_url: str) -> None:
        self._http = http
        self._mdm_url = mdm_url.rstrip("/")
        self._meta_cache: dict[str, tuple[float, BusinessEntity]] = {}

    def entities(self) -> BusinessEntityList:
        body: object = self._http.request("GET", self._mdm_url + ep.DATAMODEL, ep.MDM_HEADERS)
        return BusinessEntityList(
            entities=wire.entities_from_datamodel(body), source="GET " + ep.DATAMODEL
        )

    def metadata(self, guid: str) -> BusinessEntity:
        cached = self._meta_cache.get(guid)
        if cached is not None and time.monotonic() - cached[0] < ep.METADATA_CACHE_SECONDS:
            return cached[1]
        body: object = self._http.request(
            "GET", self._mdm_url + ep.BUSINESS_ENTITY.format(guid=guid), ep.MDM_HEADERS
        )
        entity = wire.business_entity_from_metadata(body, guid)
        self._meta_cache[guid] = (time.monotonic(), entity)
        return entity

    def records(self, guid: str, limit: int) -> RecordPage:
        entity = self.metadata(guid)
        body: object = self._http.request(
            "POST",
            self._mdm_url + ep.SEARCH,
            ep.MDM_HEADERS,
            json={"entityType": guid, "search": "*", "pageSize": limit, "recordsToReturn": limit},
        )
        result = wire.search_response(body)
        raw = result.records[:limit]
        return RecordPage(
            entity=entity,
            hits=result.hits,
            records=[wire.record_from_search(r, entity) for r in raw],
            unknown_keys=wire.unknown_keys(raw, entity),
        )
