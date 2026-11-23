# TX MDM - IDMC Job Runner

A small app for running and watching Informatica IDMC jobs without the browser console:

- **Business 360 (MDM):** pick an ingress, egress or match-merge job definition and run it.
- **Data Integration (CDI):** pick a mapping task or taskflow and run it.
- **Monitor (CDI) tab:** what is running in Data Integration right now, with the minutes it
  has been running ticking live, plus recent history (status, start, end, duration in minutes,
  source/target success and failed rows, error text, who/what started it) and expandable
  taskflow steps. Auto-refreshes every 15 s (Pause / Refresh now), "my tasks" or all jobs.
- **Results screen** (same for both): job name, status, "Requested" time (when this app
  submitted the run), "Started in IDMC" time (as Informatica reports it), end time, a short
  live log, counts on one side, errors on the other.

```
frontend/  React + Vite + strict TypeScript, Vercel UI SDK (@ui-sdk/react) + agent bridge
   |  only ever calls /api/... on its own origin (Vite proxies it)
   v
backend/   Python FastAPI - owns EVERY Informatica call, holds the credentials
   +-- app/cdi/   CDI: own session, own host, own task list, own runs
   +-- app/mdm/   MDM (Business 360): own session, own host, own job list, own runs
   `-- app/common/ login helper, run registry, the shared RunView shape
```

CDI and MDM are separate concerns: separate modules, routers, sessions and lists. They share
only the app shell (tabs) and the shape of a run result.

### Repository layout

| Folder | What |
|---|---|
| `backend/`, `frontend/` | The app |
| `internal-docs/` | Reference material: B360 Postman collection, B360 REST API reference PDF (Oct 2026), transcribed `idmc_collection.http` (password masked), CDI and MDM API research notes, API map |
| `internal-notes/` | Working notes for the agent maintaining this repo: layout, gotchas, verified vs unverified API facts, run/test commands, next steps, barebones-v2 <-> CDI |
| `methodology/` | Spec-Driven Development: constitution, six-phase lifecycle, operating procedures (incl. hill climbing), decision log, Python/TS review guide |
| `specs/` | Current-state specs: CDI, MDM, shared behaviour, agent interface |
| `changes/` | Change proposals (proposal / specs / design / tasks) and templates |
| `idq-barebones-v2/` | Read-only snapshot of the Snowflake bare-bones package from github.com/visakha/idq-cli @ `adde845` |

## Setup

Prerequisites: Python 3.12+, Node 20+ (tested on 24).

### Windows / PowerShell: starter scripts (use these)

From the repo root, one PowerShell window each:

```powershell
.\start-backend.ps1 -Pull     # pull, create/activate backend\.venv, pip install only if needed, start :8000
.\start-frontend.ps1          # npm install only if needed, start :5173
```

`start-backend.ps1` always runs the venv's own `python.exe`, never the global
Python in AppData (running the global `uvicorn.exe` is what caused
"No module named faker" after 0.9.8). Add `-Install` to force a reinstall.
If PowerShell refuses to run scripts:
`Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`.

### Linux / macOS

```bash
# backend
cd backend
python3 -m venv .venv
.venv/bin/pip install -e '.[dev]'
cp .env.example .env        # then put the real username/password in .env (git-ignored)
.venv/bin/uvicorn app.main:app --port 8000

# frontend (second terminal)
cd frontend
npm install
npm run dev                 # http://localhost:5173, proxies /api to :8000
```

### Environment variables (backend/.env)

| Variable | Meaning |
|---|---|
| `IDMC_USERNAME` / `IDMC_PASSWORD` | IDMC login. Only the backend sees these. |
| `IDMC_LOGIN_URL` | v3 login host, default `https://dm1-us.informaticacloud.com` |
| `IDMC_MDM_URL` | Business 360 API host, default `https://usw1-mdm.dm1-us.informaticacloud.com` |
| `IDMC_PLATFORM_URL` | Optional override; empty = use `baseApiUrl` from the login response |
| `MDM_RESOLVER_CACHE_SECONDS` | How long MDM job-id resolution is cached (default 600) |
| `FRONTEND_ORIGIN` | CORS origin if you skip the Vite proxy |
| `IDMC_PROXY_URL` | Outbound proxy for IDMC calls; empty = direct |
| `HTTP_TRUST_ENV` | `false` (default): ignore `HTTP(S)_PROXY`/`NO_PROXY` env vars. `true`: honour them, falling back to `IDMC_PROXY_URL` with a warning if httpx cannot parse them |

