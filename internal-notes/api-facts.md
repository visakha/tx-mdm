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

## B360 Data focus list (0.9.7, Vamsi 2026-11-23 01:00-01:04 CST)
- Live (his backend, 0.9.5, 2026-11-23 ~00:59 CST): datamodel lists 106 entities - 97 `rdm.*`,
  5 `entity.*` templates, `c360.person`, `c360.organization`, `zlv_guest` (6 STRING fields, no
  field groups, 21 records), `zlv_person` (5 fields + group `alt_id`, 0 records).
- His words: "let's focus on ZLV guest only. c360 person is out of the box" and "what business
  entity [to] be shown should be written to a config file or a toml file in the backend".
- So `scope=focus` filters the derived list to the TOML entries; nothing else is hardcoded.
  Category is by name prefix only (`app/b360data/scope.py: category_of`).


## B360 Add records (0.9.8, Vamsi 2026-11-23 01:05-01:10 CST)

- Create Master Record (reference pp. 51-55): `POST {mdm}/business-entity/public/api/v1/entity/<entity>?sourceSystem=<ss>&sourcePKey=<pkey>`,
  header `IDS-SESSION-ID`, body = the record's fields by internal name (picklists as `{"Code": ...}`, the
  reference example's shape; UNVERIFIED on his org - zlv_guest has no picklists). 200 reply:
  `{"approvalRequired": bool, "id": "<deprecated>", "businessId": "..."}` (p. 55). Code: `app/b360data/service.py` `create`.
- sourceSystem is REQUIRED. Vamsi's source systems (his words, 01:09-01:10 CST, corrected to all
  lowercase): `zlv_ttf`, `zlv_eci`; plus the out-of-box `c360.default.system` (seen in the Postman
  collection). Seeded in `backend/b360_entities.toml` `[sources]`, default `zlv_ttf` (builder's choice:
  the egress job is Src_TTF). The internal ids are as he dictated; NOT yet checked against IDMC - if IDMC
  rejects one, the result row shows IDMC's own error text.
- Listing source systems: the reference has NO documented call (searched 2026-11-23). The backend tries
  `GET {mdm}/metadata/api/v2/objects/sourceSystem` (same /metadata/api/v2/objects family as businessEntity)
  - UNDOCUMENTED, UNVERIFIED; any non-429 error -> `NOT_AVAILABLE`, the TOML list is used alone.
- Default sourcePKey: `TXMDM-<yyyymmddHHMMSS>-<n>` (backend local time, n = 1-based row in the request).
- Never called against the live org by the builder: tests use respx + the fake IDMC only.

## B360 Records paging, filters, sort, Business ID lookup (0.9.9, Vamsi 2026-11-23 ~01:30 CST)

All from the B360 REST API Reference (Oct 2026). Search: `POST {mdm}/search/public/api/v1/search`.

- Paging: `recordOffset` = (page-1)*10, `recordsToReturn` = 10, `pageSize` = 10 (pp. 25-26). Page count
  = ceil(`hits` / 10). The search window is 10,000 records, so the API refuses page > 1000.
- Name filters: `filters.filter[] = {fieldName, comparator: "STARTS_WITH", fieldValue}` (pp. 23-25;
  STARTS_WITH / CONTAINS accept partial values). fieldName = `<prefix>.<field>`, where prefix is the one
  the search reply itself uses for root keys (learned from the last reply, `wire.key_prefix`), else the
  documented rule "entity id without dots" (`c360person.firstName`, p. 27). For zlv_guest that is
  `zlv_guest.first_name` / `zlv_guest.last_name`. UNVERIFIED against his org. The first/last name field
  is the root field whose name, ignoring case and `_`, is `firstname` / `lastname`; none -> 400, nothing sent.
- Last updated: `_meta.lastUpdateDate` (p. 27 search sample, epoch ms as a STRING; pp. 56-57 / 61-62 _meta
  table "date when the master record was last updated" - any channel). Sort:
  `sort: [{"fieldName": "_meta.lastUpdateDate", "order": "DESCENDING" | "ASCENDING"}]` (p. 26 sort params;
  p. 31 uses `_meta.lastUpdateDate` as a filter fieldName). Using it as a SORT fieldName is UNVERIFIED.
  Only this column sorts (Vamsi: "Only that one").
- Business ID: exact match through Read Master Record by Business ID,
  `GET {mdm}/business-entity/public/api/v1/entity/<businessEntity>/<businessId>` (pp. 56-58). Reply keys
  are plain field names (no prefix) plus `_meta` (lastUpdateDate here is an epoch NUMBER). 404 / 400 ->
  empty page with a note (our choice); 429 passed through, never retried.
- System metadata: fields/groups flagged system in the metadata reply (UNVERIFIED flag names `system`,
  `systemField`, `isSystem`) or named with a leading `_` are SYSTEM; plus the documented system items not
  in the reply (`_meta` group pp. 56-57, validationType / validationState / recordStateIndicator /
  `_indexValidationError.code`) marked `origin_source = DOCUMENTED`.

## Live facts from the 0.9.9 bridge test (read-only, 2026-11-23 ~02:00 CST)

- **LIVE**: source-system discovery `GET {mdm}/metadata/api/v2/objects/sourceSystem` (UNDOCUMENTED) works on
  his org and lists rdm.system.default, b360.default.system, c360.default.system, zlv_ttf, zlv_eci.
- **LIVE**: Search API filter STARTS_WITH on `zlv_guest.first_name` works (the `<prefix>.<field>` shape).
- **LIVE**: Create Master Record with sourceSystem zlv_ttf: both 5-record Send batches landed (zlv_guest 31 hits).
- **LIVE** metadata: system fields validationType, validationState, recordStateIndicator,
  _indexValidationError.code; `_meta` group businessId, id, businessEntity, state, validation, consolidation,
  searchIndex, score, createdBy, creationDate, updatedBy, lastUpdateDate, changeList.
