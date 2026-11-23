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

# 0.9.9 Records paging, filters, sort (Search API pp. 20-36):
#   recordOffset + recordsToReturn + pageSize (p. 25-26); filters.filter[] {fieldName, comparator,
#   fieldValue} (p. 23-25; STARTS_WITH accepts partial values); sort [{fieldName, order}] (p. 26).
#   fieldName for an entity field = "<entity guid without dots>.<field>" as in c360person.firstName
#   (p. 27, 30); for a custom entity the prefix the search reply itself uses is preferred.
#   Last updated = _meta.lastUpdateDate (p. 27 response, p. 31 filter example). The sort on it is
#   UNVERIFIED (the reference only shows sort: [] and the field in a filter).
PAGE_SIZE = 10
MAX_PAGE = 1000  # 10,000-record search window (maxRecords note p. 26)
LAST_UPDATE_FIELD = "_meta.lastUpdateDate"
# Read Master Record by Business ID, pp. 56-58: GET .../entity/<businessEntity>/<businessId>
READ_RECORD = "/business-entity/public/api/v1/entity/{guid}/{business_id}"

# 0.9.10 Source (xref) records, all in the B360 REST API Reference (Oct 2026):
#   Read Source Records by Master Record, p. 70-71: GET .../entity-member/<entity>/<businessId>
#     -> {"content": [{"sourcePKey", "sourceSystem"}]}
#   Read Source Record, pp. 80-84: GET .../entity-xref/<entity>/<sourceSystem>/<sourcePKey>
#   Update Source Record Field, pp. 88-90: PATCH same URI, body [{op, path, value}]
#     (chosen over Update Source Record PUT, pp. 85-88, which replaces the whole record and
#     CREATES one when it does not exist).
#   No documented call lists ALL source records of an entity ("Currently, source records aren't
#   searchable", p. 82), so Records (S) is master-driven plus a sourceSystem + sourcePKey lookup.
ENTITY_MEMBER = "/business-entity/public/api/v1/entity-member/{guid}/{business_id}"
ENTITY_XREF = "/business-entity/public/api/v1/entity-xref/{guid}/{source_system}/{source_pkey}"
MAX_SOURCES_READ = 20  # Read Source Record calls per master record, one at a time
PICKLIST_SAMPLE = 50  # records read (one Search API call) to observe real picklist values
RDM_PAGE_SIZE = 200  # 0.9.12: one Search API page of a Reference 360 value entity
RDM_CACHE_SECONDS = 300  # 0.9.12: allowed values cached 5 min, like metadata

# 0.9.12 Merge (M), all in the B360 REST API Reference (Oct 2026):
#   Merge API, p. 106: POST .../entity-group/<businessEntity>, body = JSON array of up to 10
#     {"businessId"} (or {"sourcePKey", "sourceSystem"}) -> {"approvalRequired", "businessId"
#     (the surviving master)}.
#   Update Master Record Field, pp. 67-68: PATCH .../entity/<businessEntity>/<businessId>
#     ?sourceSystem=<id>, body [{op, path, value}] -> {"approvalRequired"}. Used ONLY to apply
#     the per-field winners Vamsi picks on the surviving master (a steward override).
#   Unmerge API, pp. 107-110: POST .../entity-group/<businessEntity>/<businessId>
#     ?_keepRelsWith=BUSINESS_ID[&_allowMergeBack=MAY_MERGE], body [{sourcePKey, sourceSystem}]
#     -> {"approvalRequired"}. Takes SOURCE keys, not business ids.
ENTITY_GROUP = "/business-entity/public/api/v1/entity-group/{guid}"
ENTITY_GROUP_MASTER = "/business-entity/public/api/v1/entity-group/{guid}/{business_id}"
MAX_MERGE = 10
MAX_SOURCES_PAGE = 50  # 0.9.12.3: most source records read for one Records (S) page
