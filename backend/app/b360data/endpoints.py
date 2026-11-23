"""Business 360 data endpoints (read-only). MDM host, header IDS-SESSION-ID.

Discovery chain (details and page numbers in internal-notes/api-facts.md):
  1. GET  DATAMODEL                      -> every business entity configured in the org
  2. GET  BUSINESS_ENTITY.format(guid)   -> that entity's fields and field groups
  3. POST SEARCH {"entityType": guid}    -> its first N master records

SEARCH and the record shape are documented in the Business 360 REST API Reference (Oct 2026),
Search API pp. 20-36. The metadata paths come from the B360 Postman collection Vamsi supplied
("Meta Data API 3": tenantModel/datamodel), Informatica KB "HOW TO: Get a list of all the search
and facetable attributes in C360 SaaS?" (objects/businessEntity/<guid>) and the reference's
Relationship Metadata API (p. 94-96, same /metadata/api/v2/objects family and JSON style).
The datamodel and businessEntity RESPONSE shapes are NOT printed in the reference: UNVERIFIED.
"""

DATAMODEL = "/metadata/api/v2/objects/tenantModel/datamodel"
BUSINESS_ENTITY = "/metadata/api/v2/objects/businessEntity/{guid}"
SEARCH = "/search/public/api/v1/search"
MDM_HEADERS = ("IDS-SESSION-ID",)

DEFAULT_LIMIT = 10
MAX_LIMIT = 50
METADATA_CACHE_SECONDS = 300  # the reference says model metadata refreshes every 5 min (p. 15)
