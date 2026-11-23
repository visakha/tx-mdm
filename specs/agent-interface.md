# Spec - agent interface (contract)

**As of:** 0.9.11 (2026-11-23). Replaces 1.0.0 (2026-11-22). Background:
`internal-notes/ui-sdk-philosophy.md`.

## Why

An agent (Muse, a Copilot, a test) must drive tx-mdm the way a person does - by name, without
scraping - and every feature must exist in the backend API first.

## Requirements

Layers (an agent may use any of the three)
- **A01** HTTP API is primary: every feature has a typed route under `/api/cdi`, `/api/mdm`,
  `/api/b360` (+ `/api/health`, `/api/about`), each with a stable `operationId`; Swagger at `/docs`,
  schema at `/openapi.json`. Route lists live in cdi.md, mdm.md, b360-data.md. `CODE`
- **A02** UI SDK bridge `window.agent` (`createAgent()` from `@ui-sdk/react/agent`, created before
  render): `snapshot()` (components, state, actions), `act({steps})` (setValue / press by label or
  ref, same callbacks as a person, `source: "agent"`), `query({text, within})`. `CODE`
- **A03** Ready signal: `window.agentReady` resolves and `<html data-agent-ready="true">` is set once
  `snapshot()` lists at least one component (gives up after 20 s). `CODE`
- **A04** App surface `window.txmdm` (`src/agentActions.ts`), typed, each action carrying
  `description` and `sideEffect`; `describe()` lists them. `CODE`

`window.txmdm` actions (sideEffect = acts on the live org)
- Read / navigate (no side effect): `describe`, `about`, `currentRoute`, `openSection`, `layout`,
  `openNavSection`, `selectRibbonTab`, `listMdmJobs`, `listCdiTasks`, `selectJob`, `openRun`, `getRun`,
  `openMonitor`, `getMonitor`, `openMdmMonitor`, `getMdmMonitor`, `lookupMdmJob`,
  `getTaskflowHistory`, `openTaskflowSummary(runId, domain='cdi')`, `openTaskflowLog`,
  `getTaskflowRun`, `getTaskflowSessionLog`, `listB360Entities(scope='focus')`, `getB360Metadata`,
  `getB360Records(name, {page, firstName, lastName, businessId, sort NEWEST_FIRST|OLDEST_FIRST})`,
  `getB360SourceSystems`, `getB360Sources(name, businessId)` (max 20), `getB360SourceRecord`,
  `openB360Record`, `generateB360Rows(name, count=5)` (preview only, nothing sent).
- Side effect: `runJob` (CDI task or MDM job, starts once, never retries),
  `runTaskflowByName(name, parameters={}, apiName?)` (jobInstanceId rule of cdi.md C06; parallel
  starts allowed), `terminateTaskflow`.

Labels and permissions
- **A05** Every SDK component (Input, Button, Select, Checkbox, Listbox, Tabs) has a unique, scoped
  `aria-label` - the agent's handle (e.g. "Search tasks, taskflows and jobs", "Run <name>",
  "Abort taskflow run <id>", "Open master record", "Add form ...", "Preview row N ...", "Edit ...").
  Tables are own markup, so each table has a Listbox picker beside it. `CODE`
- **A06** No confirmation for persons or agents: `allow: () => true` (owner decision 2026-11-23 01:53
  CST). `data-agent-confirm="<sentence>"` stays on Run / Abort / Send / Save only as a DESCRIPTIVE
  label so `snapshot()` tells the agent what the press does. `CODE`
- **A07** Deep links: every section and run is a URL (`/cdi/jobs`, `/mdm/jobs`, `/mdm/ingress`,
  `/mdm/egress`, `/{cdi|mdm}/runs/:runKey`, `/monitor`, `/mdm/running`, `/taskflows`,
  `/taskflows/runs/:id`, `/mdm/taskflows`, `/mdm/taskflows/runs/:id`, `/b360`, `/b360/:entity`);
  default `/mdm/jobs`; unknown ribbon tab id throws a clear error. `CODE`
- **A08** `data-testid` on key elements (lists, run box, status, counts) for Cypress; names in
  `internal-notes/ui-observations.md`. `CODE`

What agents cannot do through `window.txmdm`
- **A09** Create B360 records or save source edits: no action exists; an agent can only press the
  same Send / Save buttons a person presses, via `window.agent.act`. `CODE`
- **A10** See credentials or session ids (backend-only, shared.md S01); change `b360_entities.toml`;
  delete anything in the org (Clear is view-only). `CODE`

## Known gaps / UNVERIFIED

- `allow: () => true` departs from the SDK's own "mark what needs a person" guidance - by choice.
- `definePrimitive`, WebMCP tool registration, `subscribe`, history / undo: not used.
- Agent Cypress (`agent_b360_fake.cy.js`) has passed only against the fake IDMC (0.9.10); no agent
  drive against the live org yet.
- `@ui-sdk/react` is 0.1.0-beta.13; APIs may change on upgrade.
