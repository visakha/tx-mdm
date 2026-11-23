# MDM (Business 360) job picker: listing job definitions through metadata APIs

Researched 2026-11-22. Read-only work: public docs plus the local B360 reference and Postman collection. Nothing was called against Vamsi's org.
Labels: **DOCUMENTED** = official Informatica doc or KB. **COMMUNITY** = Informatica Network post. **UNVERIFIED** = inferred and needs a live probe.

## Bottom line
- **Yes, there is a documented metadata listing.** The IDMC platform v3 objects API accepts `type=='MDM_JOB_DEFINITION'`. **DOCUMENTED** in the official IDMC REST API Reference, July 2026, "Finding an asset", p.236.
- **The catch:** it returns the FRS asset `id` (a GUID-style string), `path`, `type`, `description`, `updatedBy` and `updateTime`. It does not return the **internal ID** that `jobInstance/Ingress|Egress|MatchMerge` needs as `jobDefinitionId`. It also doesn't say whether a job is ingress, egress or match-merge. The B360 reference still says the internal ID "is visible in Business 360 Console" (local PDF, line ~7573).
- So the picker can be **listed** from metadata, but the step from **asset id to internal jobDefinitionId and job kind** needs one live probe (see section 3).
- The B360 metadata service (`/metadata/api/v2/objects/{type}`) has **no documented job-definition type**. Its documented types are relationship, businessEntity, uiApplication and tenantModel.

## 1. Listing APIs

### 1a. IDMC v3 objects, `MDM_JOB_DEFINITION`: DOCUMENTED (primary)
```
GET {baseApiUrl}/public/core/v3/objects?q=type=='MDM_JOB_DEFINITION'&limit=200&skip=0
INFA-SESSION-ID: <userInfo.sessionId from v3 login>
Accept: application/json
```
- `baseApiUrl` comes from the v3 login response, e.g. `https://usw1.dm1-us.informaticacloud.com/saas`. The doc example is `GET /saas/public/core/v3/objects?...`. **Note:** this is the platform host, **not** the MDM pod host (`usw1-mdm...`) used by the B360 job APIs.
- The MDM SaaS types listed for the filter are: MDM_BUSINESS_ENTITY, MDM_REFERENCE_ENTITY, MDM_HIERARCHY, MDM_RELATIONSHIP, **MDM_JOB_DEFINITION**, MDM_AUTHORIZATION, MDM_BUSINESS_EVENT, MDM_REPORT_SET, MDM_REPORT, MDM_DYNAMIC_POOL, MDM_APPLICATION, MDM_SRC_SYSTEM, MDM_APP_COMPONENT, MDM_APP_PAGE. Types aren't case-sensitive.
- Other filters: `location=='Project/Folder'`, `updateTime>=...`, `updatedBy==`, `tag==`. They combine with `and`.
- Paging: max 200 per call. Use `skip` for more. `count` can be imprecise for about 90 seconds on large result sets.
- Response: `{ count, objects: [ { id, path, type, description, updatedBy, updateTime, tags, sourceControl{...}, customAttributes{...} } ] }`.
- The response leaves out assets the user can't read. A KB shows FRS permission overrides apply to MDM_JOB_DEFINITION too.
- Sources:
  - Official PDF, IDMC REST API Reference July 2026, Objects > Finding an asset (pp.235–239): https://docs.informatica.com/content/dam/source/GUID-B/GUID-BA8ED0B4-AB32-46B1-A7B8-358FAB844D6B/67/en/IICS_July2026_(REST-API)Reference_en.pdf
  - The same page in HTML (docs-test mirror): https://docs-test.informatica.com/cloud-common-services/administrator/current-version/rest-api-reference/platform-rest-api-version-3-resources/objects/finding-an-asset.html
  - KB, the FRS error naming MDM_JOB_DEFINITION as an FRS asset type: https://knowledge.informatica.com/s/article/ERROR-Match-Job-Definition-failure-In-SaaS?language=en_US
- Header note: KB 000196351 calls v3 objects with `IDS-SESSION-ID: <icSessionId>`, so either header style is accepted in practice. The docs use `INFA-SESSION-ID`. https://knowledge.informatica.com/s/article/000196351

### 1b. `/public/core/v3/objects/{id}/references`: DOCUMENTED, no help here
It returns `appContextId`, a service-specific ID, but the doc says that only applies to Data Integration and Data Ingestion and Replication, not MDM. Same PDF, pp.240–241.