> **Proxy note.** The backend deliberately ignores ambient proxy env vars by default. A
> `NO_PROXY` containing an IPv6 entry (e.g. `::1`) makes httpx raise
> `InvalidURL: Invalid port` on every call. If you need a proxy, set `IDMC_PROXY_URL`.

### Try it without an IDMC org

`backend/dev/fake_idmc.py` is a tiny fake IDMC. Start it on port 8900 and point the backend at it:

```bash
cd backend
.venv/bin/uvicorn dev.fake_idmc:app --port 8900 &
IDMC_USERNAME=demo IDMC_PASSWORD=demo \
IDMC_LOGIN_URL=http://127.0.0.1:8900 IDMC_MDM_URL=http://127.0.0.1:8900 \
IDMC_PLATFORM_URL=http://127.0.0.1:8900/saas \
.venv/bin/uvicorn app.main:app --port 8000
```

## Checks

```bash
cd backend  && .venv/bin/pytest -q && .venv/bin/ruff check . && .venv/bin/mypy app
cd frontend && npm run typecheck && npm test && npm run lint && npm run build
```

## Backend API (what the frontend calls)

| Method | Path | Does |
|---|---|---|
| GET | `/api/cdi/tasks` | CDI tasks from the v3 objects query (MTT, WORKFLOW, TASKFLOW) |
| POST | `/api/cdi/runs` | Start one CDI task `{task_id, task_type, task_name, api_name?}` |
| GET | `/api/cdi/runs/{run_key}` | Refresh and return the run |
| GET | `/api/cdi/monitor?only_my_tasks=true&row_limit=50` | Monitor tab: running jobs (activityMonitor, details=true) + recent history (activityLog) + runs started here. Read-only |
| POST | `/api/cdi/taskflows/{name}/run` | Start an advanced taskflow BY NAME; body `{"parameters": {"jobInstanceId": "ABC123"}, "api_name": null}` (both optional). Returns IDMC's `run_id`. Parallel starts of one taskflow are allowed (no 409) since 0.9.1 |
| GET | `/api/cdi/taskflows/{name}/history?row_limit=100` | Run history of one taskflow (Run tab detail): runs started from this app + its child task rows from activityMonitor / activityLog (IDMC does not list the taskflow itself). Read-only |
| GET | `/api/cdi/taskflows/runs/{run_id}?details=true` | Status + summary of ANY taskflow run by IDMC run id (works after a restart). Read-only |
| GET | `/api/cdi/taskflows/runs/{run_id}/session-log?subtask=<child task>` | Session log of one child task, plain text. Read-only |
| POST | `/api/cdi/taskflows/runs/{run_id}/terminate` | Abort a running taskflow (IDMC `PUT /active-bpel/services/tf/terminate {"runid": [...]}`, 204 = accepted). Optional `{"run_ids": [...]}`, max 200. SIDE EFFECT |
| GET | `/api/mdm/jobs` | MDM job definitions (v3 objects) + resolved internal id / kind |
| POST | `/api/mdm/runs` | Start one MDM job `{asset_id}` |
| GET | `/api/mdm/runs/{run_key}` | Refresh and return the run |
| GET | `/api/mdm/monitor?row_limit=25` | Business 360 Currently running: every running `b360.*` / `c360.*` job in the org, whoever started it (portal, other machine, other user), plus recent finished ones. B360 job search; status-filter value spelling and sort order UNVERIFIED (see `app/mdm/monitor.py`). Read-only |
| GET | `/api/mdm/job-instances/{instance_id}` | Look up ANY B360 job instance by full id (`jobInstance/{id}?details=true`). Read-only |
| GET | `/api/b360/entities?scope=focus\|all` | B360 Data: business entities DERIVED from the metadata API (`GET {mdm}/metadata/api/v2/objects/tenantModel/datamodel`). `focus` (default) = only the entities listed in `backend/b360_entities.toml`, each marked found / not found in the org; `all` = every entity with its category (CUSTOM, OUT_OF_THE_BOX c360.\*, REFERENCE rdm.\*, TEMPLATE entity.\*). Typed `BusinessEntityList`. Read-only |
| GET | `/api/b360/entities/{name}/metadata` | One entity's typed fields (data type, searchable, mandatory) and field groups (`GET {mdm}/metadata/api/v2/objects/businessEntity/{name}`, cached 5 min). Read-only |
| GET | `/api/b360/source-systems` | 0.9.8: source systems the Add records tab may send to = `[sources] allowed` in `backend/b360_entities.toml` (exact case; default `zlv_ttf`), plus a read-only discovery attempt `GET {mdm}/metadata/api/v2/objects/sourceSystem` (UNDOCUMENTED, UNVERIFIED; `NOT_AVAILABLE` when it fails). Typed `SourceSystemList`. Read-only |
| GET | `/api/b360/entities/{name}/form-schema` | 0.9.8: the entity's root-field form, from a Pydantic model built per entity with `pydantic.create_model` (types from the metadata, mandatory = required). Typed `FormSchema`. No IDMC write |
| POST | `/api/b360/entities/{name}/records/generate` | 0.9.8: `{count: 1..100, seed?}` -> Faker test rows checked by the same dynamic model. Preview only, NO IDMC call. Typed `GeneratedRows` |
| POST | `/api/b360/entities/{name}/records` | 0.9.8 WRITE: `{source_system, records[<=100]}` -> Create Master Record (`POST {mdm}/business-entity/public/api/v1/entity/{name}?sourceSystem=&sourcePKey=`, reference pp. 51-55) one record at a time, in order, never retried. Source not allowed -> 400; a record that does not fit the model, duplicate sourcePKey or >100 -> 422; in both cases nothing is sent. 429 / 401 / 403 / no answer stop the run (rest NOT_SENT). Typed `CreateResponse`. Only on a person's Save / Send to B360 |
| GET | `/api/b360/entities/{name}/records?page=1&first_name=&last_name=&business_id=&sort=NEWEST_FIRST` | 0.9.9: one page of 10 master records via the Search API (`recordOffset`/`recordsToReturn`/`pageSize`, reference pp. 25-26); `first_name`/`last_name` -> `filters.filter[]` STARTS_WITH on `<entity prefix>.<field>`; `sort` NEWEST_FIRST/OLDEST_FIRST -> `sort:[{fieldName:"_meta.lastUpdateDate"}]` (only sortable column); `business_id` -> exact Read Master Record by Business ID `GET {mdm}/business-entity/public/api/v1/entity/{name}/{businessId}` (pp. 56-58; 404 = empty page with a note). Typed `RecordPage` (page, total_pages, filters, mode, last_updated per record). Read-only |
| GET | `/api/b360/entities/{name}/source-metadata` | 0.9.10: Metadata (S) - same configured fields/groups as the entity, plus the xref `_meta` system fields (org metadata + those documented for Read Source Record, pp. 80-84, marked DOCUMENTED). Derived: no separate source-metadata call is documented. Typed `BusinessEntity`. Read-only |
| GET | `/api/b360/entities/{name}/records/{business_id}/sources` | 0.9.10: Records (S) - Read Source Records by Master Record `GET {mdm}/business-entity/public/api/v1/entity-member/{name}/{businessId}` (pp. 70-71), then Read Source Record for each member (max 20, one at a time). Typed `SourceRecordList` (records, not_read, system_columns). Read-only |
| GET | `/api/b360/entities/{name}/sources/{source_system}/{source_pkey}` | 0.9.10: Read Source Record `GET {mdm}/business-entity/public/api/v1/entity-xref/{name}/{sourceSystem}/{sourcePKey}` (pp. 80-84); 404 -> 404. Typed `SourceRecord` (values, group rows with `_id`, system_values). Read-only |
| POST | `/api/b360/entities/{name}/sources/{source_system}/{source_pkey}/update` | 0.9.10 WRITE (dry_run=false only): `{original, updated, dry_run}` -> diff into Update Source Record Field ops; dry_run=true (default) returns them (old -> new, shown inline on the Edit page) and sends nothing; dry_run=false sends ONE `PATCH .../entity-xref/{name}/{sourceSystem}/{sourcePKey}` (pp. 88-90). Source not allowed -> 400, bad values -> 422, 429 passed through, never retried. Typed `UpdateSourceResponse`. No master-record edit exists |
| GET | `/api/health` | Liveness |

