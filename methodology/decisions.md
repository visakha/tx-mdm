# Decision log

Newest first. Each entry records what was decided, why, and what it supersedes. Reversing a
decision means adding a new entry, never editing an old one.

## 2026-11-22 — D11: Outbound HTTP ignores ambient proxy env vars by default

- **Decision:** the backend builds its httpx client with `trust_env=False` and an explicit
  `IDMC_PROXY_URL`. `HTTP_TRUST_ENV=true` opts in to env-var proxies, and falls back to the
  explicit setting with a warning if httpx cannot parse them.
- **Why:** a `NO_PROXY` value with an IPv6 entry made every IDMC call fail with `InvalidURL`.
  The tests passed only because their fixtures already used `trust_env=False`.

## 2026-11-22 — D10: Two start times on a run

- **Decision:** `started_at` = when this backend submitted the run (UI label "Requested");
  `idmc_started_at` = the start time IDMC reports (UI label "Started in IDMC").
- **Why:** overwriting one with the other mixed two different clocks. The fake IDMC exposed
  this by returning an old date.

## 2026-11-22 — D9: SDD methodology adopted

The constitution, six-phase lifecycle, operating procedures, hill climbing and this log are
adopted, adapted from the Spec-Driven Development method to a Python + TypeScript repo. SDD
tools (OpenSpec, SpecKit) are **not** installed; the artefact shapes are plain files.

## 2026-11-22 — D8: Repository layout

- `internal-docs/` holds the reference material Vamsi supplied.
- `internal-notes/` holds the agent's working notes.
- `methodology/`, `specs/` and `changes/` hold the SDD artefacts.
- `idq-barebones-v2/` is a read-only snapshot from idq-cli. The two projects are related but
  kept separate.

## 2026-11-22 — D7: Repo is public; only the password is masked

The Informatica reference files, the IDMC username and the hostnames are committed. Passwords,
session ids, `.env` files and credential screenshots never are.

## 2026-11-22 — D6: Agent-friendly navigation is part of the contract

- Stable routes: `/mdm/jobs`, `/mdm/jobs/:id`, `/mdm/runs/:runKey`, plus the same three under
  `/cdi/`.
- Declared actions on `window.txmdm`, alongside the UI SDK agent bridge.
- Stable `data-testid` / aria labels.
- An OpenAPI schema with `operationId`s, summaries and descriptions.

## 2026-11-22 — D5: Run rules

- One active run per job.
- Never auto-retry a failed run.
- 429 is a hard stop.
- One re-login on a 401.
- Agent-started runs need a person's confirmation.

## 2026-11-22 — D4: MDM job ids come from a pluggable, unverified resolver

`MDM_JOB_DEFINITION` metadata lacks `jobDefinitionId` and job type. `JobSearchResolver` fills
them in from job search, with caching. The egress jobType is never hard-coded. The resolver
will be replaced once the real id source is verified.

## 2026-11-22 — D3: Pickers come from metadata APIs

CDI uses v3 objects (MTT / WORKFLOW / TASKFLOW), paged 200 at a time. MDM uses v3 objects
(`MDM_JOB_DEFINITION`). Neither is built from past runs or hand-kept lists.

## 2026-11-22 — D2: Python FastAPI backend owns all Informatica calls

This supersedes the earlier plan for a TypeScript proxy (Vamsi, 20:37 CST). It also means
credentials stay server-side and CORS is avoided.

## 2026-11-22 — D1: Frontend stack

The Vercel UI SDK (`@ui-sdk/react`, including its agent bridge) + React + Vite + strict
TypeScript. No Next.js, no Ext JS, and not the AI SDK.