- **OPEN (live)**: his created records show ffr_first_name / ffr_last_name NULL in the master although the
  preview filled them. ("ffr" = freeform reason, his words 02:01 CST: free text for when that field's
  validation fails.) **CODE**: `test_create_body_carries_every_filled_field` proves tx-mdm puts every filled
  root field in the Create body by its metadata name. So the NULL most likely comes from IDMC itself
  (survivorship / trust on the ffr_ fields, or validation-owned fields) - UNVERIFIED. Next check: open the
  record's source in Records (S) (Read Source Record): if the xref has the ffr_ values and the master does
  not, it is survivorship; if the xref is NULL too, IDMC dropped them on create.

## Source records, edit, field groups (0.9.10, 2026-11-23 01:40-02:00 CST)

Reference: internal-docs/B360_October2026_Business360_REST-API_Reference_en.pdf.

| Call | Pages | Used for | Status |
|---|---|---|---|
| Read Source Records by Master Record `GET .../entity-member/{entity}/{businessId}` -> `{content:[{sourcePKey, sourceSystem}]}` | 70-71 | Records (S) member list | DOC, CODE |
| Read Source Record `GET .../entity-xref/{entity}/{sourceSystem}/{sourcePKey}` | 80-84 | Records (S) rows, Edit load | DOC, CODE |
| Update Source Record Field `PATCH .../entity-xref/...` body `[{op, path, value}]`, reply `{approvalRequired}` | 88-90 | Edit Save | DOC, CODE |
| Update Source Record `PUT` (replaces, CREATES if missing) | 85-88 | NOT used | DOC |

- **PATCH over PUT**: PATCH sends only what changed and cannot create a record by accident; PUT replaces
  the whole record and creates it when missing.
- Documented PATCH paths: `firstName`, `Phone[<_id>].phoneNumber`, `PostalAddress[<_id>]` (whole row).
  UNVERIFIED shapes we also build: field `remove`, add a group row (path `<group>`, value `[row]`), remove a
  row (`<group>[<_id>]`). Each op carries `verified` and the Edit page shows "UNVERIFIED".
- "Currently, source records aren't searchable" (p. 82): there is no documented list of all source
  records, so Records (S) is master-driven (or one sourceSystem + sourcePKey lookup). Not faked.
- Picklist values: NO documented call lists a picklist's allowed values (PDF and Postman). Options are the
  distinct {Code, Name} pairs seen in up to 50 of the entity's own records (one Search call); none seen =
  options_source NONE, field left empty. Never invented.
- Create body with groups follows pp. 52-54 (`"Phone":[{"_id", "phoneType":{"Code"}, ...}]`); new row `_id`
  = uuid4 hex. UNVERIFIED on his org until x_phone rows land.
- Metadata (S) is derived: same entity metadata + xref `_meta` fields documented on pp. 80-84
  (sourceSystem, sourcePrimaryKey, xrefType, sourceLastUpdatedDate, populationName ...). No separate
  source-metadata call is documented.

## Merge / Override / Unmerge (0.9.12, B360 REST API Reference Oct 2026)
- Merge API p. 106: `POST {mdm}/business-entity/public/api/v1/entity-group/<businessEntity>`, body =
  JSON array of up to 10 items, each `{businessId}` or `{sourcePKey, sourceSystem}`; reply
  `{approvalRequired, businessId}` (businessId = surviving master).
- Update Master Record Field pp. 67-68: `PATCH .../entity/<be>/<businessId>?sourceSystem=<id>`, body
  `[{op: add|replace|remove, path, value}]`, reply `{approvalRequired}`; a merged-away (inactive)
  businessId updates the active master it merged into. Used for merge winners. Update Master Record
  (PUT) pp. 65-66 replaces the whole record: not used.
- Unmerge API pp. 107-110: `POST .../entity-group/<be>/<businessId>?_keepRelsWith=BUSINESS_ID|REMAINS|NONE
  &_groupingForRemoved=ALL|EACH|NONE&_groupingForRemains=...&_allowMergeBack=MAY_MERGE|NEVER_MERGE`,
  body = source keys `[{sourcePKey, sourceSystem}]` (up to 10); defaults REMAINS / EACH / ALL /
  NEVER_MERGE; BUSINESS_ID is what the B360 UI does; reply `{approvalRequired}`.
- Not documented: how an override PATCH interacts with trust / manualOverride and later match/merge.

## Reference 360 picklists (0.9.12)
- Live (02:27 CST via his backend): `rdm.value.be._ent_phonetype`, label "RDM values of list
  Enterprise PhoneType", searchable with the normal Search API, 11 records, fields Name / Code; Codes
  VoIP, Cell, Contaminated, Fax, Freephone, LandLine, Marine, Mobile, Pager, Special, Telephone. Also
  `rdm.value.be._ent_phonestatus`, `rdm.value.be._ent_phoneusagetype`; 97 rdm.* entities.
- The reference prints `lookupCodeList` (code list of a picklist), `masterCodeList` (parent list of
  a dependent picklist) and `beReferenceEntity` for Customer 360 custom field designators (pp.
  148-150). The businessEntity metadata reply itself is not printed, so the attribute his LookupField
  carries is UNVERIFIED; tx-mdm keeps every raw attribute name (`lookup.raw_keys`) to find out.

## Field lengths (0.9.12.2)
- The reference prints `length`, `minLength`, `maxLength`, `precision`, `scale` for Customer 360 custom
  field designators (pp. 148-150). Whether businessEntity metadata fields carry `maxLength` / `length`
  is UNVERIFIED; tx-mdm reads either if present (origin METADATA). Our earlier wire model dropped them.
