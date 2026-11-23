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

# 0.9.8 Add records. Create Master Record, reference pp. 51-55:
#   POST <baseApiURL>/business-entity/public/api/v1/entity/<businessEntity>
#        ?sourceSystem=<sourceSystem>&sourcePKey=<pkey>
#   body = the record's fields by internal name; 200 -> {"approvalRequired", "id" (deprecated),
#   "businessId"} (p. 55). The ONLY write call in the B360 Data notebook.
CREATE_RECORD = "/business-entity/public/api/v1/entity/{guid}"
MAX_CREATE = 100

# Source systems: the reference documents NO list call. This path follows the same
# /metadata/api/v2/objects/<type> family as businessEntity. UNVERIFIED: may 404 on a real org;
# the service then reports NOT_AVAILABLE and the TOML allowed list is used alone.
SOURCE_SYSTEMS = "/metadata/api/v2/objects/sourceSystem"
