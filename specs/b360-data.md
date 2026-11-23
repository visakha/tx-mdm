# Spec - B360 Data (business entity records)

**As of:** 0.9.11 (2026-11-23). New file; covers 0.9.5-0.9.11.

## Why

See and feed Vamsi's own Business 360 business entity (focus: `zlv_guest`, "ZLV Guest") from the
app: the golden (master) records, the source records that merge into them, the metadata that
shapes both, and test data entered at SOURCE level.

## Model (his words, 2026-11-23 ~01:33 CST)

- Source records come in from source systems; several merge into one golden MASTER record.
- Data is only ever added or edited at SOURCE level. There is NO add or edit path for masters.
- Tabs: Records (M) | Metadata (M) | Records (S) | Metadata (S) | Add records (S) | Edit records (S).

## Configuration - `backend/b360_entities.toml` (he edits it; restart backend to apply)

- **D01** `[[entity]] name / label` = which entities appear as their own items in the B360 Data
  left pane; a name not in the org shows "(not found in org)"; bad file stops start-up with a clear
  error; `B360_ENTITIES_FILE` overrides the path. `CODE` / `LIVE`
- **D02** `fields = [...]` per entity lists EVERY field / group / system item, one per line; a line
  commented out with `#` hides that column and detail row in Records (M) and (S) (a group line hides
  the whole group); Metadata tabs still show all; no list = show all; unknown name = warning line,
  ignored; a duplicate name stops start-up. Records endpoints return typed `visibility {listed,
  hidden, warnings}`. `CODE`
- **D03** `[sources] allowed` = source systems the app may write to, matched exactly and
  case-sensitive (`zlv_ttf`, `zlv_eci`, `c360.default.system`); `default = "zlv_ttf"`. Anything else
  -> 400, nothing sent. `CODE` / `LIVE` (zlv_ttf accepted)

## Requirements

Entities and metadata
- **D04** Entities derived from org metadata, never hardcoded: `GET /api/b360/entities?scope=focus|all`
  (IDMC `tenantModel/datamodel`); `all` groups CUSTOM / OUT_OF_THE_BOX (`c360.*`) / REFERENCE
  (`rdm.*`) / TEMPLATE (`entity.*`) behind "Show all entities". `CODE` / `LIVE` (106 entities)
- **D05** Metadata (M): `GET /api/b360/entities/{name}/metadata` - typed fields (name, label, data
  type enum, mandatory, searchable, origin CONFIGURED | SYSTEM) and field groups (cardinality ONE /
  MANY), cached 5 min. `CODE` / `LIVE`
- **D06** System items in magenta, in two groups with a one-line note each (his split, 01:54 CST):
  "System fields" = business-facing, data-influenced (validationType, validationState,
  recordStateIndicator, _indexValidationError.code); "Record system metadata (_meta)" = purely
  system-owned (businessId, id, businessEntity, createdBy, creationDate, updatedBy, lastUpdateDate ...).
  Items the org reply omits but the reference documents are marked "(documented)". `CODE` / `LIVE`
- **D07** Metadata (S): `GET /api/b360/entities/{name}/source-metadata` - same model plus documented
  xref `_meta` fields; labelled as DERIVED (no source-metadata call exists). `CODE`

Master records
- **D08** Records (M): `GET /api/b360/entities/{name}/records?page=&first_name=&last_name=&business_id=&sort=`
  - 10 per page via Search API offset; Prev / Next, "Page X of Y (N records)". `CODE` / `LIVE`
- **D09** Filters: first / last name STARTS_WITH; Business ID exact via Read Master Record. Only "Last
  updated" (`_meta.lastUpdateDate`) sorts, server-side, newest first by default. `CODE` / `LIVE` (STARTS_WITH)
- **D10** Master table in its own scroll box (horizontal + about 10 rows high, sticky header); system
  (_meta) columns magenta after configured ones; values exactly as IDMC returned them. `CODE`
- **D11** Detail below (stacked, full width, no tabs): root fields, then each field group as its own
  block, then the magenta _meta block. `CODE` / `LIVE`

Source records
- **D12** Records (S): pick a master -> `GET /api/b360/entities/{name}/records/{business_id}/sources`
  (Read Source Records by Master Record, then Read Source Record each, max 20). `CODE`
- **D13** Look up one source: `GET /api/b360/entities/{name}/sources/{source_system}/{source_pkey}`;
  404 -> not found. No "list all source records" - B360 says they are not searchable (p. 82). `CODE`

Add records (S) - the only create path
- **D14** Form: `GET /api/b360/entities/{name}/form-schema` - typed model built from metadata;
  mandatory starred; field groups as repeatable blocks. `CODE`