Rules built in: one active run per job (a second start gets HTTP 409); a failed run is
recorded and **never retried**; an HTTP 429 from Informatica is a hard stop, shown as-is;
a 401 triggers one fresh login and one resend of that request (the call never ran, so it is
not a job retry). The password never goes to the browser and is never echoed in errors.

## Layout (OneNote style)

Left pane: a search box and two notebooks - **Data Integration (CDI)**: Tasks, Taskflows,
Monitor, Runs; **Business 360 (MDM)**: All jobs, Ingress jobs, Egress jobs, Currently running, Runs. Top ribbon:
contextual tabs for the selected section (Taskflows: Run / Track run id / Summary / Session log;
Monitor: Everything / Running now / History / Started here; Runs: Runs / Result; job sections:
Jobs / Run). URLs are unchanged (plus `/cdi/runs`, `/mdm/runs`, `/mdm/ingress`, `/mdm/egress`, `/mdm/running`).
Every status poll in the UI is 15 s (one constant, `frontend/src/shared/poll.ts`).
Screen-by-screen notes: `internal-notes/ui-observations.md`.

### Hide fields on the records screens (b360_entities.toml)

`backend/b360_entities.toml` lists every field of each entity under `fields = [...]`, one per line:
root fields (`first_name`), field groups (`x_phone`) and their fields (`x_phone.ph_num`), system fields
(`validationType`) and record system metadata (`_meta.lastUpdateDate`). Put `#` in front of a line to hide
that field from the Records (M) / Records (S) columns and the record detail (a commented group hides the
whole group); the Metadata tabs always show everything. Save, then restart the backend (Ctrl+C, run
uvicorn again). No `fields` list = show all. A name not in the metadata shows a warning line and is ignored.
In the title bar, **API docs** opens the backend's Swagger UI (`/docs`).

