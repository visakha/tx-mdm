# Informatica API facts - verified vs. not

Labels:

- **DOC** - stated in an official Informatica document. The research notes in
  `internal-docs/` give page references.
- **CODE** - exercised by this repo's tests, but only against mocks or `fake_idmc`.
- **LIVE** - seen working against Vamsi's real org.

**As of 2026-11-22, nothing is LIVE.** No code in this repo has called the real org.

## Login and session

| Fact | Status |
|---|---|
| `POST https://dm1-us.informaticacloud.com/saas/public/core/v3/login`, body `{username, password}` | DOC |
| The response carries `userInfo.sessionId` and `products[0].baseApiUrl` | DOC |
| v3 calls send `INFA-SESSION-ID`; v2 calls send `icSessionId`; B360 calls send `IDS-SESSION-ID` | DOC (B360 header also seen in Vamsi's own .http file) |
| One v3 session id works for both the v2 and v3 platform calls | DOC |
| Sessions expire after 30 min idle; the backend re-logs in once on a 401 | DOC / CODE |
| The org may use JWT auth instead of session ids (an option since 2025-11) | UNVERIFIED for this org |
| `baseApiUrl` also serves the v2 `/api/v2/job` and activity calls | UNVERIFIED |

## CDI

| Fact | Status |
|---|---|
| Picker: `GET {baseApiUrl}/public/core/v3/objects?q=type=='MTT'` (also WORKFLOW, TASKFLOW), `limit` up to 200, `skip` offset | DOC / CODE |
| The v3 `id` is the `taskFederatedId` for the job call | DOC |
| Run: `POST {baseApiUrl}/api/v2/job {taskFederatedId, taskType}`; type list DMASK/DRS/DSS/MTT/PCS/WORKFLOW | DOC / CODE |
| Advanced taskflows are not run by `/api/v2/job`; use the published `POST {pod}/active-bpel/rt/{apiName}` | DOC / CODE |
| `INFA-SESSION-ID` accepted on the `/active-bpel/rt/` run call | UNVERIFIED (documented only for the status call) |
| Run-id field name in the `/active-bpel/rt/` response | UNVERIFIED |
| Published API name = task name | UNVERIFIED (the UI lets you type a different one) |
| Monitor: `activityMonitor` lists all running jobs with no filter (match on runId + taskId); then `activityLog`, where state 1 = success, 2 = warning, 3 = failed | DOC / CODE |
| Taskflow status: `GET {pod}/active-bpel/services/tf/status/{runId}` | DOC / CODE |
| `startTime`/`endTime` are US Eastern Time; the `*Utc` fields are UTC | DOC |
| Rate limits for these platform calls | Not documented. The backend treats a 429 as a hard stop anyway |

## MDM (Business 360)

| Fact | Status |
|---|---|
| List: `GET {baseApiUrl}/public/core/v3/objects?q=type=='MDM_JOB_DEFINITION'` | DOC / CODE |
| That list has **no** internal `jobDefinitionId` and **no** job type | DOC (by absence) |
| Run: `POST {mdm}/job/public/api/v1/jobInstance/{Ingress\|Egress\|MatchMerge} {jobDefinitionId}` | DOC (Postman collection + PDF) / CODE |
| Status: `GET {mdm}/job/public/api/v1/jobInstance/{id}?details=true`, `_meta.state`, `jobLevelMetrics` | DOC / CODE |
| Job search returns `jobDefinition.id` + `jobType`, used by the resolver | DOC for the call; using it to map definitions to ids is UNVERIFIED |
| `internal.c360.ingress.fileImportJob` is an internal job type, so the resolver skips it | DOC (seen in the collection) |
| Egress `jobType` string | UNVERIFIED. Recognised by the substring "egress" and never hard-coded |
| Search Job Instances body: `search`, `pageSize`, `pageOffset`, `filters{operator, filter[{fieldName, fieldValue}]}`, fieldName `name`/`status`/`jobType` | DOC (PDF pp. 130-132) / CODE (0.9.0) |
| Search response: `totalRecords`, `totalPages`, `currentPage`, `jobInstances[]` each with `id`, `name`, `jobType`, `jobDefinition.id`, `_meta{state, startedAt, startedBy, completedAt, isCompleted}` (epoch ms) | DOC (PDF example pp. 132-134) / CODE |
| Status filter value spelling (we send `RUNNING`, `QUEUED`) | UNVERIFIED. Running jobs found in the unfiltered page are merged in too |
| Sort order of an unfiltered search | UNVERIFIED. Backend sorts by `startedAt`, newest first |
| Search is org-wide (all users), not only the caller's jobs | UNVERIFIED (PDF says you can search by the user who started it, which suggests org-wide) |
| Job types seen live: `b360.ingress.load` (portal ingress 1309395637279657984, 2026-11-22 23:50:47 CST), `c360.egress.etl` (app egress 1309392734552862720, 23:39 CST) | LIVE (portal screen read by Vamsi + backend run list) |
| Field names in the `details=true` error payload | UNVERIFIED. Errors are collected from any `errorMessage`-style field |

## How to promote a fact to LIVE

Do it only with Vamsi's go-ahead and his credentials in `backend/.env`:

1. Run the one read-only call that proves the fact (for example, the MDM job list, or a job
   search).
2. Record the date, the call and the response shape, with ids redacted, in this file.
3. If the fact changes behaviour, write a change proposal under `changes/`.

## Taskflow terminate (2026-11-22)
- DOC (KB 000216333): body {"runid": [...]}, INFA-SESSION-ID or Basic auth, 204 success, max 200
  ids, 500 if any id is invalid. https://knowledge.informatica.com/s/article/000216333?language=en_US
- COMMUNITY: method/path PUT /active-bpel/services/tf/terminate (pod host, same as tf status).
- VERIFIED live 2026-11-22 23:21 CST: a terminated run shows FAILED + code processManuallyTerminated (see below).

## Abort seen live (2026-11-22 23:21 CST, run 1309386379683184640, stopped from the portal Monitor)
- Taskflow status after the terminate: `FAILED` (final), NOT STOPPED or SUSPENDED. errorMessage is a
  JSON string: reason `"Manual Process Termination"` (wrapped in its own extra quotes), code
  `processManuallyTerminated`.
- Child MTT mt_m_MDM_ZLV_TTF_Guest_Basic: `STOPPED`, error "The job was stopped by user
  vvamsi-idmcdev using the API." Rows: source_success 20, target_success 0 (7.6 min).
- Since 0.8.0 the backend sets `aborted: true` on that code and strips the extra quotes; the UI
  shows "ABORTED (IDMC: FAILED)" in grey. An ordinary failure keeps `aborted: false`.

## Taskflows in the activity monitor / log (live, read-only, 2026-11-23 ~00:20 CST)

GET /api/v2/activity/activityMonitor and activityLog list a taskflow's child mapping tasks
(type MTT, e.g. mt_m_MDM_ZLV_TTF_Guest_Basic_EGR, run_id = the mapping task's run number such as
"9"), not the taskflow itself: no TASKFLOW-named rows in either list while
tf_MDM_ZLV_TTF_Guest_Basic_EGR (run 1309401025769136128) was running.

## MDM vs CDI taskflows: naming rule (Vamsi, 2026-11-23 00:41 CST)

- Business 360 / MDM taskflow: the name starts with `tf_MDM_`, or ends with `_EGR` (egress)
  or `_IGR` (ingress). Case doesn't matter. These need the Start-step input field
  `jobInstanceId` (exact name) with a real value.
- CDI taskflow: everything else, in particular `tf_Ldg_*` and `tf_Stg_*`, even when the name
  contains MDM (e.g. `tf_Stg_MDM_CDI_TTF`). These must NOT get `jobInstanceId`.
- Seen live 2026-11-23 06:39Z: `tf_Stg_MDM_CDI_TTF` started with a pre-filled
  `jobInstanceId` answered `IDMC 400 Validation failed, extra: jobInstanceId`.
- The rule lives in ONE place, `backend/app/cdi/taskflow_kind.py`. `GET /api/cdi/tasks`
  tags every item with `domain` ("mdm" | "cdi"). Only TASKFLOW items are classified; mapping
  tasks and linear taskflows are always "cdi".
- Guard: `POST /api/cdi/taskflows/{name}/run` and `POST /api/cdi/runs` answer 400 without
  calling IDMC when an mdm taskflow lacks `jobInstanceId`, or a cdi taskflow carries it.

## B360 Data notebook: deriving business entities from metadata (0.9.5, 2026-11-23)

Vamsi (00:47 CST): "as a thought experiment, see if you can derive it by making those API calls."
Nothing about his org is hardcoded. Three calls, each derived from the one before. All are
read-only, go to the MDM pod host (`IDMC_MDM_URL`, default https://usw1-mdm.dm1-us.informaticacloud.com)
with header `IDS-SESSION-ID`, are never retried, and a 429 is passed through as HTTP 429.
Reference = internal-docs/B360_October2026_Business360_REST-API_Reference_en.pdf (page numbers
are the PDF's printed page numbers). Code: backend/app/b360data/ (wire.py is the only place raw
JSON is read; everything after it is typed Pydantic models, see models.py).

Step 1 - which business entities exist
- Call: `GET {mdm}/metadata/api/v2/objects/tenantModel/datamodel`.
- Source of the PATH: Postman "Meta Data API 3" in internal-docs/B360_API_collection.postman.json
  (no saved response), and the MuleSoftForge Informatica MDM connector "Metadata Read" docs
  (https://docs.mulesoftforge.com/connectors/mule-infa-mdm-connector/operations/metadata-read):
  DATAMODEL = "full schema for the organization: all business entities, relationships, field
  groups, lookup types"; a 401 there means the user lacks the Metadata / System Administrator
  scope. The reference PDF does NOT print this call.
- How we read it: every JSON object anywhere in the response whose `eClass` ends with
  `#//BusinessEntity`, or that is listed under a `businessEntity` key, with a `guid` (else
  `name`) -> one entity {name = guid, label = label.en}. Sorted by label.
- UNVERIFIED: the response shape. The eClass/guid/label style is copied from the documented
  Relationship Metadata API (step 2). Tested only against backend/dev/fake_idmc.py.
- Endpoint: `GET /api/b360/entities` -> BusinessEntityList.

Step 2 - what one entity looks like (fields, field groups, types)
- Call: `GET {mdm}/metadata/api/v2/objects/businessEntity/{guid}` with guid from step 1
  (e.g. `c360.person`).
- Sources: MuleSoftForge "Metadata Read" (BUSINESS_ENTITY = `/metadata/api/v2/objects/businessEntity/{objectInternalId}`;
  on 404 use DATAMODEL to find the id) and Informatica KB "HOW TO: Get a list of all the search
  and facetable attributes in C360 SaaS?"
  (https://knowledge.informatica.com/s/article/How-can-I-get-a-list-of-all-the-search-and-facetable-attributes?language=en_US):
  look for `"searchable": true` / `"facetable": true` in this response.
- Shape we expect, from the documented sibling call `GET {mdm}/metadata/api/v2/objects/relationship/?name=`
  (Relationship Metadata API, pp. 94-96): paged `{content: [...]}` or one object; each object has
  `eClass "http://informatica.com/mdm/v2/Core#//<Type>"`, `guid`, `name`, `label {en}` and a
  `field` list; each field has eClass `...#//TextField` / `...#//IntegerField`, `name`,
  `mandatory`, `allowMany`, `options`, `label {en}`.
- How we read it: a `field` entry that has its own `field` list (or an eClass ending in
  FieldGroup) is a FIELD GROUP; everything else is a top-level FIELD. Field data type = eClass
  suffix mapped to FieldDataType (TextField -> STRING, IntegerField -> INTEGER documented p. 95;
  DateField, BooleanField, LookupField, DecimalField ... same naming, UNVERIFIED; anything else ->
  UNKNOWN with raw_type kept). allowMany false -> cardinality ONE, else MANY. searchable from
  `searchable` or `options.searchable`.
- Data types modelled (FieldDataType): String, Picklist, Dependent Picklist, Date, Double,
  Boolean, Integer ("data types of business entity fields", p. 150) plus Decimal and DateTime
  (search-term formats table, pp. 113-114), plus UNKNOWN.
- Cache: the reference says model metadata "is refreshed and cached every five minutes" (p. 16);
  the backend caches each entity's metadata for 300 s too.
- UNVERIFIED: how this response nests field groups, the eClass names other than
  TextField/IntegerField, and where `searchable` sits. Tested only against the fake.
- Endpoint: `GET /api/b360/entities/{name}/metadata` -> BusinessEntity (call this first on the
  real org to see what it really returns).

Step 3 - the first 10 records
- Call: `POST {mdm}/search/public/api/v1/search` body
  `{"entityType": "<guid>", "search": "*", "pageSize": 10, "recordsToReturn": 10}`.
- Source: Search API, pp. 20-36 (request parameters pp. 25-26: entityType, search, fields,
  filters, pageSize, pageOffset, recordsToReturn, recordOffset, maxRecords, sort; response
  pp. 26-27: `searchResult {hits, records[]}`, each record has `_meta {businessId, ...}`;
  sample pp. 33-34: keys prefixed with the entity without dots (`c360person.firstName`), field
  groups are arrays of objects (`c360person.Phone: [{phoneNumber}]`), picklists are
  `{"Name": ...}`). Also Postman "Search Business Entity" and his idmc_collection.http.
- How the metadata drives it: columns = step 2's top-level fields (in order); field groups =
  step 2's field groups, each row typed by the group's fields. Record keys the metadata did not
  describe are returned in `unknown_keys` and NOT shown as columns (never guessed).
- Values are typed by the declared data type: INTEGER -> int, DOUBLE/DECIMAL -> float,
  BOOLEAN -> bool, DATE -> date, DATETIME -> datetime (epoch ms or ISO), picklist object ->
  its Name, anything else -> str.
- UNVERIFIED: whether `search: "*"` returns all records (the reference's samples search a real
  term); limit stays 1..50.
- Endpoint: `GET /api/b360/entities/{name}/records?limit=10` -> RecordPage.
- Confidence: search HIGH (documented); businessEntity metadata MEDIUM (path from two outside
  sources, shape guessed from the documented sibling); tenantModel/datamodel MEDIUM-LOW (path
  known, shape not printed anywhere we have).

## MDM vs CDI mapping tasks (0.9.6, Vamsi's yes 2026-11-23 00:58 CST)

- Extends the taskflow naming rule to mapping tasks (MTT), in the same place:
  backend/app/cdi/taskflow_kind.py (`is_mdm_mapping_task`, `mapping_task_domain`).
- MDM mapping task: name starts `mt_m_MDM_` or ends `_EGR` / `_IGR` (any case).
  `mt_m_Ldg_*` and `mt_m_Stg_*` stay CDI even with MDM in the name.
- Live names (from /api/cdi/tasks on his backend, 2026-11-23 00:57 CST):
  mt_m_MDM_ZLV_TTF_Guest_Basic -> mdm, mt_m_MDM_ZLV_TTF_Guest_Basic_EGR -> mdm,
  the 9 mt_m_Ldg_/mt_m_Stg_ tasks -> cdi.
- `GET /api/cdi/tasks` tags them `domain: "mdm"`. `POST /api/cdi/runs` answers 400 for an MDM
  mapping task ("runs via its taskflow") and never calls IDMC: the mapping reads the taskflow's
  jobInstanceId, so a lone start would fail with "[FATAL] Invalid/Default JobInstanceId".
- CDI Monitor and taskflow history are unchanged (they still list these child rows by name).