### 1c. B360 metadata service `/metadata/api/v2/objects/{type}`: DOCUMENTED types only, no job type
- Documented: `relationship/?name=` (local PDF line 5635ff), `businessEntity/<guid>` (KB https://knowledge.informatica.com/s/article/How-can-I-get-a-list-of-all-the-search-and-facetable-attributes?language=en_US). The Postman collection has `uiApplication/c360.c360` and `tenantModel/datamodel`.
- Responses are paged Spring-style (`content[]`, `size`, `number`, `last`), and `guid` is the internal ID. So *if* a job-definition type existed here, it would hand back the internal ID directly.
- **UNVERIFIED:** whether `tenantModel/datamodel`, or some undocumented type such as `jobDefinition`, includes job definitions. One read-only GET of `tenantModel/datamodel` would show it (the Postman collection already has this call).

### 1d. Export API: DOCUMENTED that job definitions can be exported, package format undocumented
- "MDM SaaS assets: ... Job definitions" is listed as exportable through `/public/core/v3/export`: https://onlinehelp.informatica.com/IICS/dev/cdi/en/tt-cloud-rest-api/Export_and_import.html
- Flow: POST export with the object ids from 1a, poll the status, GET `.../export/{id}/package` (a zip).
- **UNVERIFIED:** the JSON inside the package. It very likely carries the internal ID and the job kind, because import matches on internal ID. A KB says "MDM SaaS uses internal IDs for MDM assets ... during asset migration": https://knowledge.informatica.com/s/article/Best-Practices-for-Migrating-Assets-via-SDLC-in-MDM-SaaS?language=en_US
- Heavyweight, asynchronous and zip-based. It works as a "refresh catalog" button, not a per-page call.

## 2. What each source returns

| Source | Internal jobDefinitionId | Display name | Job kind (ingress/egress/match-merge) | Status |
|---|---|---|---|---|
| v3 objects MDM_JOB_DEFINITION | No (FRS `id` only) | Yes, last segment of `path` | No (type is just MDM_JOB_DEFINITION) | DOCUMENTED |
| `/frs/v1/Documents('<id>')` | Probably | Yes | Probably | UNVERIFIED for MDM (KB shows it for CDQ assets) |
| v3 export package | Probably | Yes | Probably | Export DOCUMENTED, contents UNVERIFIED |
| B360 job search `jobInstances[].jobDefinition.id` | Yes, for jobs that have run | `name` | `jobType` | DOCUMENTED |

Job type strings seen in the docs and collection:
- `c360.ingress.load` (Postman "Job Search and Filter")
- `c360.be.matchmerge`, `c360.be.match.startTraining`, `c360.be.match.finishTraining` (local PDF ~7900)
- **Egress jobType string: not found** in the PDF, the collection or the web. UNVERIFIED. Expect something like `c360.egress.*`, so read it from a live search response rather than hard-coding it.
- **Caution:** in the doc example, an ingress run started from the UI file import shows `jobDefinition.id = "internal.c360.ingress.fileImportJob"`, a system job, not the user's definition ID. So job-search IDs aren't always user job definitions. Filter those `internal.*` IDs out. (Local PDF ~8131, KB https://knowledge.informatica.com/s/article/Read-the-job-Instance-Id-details-via-Public-API-in-SAAS?language=en_US)

Internal ID facts (COMMUNITY): the internal ID is assigned at creation, derived from the asset name, and unique per org. **Renaming an asset does not change it.** So the display name in `path` can't be trusted as the ID. https://network.informatica.com/s/question/0D5VM000016NqsV0AS/b360-import-error-cant-import-the-asset-because-its-internal-id-matches-the-internal-id-of-a-deleted-asset

Related (KB 000219814, DOCUMENTED but a different route): the CAI process endpoint `POST <cai url>/active-bpel/rt/MDMIngress` takes `jobDefinitionId: "<GUID of ingress job>"`. The same KB says that route is "not documented and not a public API". **UNVERIFIED:** whether the public `jobInstance/Ingress` accepts the FRS GUID in place of the internal ID. https://knowledge.informatica.com/s/article/000219814?language=en_US

## 3. Recommended design (metadata-driven, as Vamsi asked)
1. **List:** v3 objects `type=='MDM_JOB_DEFINITION'`, paged by 200, showing the name and folder from `path`, plus `updateTime` and `updatedBy`.
2. **Resolve ID and kind per job:** use whichever of these works in one live read-only probe on a single asset, in this order:
   a. `GET {podBase}/frs/v1/Documents('<objects.id>')` with the session header. Look for the internal ID or name and the job type in the document.
   b. A `GET .../metadata/api/v2/objects/tenantModel/datamodel` read, checking for job definitions.
   c. Export one MDM_JOB_DEFINITION and read the package JSON.
   d. Last resort: try the FRS `id` as `jobDefinitionId`. **Skip this one.** It would start a real job, so it isn't read-only and needs Vamsi's OK.
3. **Enrich and fallback:** B360 job search (`POST /job/public/api/v1/search`, `search:"*"`, page through `pageSize`/`pageOffset`) gives the internal ID plus `jobType` for anything that has run. Join it to the list by name to fill gaps and show the last run status.
4. Cache the resolved name → internal ID → kind map. Refresh it on demand.

**Live probe needed (Vamsi's approval):** steps 2a and 2b are read-only GETs against his org with the saved IDMC login. They settle the open questions in about two calls. Nothing in this research made those calls.