### UI end-to-end (Cypress, against the fake IDMC)

Start the fake stack (see "Try it without an IDMC org") and `npm run dev`, then in `frontend`:

```
npx cypress@16 run --browser electron
```

(Cypress is not in package.json on purpose; npx downloads it once.)

Live, read-only (never clicks Run; the forwarder refuses every POST):

```
python dev/forward_readonly.py http://<backend-host>:8000 [http://<proxy>:<port>]
TXMDM_API_TARGET=http://127.0.0.1:8010 npx vite --port 5174
npx cypress@16 run --browser electron --config-file cypress.config.cjs --config baseUrl=http://localhost:5174,specPattern=cypress/live/**/*.cy.js
```

## Taskflows by name (Taskflows section)

UI: left pane **Taskflows** (`/taskflows`). Pick a taskflow, check the input fields
(`jobInstanceId` = `ABC123` is prefilled - edit it), press **Run** (starts at once, no pop-up). The run id
appears in the URL (`/taskflows/runs/<runId>`) and the view polls every 10 s until final:
started at, ticking "running for", status, then per child task rows ok/error, source/target
rows, errors, totals and a **Session log** button per child. Ribbon tab **Track run id**: paste any run id and press
**Track** to follow a run started elsewhere.

PowerShell (backend on port 8000):

