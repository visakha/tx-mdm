# Spec - shared behaviour

**As of:** 0.9.11 (2026-11-23). Replaces 1.0.0 (2026-11-22).

## Why

Vamsi runs and watches IDMC jobs and B360 data from one local app instead of the console, on
his Windows laptop, with the IDMC password never leaving that laptop.

## Architecture (fixed)

- Python FastAPI backend owns EVERY Informatica call and the credentials (`backend/.env`, git-ignored).
- Vite + React + strict TypeScript frontend, Vercel UI SDK (`@ui-sdk/react`); calls only `/api/...`
  on its own origin (Vite proxies `/api`, `/docs`, `/openapi.json` to `:8000`). No Next.js, no AI SDK.
- CDI, MDM and B360 Data are separate backend modules (`app/cdi`, `app/mdm`, `app/b360data`).

## Requirements

Session and calls
- **S01** Credentials stay server-side: no password or session id in any page, response, log or error. `CODE`
- **S02** CDI and MDM use separate v3 login sessions; one expiring does not affect the other. `CODE`
- **S03** On 401 the backend logs in again and resends ONCE; a second failure is returned, no loop. `CODE`
- **S04** IDMC 429 is a hard stop: passed through as 429 with a readable message, never retried;
  screens that auto-refresh stop refreshing for good after a 429. `CODE`
- **S05** Outbound proxy: env-var proxies ignored unless `HTTP_TRUST_ENV=true`; `IDMC_PROXY_URL` or direct. `CODE`

Runs
- **S06** One active run per CDI task / MDM job: a second start while one is not final -> 409, nothing
  sent (`POST /api/cdi/runs`, `POST /api/mdm/runs`). Exception: taskflows started by name may run in
  parallel (C07 in cdi.md). `CODE`
- **S07** Never auto-retry a start or a failed run. `CODE`
- **S08** Statuses: QUEUED -> RUNNING -> SUCCESS / WARNING / FAILED / STOPPED (final), or UNKNOWN. `CODE`
- **S09** Runs started here live in backend memory; a backend restart forgets them. `CODE` (by design)
- **S10** Results view: job name, status, Requested, Started in IDMC, Last refresh (just before Ended),
  Ended, short log, counts and errors (`GET /api/{cdi|mdm}/runs/{run_key}`). `CODE` / `LIVE`

Screen shell
- **S11** OneNote layout: left pane with search box and three notebooks - Data Integration (CDI),
  Business 360 (MDM), B360 Data - each with sections; contextual ribbon tabs on top. The URL is the
  section, so every screen is deep-linkable (`frontend/src/shared/routes.ts`). `CODE`
- **S12** Left-pane search lists sections and matching items (up to 25), labelled by kind
  (CDI task, CDI taskflow, MDM taskflow, MDM mapping task ...). `CODE`
- **S13** Polling is 15 s everywhere: one constant `POLL_SECONDS` in `frontend/src/shared/poll.ts`,
  pinned by a test. `CODE`
- **S14** While polling: shared progress bar (moving sweep while running - IDMC gives no percent;
  final colour by outcome), poll clock that changes colour each answer, "Last refresh" local time. `CODE`
- **S15** No pop-ups anywhere, for persons or agents: no window.confirm / alert / prompt in
  `frontend/src` (guard `noPopups.test.ts`); results and errors show inline. Owner decision
  2026-11-23 01:53 CST. `CODE`
- **S16** Colour only where he asked: magenta for system fields/columns in B360 Data. Taskflow
  history uses indentation, not colour. `CODE`
- **S17** Title bar: version label (from `GET /api/about`) and, just before it, an "API docs" link
  to `/docs` (Swagger) in a new tab. `CODE`

Contract and hygiene
- **S18** `GET /api/about` returns ONLY `version` + exactly three `highlights` (`app/version.py`).
  `GET /api/health` is liveness. `CODE` / `LIVE` (0.9.9 read through the tunnel)
- **S19** Typed end to end: every JSON route has a Pydantic `response_model` (the session log is plain text by design); frontend types are generated
  from OpenAPI (`backend/dev/gen_ts_types.py`) and a drift test fails when they disagree. No
  stringly-typed dicts. `CODE`
- **S20** ASCII only in code, logs, docs and terminal output (`backend/tests/test_ascii_only.py`). `CODE`
- **S21** Never call the live org from tests or builders; the fake IDMC stands in. `CODE`

Start-up (Windows / PowerShell)
- **S22** `start-backend.ps1 [-Pull] [-Install]`: makes/uses `backend\.venv`, reinstalls only when
  `pyproject.toml` changed or a core package is missing, creates `.env` from the example if missing
  and stops, then runs uvicorn on 0.0.0.0:8000 with the venv python. `CODE`
- **S23** `start-frontend.ps1`: `npm install` only when `package-lock.json` changed, then `npm run dev`. `CODE`

## Out of scope

Persisting runs across restarts; scheduling; multi-user access control; Next.js.

## Known gaps / UNVERIFIED

- Start-up scripts have not been run on this VM (no pwsh); his laptop is the proof.
- Cypress specs for the 0.9.1-0.9.9 screens are stale; only `agent_b360_fake.cy.js` (0.9.10) passed.
- The backend must bind 0.0.0.0 so both his browser and the Tailscale route reach it.
