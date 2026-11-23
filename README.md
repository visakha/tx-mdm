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
| GET | `/api/mdm/jobs` | MDM job definitions (v3 objects) + resolved internal id / kind |
| POST | `/api/mdm/runs` | Start one MDM job `{asset_id}` |
| GET | `/api/mdm/runs/{run_key}` | Refresh and return the run |
| GET | `/api/health` | Liveness |

Rules built in: one active run per job (a second start gets HTTP 409); a failed run is
recorded and **never retried**; an HTTP 429 from Informatica is a hard stop, shown as-is;
a 401 triggers one fresh login and one resend of that request (the call never ran, so it is
not a job retry). The password never goes to the browser and is never echoed in errors.

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
| `runJob(service, jobId, apiName?)` | Start one run **after a person confirms**, then open its results; never retries |
| `openRun(service, runKey)` | Open a results screen |
| `getRun(service, runKey)` | Read a run's status, counts, errors, log |
| `openMonitor()` / `getMonitor(onlyMyTasks?, rowLimit?)` | Show / read the CDI Monitor (running + history) |
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