```
# start by name with the jobInstanceId input field (starts a REAL run)
Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:8000/api/cdi/taskflows/tf_MDM_ZLV_TTF_Guest_Basic/run" -ContentType "application/json" -Body '{"parameters": {"jobInstanceId": "ABC123"}}'
# -> {"run_id":"1309380263289049088","taskflow_name":"tf_MDM_ZLV_TTF_Guest_Basic","task_id":"...","api_name":"tf_MDM_ZLV_TTF_Guest_Basic","run_key":"...","requested_at":"...","status_path":"/api/cdi/taskflows/runs/1309380263289049088","parameters":{"jobInstanceId":"ABC123"}}

# status + summary by run id (read-only)
curl.exe -s "http://127.0.0.1:8000/api/cdi/taskflows/runs/1309380263289049088"
# -> {"run_id":"1309380263289049088","status":"STOPPED","state_text":"SUSPENDED","is_final":true,
#     "started_at":"...","ended_at":"...","elapsed_minutes":2.5,"error":"...",
#     "subtasks":[{"name":"mt_m_MDM_ZLV_TTF_Guest_Basic","status":"FAILED","rows_processed":0,
#       "success_rows":0,"error_rows":0,"rows":{"source_success":...},"error":"[FATAL] ...",
#       "log_entry_id":"..."}],"totals":{...},"notes":[]}

# abort a running taskflow (stops the LIVE run)
Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:8000/api/cdi/taskflows/runs/1309386379683184640/terminate"
# -> {"run_ids":["1309386379683184640"],"terminated":true,"note":"IDMC accepted the terminate (204). ..."}

# session log of one child task (plain text, read-only)
curl.exe -s "http://127.0.0.1:8000/api/cdi/taskflows/runs/1309380263289049088/session-log?subtask=mt_m_MDM_ZLV_TTF_Guest_Basic"
```

