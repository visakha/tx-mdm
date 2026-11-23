# Spec - agent interface (contract)

**Version:** 1.0.0 (2026-11-22) - **State:** Reconciled. Status: CODE.

Everything in this file is a public contract: renaming or removing any of it is a spec change
(constitution IX).

## Why

An AI agent (Muse today) must be able to drive the app deterministically: navigate, read lists,
start a run with a person's confirmation, and read results. It should not have to scrape
pixels or guess at selectors.

## FR-A01 Routes

| Path | Screen |
|---|---|
| `/` | Redirects to `/mdm/jobs` |
| `/mdm/jobs`, `/cdi/jobs` | Job list for a section |
| `/mdm/jobs/:assetId`, `/cdi/jobs/:taskId` | One job, with its Run button |
| `/mdm/runs/:runKey`, `/cdi/runs/:runKey` | Results screen for one run (deep-linkable while the backend holds the run) |

- An unknown path falls back to `/mdm/jobs`.
- Ids are URI-encoded.
- `src/shared/routes.ts` (`parseRoute` / `formatRoute`) is the only place paths are built.
  `routes.test.ts` covers it.

## FR-A02 Declared actions - `window.txmdm`

| Action | Side effect |
|---|---|
| `describe()` -> the action list | none |
| `currentRoute()` -> `{route, path}` | none |
| `openSection(service)` | navigates |
| `listMdmJobs()` / `listCdiTasks()` | none (reads the backend) |
| `selectJob(service, jobId)` | navigates |
| `runJob(service, jobId, apiName?)` | **starts a run, after `window.confirm`**, then navigates to its results screen |
| `openRun(service, runKey)` | navigates |
| `getRun(service, runKey)` -> RunView | none (refreshes the run on the backend) |

- `service` is `"mdm"` or `"cdi"`.
- The UI SDK agent bridge (`src/agent.ts`) is registered alongside these actions. Its
  allow-callback asks for confirmation before any button press.

## FR-A03 Stable selectors

| Area | `data-testid`s |
|---|---|
| Shell | `service-tabs`, `tab-mdm`, `tab-cdi` |
| MDM panel | `mdm-panel`, `mdm-refresh`, `mdm-filter`, `mdm-job-list`, `mdm-job-<assetId>`, `mdm-job-detail`, `mdm-run`, `mdm-load-error`, `mdm-start-error` |
| CDI panel | `cdi-panel`, `cdi-refresh`, `cdi-filter`, `cdi-task-list`, `cdi-task-<id>`, `cdi-task-detail`, `cdi-api-name`, `cdi-run`, `cdi-load-error`, `cdi-start-error` |
| Results | `run-result` (with `data-run-key` and `data-status` attributes), `run-job-name`, `run-status`, `run-started`, `run-idmc-started`, `run-log`, `run-counts`, `run-errors` |

Each interactive control also has an `aria-label`. Run buttons are labelled
`Run <job name>`.

## FR-A04 OpenAPI

`/openapi.json` gives every operation:

- an `operationId`: `cdi_list_tasks`, `cdi_start_run`, `cdi_list_runs`, `cdi_get_run`,
  `mdm_list_jobs`, `mdm_start_run`, `mdm_list_runs`, `mdm_get_run`, `health`
- a summary
- a description of its failure codes, where relevant
- a tag (`cdi`, `mdm`, `meta`)
- typed response models with field descriptions

## Out of scope

- Authentication of agents (the app is local, single-user).
- A server-side MCP endpoint.