- **D15** Generate: `POST /api/b360/entities/{name}/records/generate {count 1-100}` - Faker preview
  only, nothing sent; 1-2 rows per MANY group; picklist codes only from values seen in real records
  (none seen -> left empty, never invented); `ffr_*` (freeform reason) left EMPTY; `clns_*` derived
  from its base field. Preview rows editable and removable. `CODE` / `LIVE` (generate)
- **D16** Send / Save: `POST /api/b360/entities/{name}/records` (Create Master Record with
  `sourceSystem` + `sourcePKey`, default `TXMDM-<yyyymmddHHMMSS>-<n>`): validated first (allowed
  source, required fields, <= 100, no duplicate keys) else nothing sent; then one at a time, in order;
  429 / 401 / 403 / no answer stop the run, rest NOT_SENT; per-row CREATED / FAILED / NOT_SENT /
  UNKNOWN shown inline. `CODE` / `LIVE` (two 5-row batches landed)
- **D17** Source systems list: `GET /api/b360/source-systems` - TOML allowed list plus any found by the
  undocumented `metadata/api/v2/objects/sourceSystem` call (shown as "add to toml to allow"). `CODE` / `LIVE`

Edit records (S)
- **D18** Open by source system + sourcePKey (or "Edit this source record" from Records (S)); typed
  form prefilled with root fields and group rows. `CODE`
- **D19** `POST /api/b360/entities/{name}/sources/{source_system}/{source_pkey}/update` with
  `dry_run=true` (default) returns the operations (old -> new) shown inline; Save is enabled only after
  that and sends exactly those as ONE PATCH (`dry_run=false`). PATCH, never PUT (PUT replaces and can
  create). `approvalRequired` shown inline. `CODE`

Safety
- **D20** Writes to the org happen ONLY when a person presses Save / Send (or an agent presses those
  same buttons through the bridge); tests and builders use the fake IDMC only. `CODE`

