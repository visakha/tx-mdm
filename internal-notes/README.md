# internal-notes — start here (for the agent working on this repo)

These notes are for whichever agent works on tx-mdm next: Muse today, maybe a different agent
tomorrow. They hold what you need so you don't have to rediscover it. They cover only
this project.

Read in this order:

1. this file — what the project is and how it is laid out
2. [`gotchas.md`](gotchas.md) — things that have already cost time
3. [`api-facts.md`](api-facts.md) — which Informatica facts are verified and which are not
4. [`run-and-test.md`](run-and-test.md) — the exact commands
5. [`next-steps.md`](next-steps.md) — what is open, in order
6. [`barebones-v2-and-cdi.md`](barebones-v2-and-cdi.md) — how the imported Snowflake package relates to the CDI side
7. [`../methodology/`](../methodology/) — how work is done here (constitution, lifecycle, procedures, decisions)

## What tx-mdm is

A small app for running and watching Informatica IDMC jobs through the APIs, without using the
IDMC web console:

- **CDI** (Data Integration): mapping tasks (MTT), linear taskflows (WORKFLOW) and advanced
  taskflows (TASKFLOW).
- **MDM** (Business 360): ingress, egress and match-merge job definitions.
- One results screen shape for both: job name, status, the time this app requested the run, the
  time IDMC says it started, a short live log, counts on one side and errors on the other.

## Layout

```
backend/            Python 3.12 FastAPI. Owns EVERY Informatica call and holds the credentials.
  app/config.py       Settings from env / backend/.env (password is a SecretStr)
  app/dependencies.py explicit wiring (lru_cache); build_http_client() owns proxy policy
  app/common/         idmc_session.py (v3 login, 401 re-login once, 429 hard stop),
                      runs.py (RunStatus, RunView, RunRegistry: one active run per job)
  app/cdi/            endpoints.py (named URL constants), models, client, service, router (/api/cdi)
  app/mdm/            endpoints, models, client, resolver (UNVERIFIED, pluggable), service, router (/api/mdm)
  dev/fake_idmc.py    offline fake IDMC for local runs (port 8900)
  tests/              pytest + respx; no network
frontend/           React 19 + Vite + strict TS + @ui-sdk/react (the "UI SDK")
  src/shared/routes.ts   typed routes, the source of truth for which screen is shown
  src/agentActions.ts    window.txmdm: declared agent actions (see README "Agent interface")
  src/agent.ts           UI SDK agent bridge; its allow-callback confirms any button press
  src/cdi/, src/mdm/     one panel + one API module each; they do not import each other
  src/shared/            api.ts, run.ts, RunResult.tsx, usePicker.ts, useRunPolling.ts
internal-docs/      reference material Vamsi supplied (Postman collection, B360 PDF, .http, research notes)
internal-notes/     these notes
methodology/        constitution, SDD lifecycle, operating procedures, decisions, review guide
specs/              current-state specs: cdi.md, mdm.md, agent-interface.md
changes/            one folder per change proposal (proposal / specs / design / tasks)
idq-barebones-v2/   read-only snapshot of the Snowflake bare-bones package (from idq-cli)
```

## Shape rules that keep it simple

- CDI and MDM are separate: they have their own session, host, list, run registry, router and
  panel. They share only the app shell and the RunView shape.
- Pickers come from the IDMC metadata APIs. Never build them from past runs or a hand-kept list.
- One active run per job. A failed run is never retried. HTTP 429 is a hard stop.
- The browser never sees credentials. It only calls `/api/...` on its own origin, through the
  Vite proxy.