Status mapping: taskflow RUNNING -> RUNNING, SUCCESS -> SUCCESS, FAILED -> FAILED,
SUSPENDED -> STOPPED (IDMC's word is kept in `state_text`). Child COMPLETED -> SUCCESS.
Errors: unknown name -> 404 (with a "Did you mean" hint for case slips); IDMC 403 -> 403 with
the Allowed Users hint; already running from this backend -> 409. Starts are never retried.
`POST /api/cdi/runs` also accepts `"parameters": {...}` for TASKFLOW tasks.

- **Doc-verified:** `GET {pod}/active-bpel/services/tf/status/{runId}` and its fields
  (status, startTime, endTime, errorMessage, subtaskDetails.details.tasks[] with assetName,
  status, rowsProcessed, successRows, errorRows, errorMessage, runId); `?subtaskDetails=Yes`
  is required since the April 2026 release (Informatica KB); purged runs answer
  `{"status": "No status available."}` (shown as UNKNOWN). Session log
  `GET /api/v2/activity/activityLog/{id}/sessionLog` (may be a ZIP; unzipped as text).
  Input fields go as top-level JSON keys of the rt POST body (Informatica KB curl example).
- **Verified live (2026-11-22):** the rt start call with INFA-SESSION-ID returns `RunId`;
  api name = task name; Allowed Users is case-sensitive.
- **Verified live (2026-11-22, run 1309380263289049088, read-only):** the child's tf-status
  `runId` (6) matched its activityLog row, whose `id` (011EWBC100000000019F) is what the
  sessionLog call wants - the real 10.9 KB session log came back with the FATAL line. A
  SUSPENDED run has no `endTime` (we use `updateTime`) and its `errorMessage` is a JSON string
  (we show its `reason`).
- **UNVERIFIED:** a SUCCESS run with real row counts (none run yet with jobInstanceId); that
  `{"jobInstanceId": ...}` in the rt body fixes the FATAL (shape is doc-based).
- Fake IDMC (`dev/fake_idmc.py`): taskflow `tf_demo_advanced` -> run id 900000000000000001
  (RUNNING, then SUCCESS with 2 children); 900000000000000002 is a SUSPENDED run with a failed
  child.

## Agent interface (for AI agents driving the app)

**Routes** (deep-linkable):

| Path | Screen |
|---|---|
| `/mdm/jobs`, `/cdi/jobs` | Job list (`/` redirects to `/mdm/jobs`) |
| `/mdm/jobs/:assetId`, `/cdi/jobs/:taskId` | One job with its Run button |
| `/mdm/runs/:runKey`, `/cdi/runs/:runKey` | Results screen for a run |
| `/monitor` | CDI Monitor tab |

**Declared actions** on `window.txmdm` (call `txmdm.describe()` in the console):

| Action | Does |
|---|---|
| `openSection(service)` | Show the `mdm` or `cdi` job list |
| `listMdmJobs()` / `listCdiTasks()` | Read the metadata-driven lists |
| `selectJob(service, jobId)` | Open one job |
| `runJob(service, jobId, apiName?)` | Start one run at once (no confirmation, owner decision 2026-11-23 01:53 CST), then open its results; never retries |
| `openRun(service, runKey)` | Open a results screen |
| `getRun(service, runKey)` | Read a run's status, counts, errors, log |
| `layout()` / `openNavSection(sectionId)` / `selectRibbonTab(tabId)` | OneNote layout: read sections + ribbon tabs, select a section or a ribbon tab |
| `openMonitor()` / `getMonitor(onlyMyTasks?, rowLimit?)` | Show / read the CDI Monitor (running + history) |
| `runTaskflowByName(name, parameters = {jobInstanceId: "ABC123"}, apiName?)` | Start a taskflow by name at once (no confirmation); opens `/taskflows/runs/<runId>` |
| `trackTaskflowRun(runId)` / `getTaskflowRun(runId)` | Show / read a taskflow run by IDMC run id |
| `getTaskflowSessionLog(runId, childTask?)` | Plain-text session log of one child task |
| `terminateTaskflow(runId)` | Abort a running taskflow at once (no confirmation) |
| `currentRoute()` / `describe()` | Where am I / what can I call |

The UI SDK agent bridge (`src/agent.ts`) is registered too; its allow-callback asks before any
button press. **Stable selectors:** every key control has a `data-testid` and `aria-label`
(full list in `specs/agent-interface.md`), e.g. `mdm-job-list`, `mdm-run`, `cdi-run`,
`run-result` (carries `data-run-key` and `data-status`), `run-status`, `run-counts`,
`run-errors`.

**OpenAPI:** `http://127.0.0.1:8000/openapi.json` (and `/docs`). Every operation has an
`operationId` (`cdi_list_tasks`, `cdi_start_run`, `cdi_get_run`, `mdm_list_jobs`,
`mdm_start_run`, `mdm_get_run`, ...), a summary, a description and typed response models - an
agent can call the backend directly.

## Copy IDMC curl (0.9.12.4)

Every IDMC-backed screen has a "Copy IDMC curl" button. It shows (inline) and copies a script that
runs against IDMC itself, not this app: step 1 logs in, the next steps are the exact IDMC calls the
backend made for that screen. Set the password first, in the same window:

```powershell
$env:IDMC_PASSWORD = "<your password>"
```

bash: `export IDMC_PASSWORD='<your password>'`. The script never contains your session id or
password. Write calls (Merge, Add, Edit) are marked "WRITES to IDMC": copying runs nothing.

## Which Informatica calls are used

| Step | CDI | MDM (Business 360) |
|---|---|---|
| Login | `POST {login}/saas/public/core/v3/login` -> `userInfo.sessionId`, `products[0].baseApiUrl` | same call, separate session |
| List | `GET {baseApiUrl}/public/core/v3/objects?q=type=='MTT'` (and WORKFLOW, TASKFLOW), paged 200 | `GET {baseApiUrl}/public/core/v3/objects?q=type=='MDM_JOB_DEFINITION'` |
| Run | `POST {baseApiUrl}/api/v2/job {taskFederatedId, taskType}`; advanced taskflow: `POST {pod}/active-bpel/rt/{apiName}` | `POST {mdm}/job/public/api/v1/jobInstance/{Ingress\|Egress\|MatchMerge} {jobDefinitionId}` |
| Monitor | `GET /api/v2/activity/activityMonitor`, then `GET /api/v2/activity/activityLog?runId&taskId` (state 1/2/3); taskflow: `GET {pod}/active-bpel/services/tf/status/{runId}` | `GET {mdm}/job/public/api/v1/jobInstance/{id}?details=true` (`_meta.state`, `jobLevelMetrics`) |
| Headers | v3: `INFA-SESSION-ID`; v2: `icSessionId` | platform: `INFA-SESSION-ID`; MDM: `IDS-SESSION-ID` |

### Monitor tab notes

- Field names (taskName, objectName, executionState, state 1/2/3/4, *Utc times, success/failed
  source/target rows, errorMsg, startedBy, runContextType, entries) are checked against the
  published IICS REST API Reference. In activityMonitor `objectName` is the *source object*, so
  the task name comes from `taskName`; in activityLog `objectName` is the task name.
- "My tasks" = names in `GET /api/cdi/tasks` (cached 5 min). If that list cannot be loaded,
  all jobs are shown with a note.
- "Running for" ticks every second in the browser from `started_at`; `elapsed_minutes` from the
  backend is start -> now (running) or start -> end (finished).
- A 429 stops auto-refresh for good; other IDMC errors in one section show as a note.
- **UNVERIFIED on the live org:** whether advanced taskflows (TASKFLOW type) show up in
  activityMonitor/activityLog at all (their mapping-task steps do show as MTT rows), and how
  child `entries` are named for taskflow steps. Mock-tested only so far.

## Verified vs. not verified

**Verified here:** backend unit/route tests (20, against a mocked IDMC), ruff + mypy strict
clean; frontend typecheck, unit tests, oxlint and production build clean.

**Not yet verified against the real org** (no live calls have been made by this code):

1. That the v3 login's `baseApiUrl` also serves the v2 `/api/v2/job` and activity calls.
2. **MDM job id resolution.** The documented list (`MDM_JOB_DEFINITION`) has no internal
   `jobDefinitionId` and no job type. `app/mdm/resolver.py` fills them by matching the
   definition name against recent job instances from the B360 job search. A job that has never
   run cannot be resolved this way and shows as "not runnable". The resolver is a pluggable
   class - swap it once the real source of the id is confirmed (e.g. export package).
3. The **egress jobType** is undocumented; egress is recognised by the word "egress" in the
   jobType the org returns.
4. Advanced taskflows: whether `INFA-SESSION-ID` works on the `/active-bpel/rt/` run call, the
   run-id field name in its response, and the published API name (defaults to the task name;
   the UI lets you type it).
5. Whether the org uses session-id auth or the newer JWT auth.
6. Exact field names in the MDM `details=true` error payload (errors are collected
   defensively from any `errorMessage`-style field).

Full, labelled list: `internal-notes/api-facts.md`.

## Adding records to B360 (0.9.8)

Each B360 Data entity page has an **Add records** ribbon tab (next to Records and Metadata):

- **Type it**: a form built from the entity's metadata through a Pydantic model
  (`backend/app/b360data/forms.py`). Required fields are starred. Save sends ONE record.
- **Generate test data**: put a number in "Number of records" (1-100), press Generate. The backend
  makes the rows with Faker (`backend/app/b360data/testdata.py`); nothing is sent yet. Edit or remove
  rows, then press **Send to B360**. Rows go one at a time; a 429, 401 or 403 stops the rest.
- Neither asks first (no pop-ups anywhere, owner decision 2026-11-23 01:53 CST); the result shows inline. After a save, the Records tab reloads so the new records show.
- **Source system** dropdown = `[sources] allowed` in `backend/b360_entities.toml` (today
  `zlv_ttf` (default), `zlv_eci`, `c360.default.system`, exact case). The backend refuses any other
  value. Informatica documents no API that lists source systems; an undocumented metadata call is
  tried and anything it finds that is not allowed is shown as "add to b360_entities.toml to allow".
  Edit the file and restart the backend to change the list.
- New backend dependency: `faker` (pip install -e ".[dev]" again after pulling).

## Which B360 entities the left pane shows (0.9.7)

The B360 Data notebook lists the business entities named in `backend/b360_entities.toml`
(today only `zlv_guest`). To change them, edit that file and **restart the backend** - it is
read once at startup. A bad file stops the backend with a clear error. A name that is not in
your org's metadata shows in the left pane as "not found in org". To use another file, set
`B360_ENTITIES_FILE` to its path.

```toml
[[entity]]
name = "zlv_guest"
# label = "ZLV Guest"   # optional override of the metadata label
```

"Show all entities" at the bottom of the notebook lists every entity in the org, grouped.