Merge (M) (0.9.12, Vamsi 02:21 CST: "merge 100000000000141 and 100000000000150 and let first
name from 141 win, while last name from 150 win")
- **D21** `POST /api/b360/entities/{name}/merge/preview` `{business_ids}`: read-only; reads each
  master (Read Master Record) and returns one row per root field with each record's value, `differs`,
  and `follows` for `clns_<field>` twins. Missing ids are listed, nothing else happens. `CODE`
- **D22** `POST /api/b360/entities/{name}/merge` `{business_ids: 2-10 distinct, winners: {field:
  business_id}, override_source_system?}`. Validated before ANY call (entity in focus, ids, winner
  ids in the list, winner fields are root fields of the metadata, picklist winners refused, override
  source in `[sources] allowed`, default `[sources] default`) else 400 and nothing sent. Steps:
  READ each record (missing -> stop before merge) -> MERGE (Merge API p. 106, body
  `[{businessId}...]`; error / no answer -> stop, no answer = outcome unknown) -> OVERRIDE (Update
  Master Record Field PATCH pp. 67-68 on the surviving businessId with `?sourceSystem=`, replace ops
  for the winner fields plus their `clns_` twins from the same winner; SKIPPED when no winners or
  `approvalRequired`) -> READ_BACK (each override shows sent / read back / stuck). 429 passed through
  as a step result, never retried. `CODE`
- **D23** Undo: `POST /api/b360/entities/{name}/records/{business_id}/unmerge` `{sources: [{source_system,
  source_pkey}], allow_merge_back}` (Unmerge API pp. 107-110, `_keepRelsWith=BUSINESS_ID`, default
  NEVER_MERGE). `CODE`
- **D24** UI: ribbon tab "Merge (M)": ids box (paste is split), Load, side-by-side table with one
  radio group per field (default "IDMC decides" = no override; clns_ rows say "follows"), Merge
  button (no pop-up; `data-agent-confirm` label only), inline steps / overrides / survivor, then Undo
  (pick source records, Unmerge). Agent bridge: `previewB360Merge` read-only; merging is button-only. `CODE`

Reference 360 picklists (0.9.12, Vamsi 02:27 CST: picklists come from Reference 360, out of the box)
- **D25** Each LookupField / DependentLookupField keeps `lookup` from the RAW businessEntity
  metadata: `code_list` / `master_code_list` / `rdm_entity`, `found_in` (the raw attribute it came
  from) and `raw_keys` (every attribute name on that raw field, values not kept). Read attributes:
  `lookupCodeList`, `masterCodeList`, `beReferenceEntity` (documented names, field designator pp.
  148-150) and UNVERIFIED alternatives `codeList`, `lookup`, `lookupEntity`, `referenceEntity`,
  `reference`. Resolved against the datamodel's `rdm.*` entities (cached 5 min): DECLARED (rdm entity
  named), LABEL_MATCH (code list X matches the entity labelled "RDM values of list X"), GUESSED (no
  list named; exactly one rdm list name ends with the field's label/name), NOT_FOUND. `CODE`
- **D26** Allowed values = every {Code, Name} of that `rdm.value.be.*` entity (Search API, pageSize
  200, cached 5 min) -> `options_source` REFERENCE_360 (or REFERENCE_360_GUESSED, labelled a guess in
  the Generate rules text); else the 0.9.10 values observed in records; else NONE. Never invented.
  Forms show a dropdown; Generate picks a random real Code, so x_phone rows are generated again;
  Metadata (M) shows a "Lookup list (Reference 360)" column. `CODE` (`LIVE` for the list itself:
  rdm.value.be._ent_phonetype has 11 codes, read 02:27 CST)

Typed API docs (0.9.12, Vamsi 02:32 CST: "create another OpenAPI hyphen typed JSON... more concrete")
- **D27** `GET /openapi-typed.json` (next to `/openapi.json`, which stays generic and separate) = the
  app spec plus, per focus entity from live metadata (read-only, same cache): `Record_<e>` (flat,
  real JSON types, required = mandatory, field groups as arrays of `Row_<e>_<group>`, system fields and
  `_meta` readOnly with `x-origin: SYSTEM`), `Values_<e>`, `NewRecord_<e>`, `CreateRequest_<e>`,
  `EntityRecord_<e>`, `RecordPage_<e>`; picklists are an `enum` of real Codes with
  `x-picklist-source` / `x-reference-360`, else string + note; concrete paths
  `/api/b360/entities/<e>/records` GET + POST. ALL fields (TOML visibility does not apply). A failed
  metadata read -> base spec + `x-typed-warnings`, never 500. `GET /docs-typed` = Swagger on it;
  title-bar link "API docs (typed)"; `backend/dev/write_openapi_typed.py` saves it to a file. `CODE`

Lengths (0.9.12.2, Vamsi 02:40-02:41 CST)
- **D28** `EntityField.length` = `{max, exact, origin METADATA|CONFIG|DECLARED|LONGEST_CODE,
  metadata_max}`. METADATA from a raw `maxLength` / `length` attribute; CONFIG from
  `b360_entities.toml` `[entity.lengths]` / `[entity.groups.<group>.lengths]` (`field = 3` or
  `{ max = 10, exact = true }`; wins over metadata; larger than metadata or unknown field ->
  `length_warnings` shown on Metadata (M)). His config: x_phone.cntry_cd 3 digits, x_phone.ph_num
  exactly 10 digits. Picklists: DECLARED (rdm entity's Code field length) else LONGEST_CODE of the live
  list, recomputed with the 5-minute caches. `CODE`
- **D29** Enforced in the dynamic Pydantic models (text max_length / min_length; integers le
  10**n-1, ge 0 or 10**(n-1) when exact), in `/openapi-typed.json` (maxLength / minimum / maximum /
  x-length-origin), in Type-it / Edit inputs (maxlength, min / max), and in Generate (cntry_cd 1,
  ph_num 10 digits not starting with 0, ph_typ a real Code that fits). Generate fills root fields and
  every field group in one go. `CODE`
- **D30** Records (S) is source-specific (Vamsi 02:45 CST): tick one or more source systems
  (checkboxes "Source system <name>", one per `[sources] allowed`, default = `[sources] default`).
  `GET /api/b360/entities/{name}/source-records?source_systems=..&source_systems=..&page=N`
  (`SourceRecordPage`): Search API page of 10 masters -> Read Source Records by Master Record (p. 70)
  per master -> keep members whose sourceSystem is ticked -> Read Source Record (p. 80) each (cap
  50). One flat table: source system, sourcePKey, master business id, fields. Not-allowed system ->
  400, nothing sent. 429 -> passed through, nothing retried. The FILTER IS APPLIED BY tx-mdm AFTER
  THE IDMC READ: the Search API documents filters only on fields and validationType /
  validationState / recordStateIndicator / _indexValidationError.code, and no call lists all
  records of one source. PAGING IS PER MASTER PAGE, so a page can show 0..n source records. `CODE`
- **D31** Metadata is ONE ribbon tab with a sub-tab strip Master | Source (UI SDK Tabs, aria-labels
  "Metadata Master" / "Metadata Source", default Master). Source has the same source-system
  checkboxes; `GET /api/b360/entities/{name}/source-metadata/by-system` (`SourceMetadata`) returns
  the model once with `same_for_all = true` and a note naming the ticked systems: no per-source
  metadata call is documented. What differs per source is per record (content meta,
  `_showContentMeta=true`, p. 19: trust score, trust rule, manualOverride per field). Old tab ids
  `source-metadata` / `metadata-source` / `metadata-master` redirect to Metadata + sub-tab. `CODE`
- **D32** Merge history (M) / (S) (Vamsi 02:48-02:49 CST), ribbon tabs after Merge (M). IDMC
  documents NO read-merge-history API (only entity-history .../anonymize, p. 78, never called). So:
  (M) `GET /api/b360/entities/{name}/records/{id}/merge-history` (`MasterMergeHistory`) = Read Master
  Record with `_showContentMeta=true` (p. 19, pp. 56-58): per field the trust entry (own fieldRef,
  else the record-wide "/" entry): source system / pkey, trustRule, trustScore, manualOverride,
  lastUpdatedDate; plus members (p. 70) and each source record (p. 80, cap 20) for created / updated
  dates, oldest first. (S) `GET .../sources/{system}/{pkey}/merge-history` (`SourceMergeHistory`) =
  Read Source Record with `_showContentMeta=true` + its master with content meta: own trust, its
  master, and per field whether its value equals the master value now ("won"). Merges / unmerges
  pressed in THIS app are logged in backend memory (last 500, lost on restart) and listed as
  "merged from this app at <time>". The page says plainly this is who contributes what now, not an
  event history. Read-only; 429 passed through. `CODE`
- **D33** Copy IDMC curl (Vamsi 02:48-02:50 CST: "the true curl ... hit the IDMC APIs and not the
  APIs that we are writing here"). `IdmcHttp._send` records each IDMC call of one backend request
  (method, full URL with query, session header NAMES, JSON body; never the session id value, and the
  login POST is not recorded at all). A middleware returns `X-Idmc-Echo-Id`; `GET
  /api/idmc/echo/{id}` (`IdmcEcho`, last 200 in memory) returns the calls plus runnable scripts:
  PowerShell (Invoke-RestMethod login with `$env:IDMC_PASSWORD`, then curl.exe with the body in
  body.json because Windows PowerShell 5 strips quotes from JSON arguments) and bash (python3 builds
  the login JSON from `$IDMC_PASSWORD`, curl, heredoc bodies). Username = the backend's configured
  IDMC_USERNAME. Header per call: IDS-SESSION-ID (MDM), INFA-SESSION-ID (CDI v3), icSessionId (v2).
  Buttons: B360 Data (one per entity, newest call of any tab), Taskflows (CDI / B360), B360 jobs.
  Write screens show the curl of the write the backend actually sent (after the button); dry runs
  send nothing, so there is nothing to echo. `CODE`

## Out of scope

Master-record create / edit (except Merge winners, D22); delete / restore; picklist management;
entities other than the TOML focus list beyond read-only browsing.

## Known gaps / UNVERIFIED

- Records he created show `ffr_first_name` / `ffr_last_name` NULL in the master although the old
  generator filled them; tx-mdm sends them (test proves it), so IDMC probably drops or survives them
  away. Check via Records (S) on his org.
- Sort by `_meta.lastUpdateDate`, picklist body shape `{"Code": ...}`, field-group create body, and
  PATCH paths for group rows / remove: documented or guessed, not yet proven on his org.
- Records (S), Edit (S) and field visibility are fake-IDMC only so far; the fake's zlv_guest uses
  different field names, so the repo TOML shows warnings there (expected).
- Add records (S) uses the documented Create MASTER Record API: with a sourceSystem it creates the
  source record that merges into a master. The tab label (S) reflects his model, the API name does not.
- Merge (0.9.12): never run on his org. Which record IDMC keeps as survivor (the app uses the returned
  businessId), whether masters merge by businessId there, whether an approval workflow applies, and
  whether the override PATCH with `sourceSystem=zlv_ttf` counts as a steward override (trust /
  manualOverride) or a zlv_ttf contribution that a later match/merge or source update replaces.
  clns_ values are carried from the winner, not recomputed by IDMC cleansing. Unmerge never exercised.
- Reference 360 (0.9.12): which raw attribute his org's metadata uses to name a LookupField's list is
  UNVERIFIED (fake mirrors the documented `lookupCodeList`); Metadata (M) shows `raw_keys` so the first
  live look answers it. Codes of rdm values read from the `Code` field (live: Name / Code).
- `/openapi-typed.json` per-entity paths duplicate the generic `{name}` routes for readability; the
  backend validates against the dynamic model, not against this document.
