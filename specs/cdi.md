# Spec - CDI (Data Integration)

**As of:** 0.9.11 (2026-11-23). Replaces 1.0.0 (2026-11-22).

## Why

Run CDI mapping tasks and taskflows that feed the MDM staging tables, and watch them to a result,
without the IDMC console. MDM-owned taskflows live in the Business 360 notebook, not here.

## Naming rule (Vamsi, 2026-11-23 00:41 CST; one place: `app/cdi/taskflow_kind.py`)

- Taskflow is MDM if its name starts `tf_MDM_` OR ends `_EGR` / `_IGR` (case-insensitive).
- Mapping task is MDM if it starts `mt_m_MDM_` OR ends `_EGR` / `_IGR`.
- `tf_Ldg_*`, `tf_Stg_*`, `mt_m_Ldg_*`, `mt_m_Stg_*` are ALWAYS CDI, even with "MDM" in the name.

## Requirements

- **C01** Task list from metadata: `GET /api/cdi/tasks` returns MTT, WORKFLOW and TASKFLOW objects
  (v3 objects API, paged) as `{id, name, path, type, domain}`, `domain` = `cdi` | `mdm` per the
  naming rule. `CODE` / `LIVE` (15 items, 2026-11-22)
- **C02** CDI notebook shows only `domain = cdi` items: sections Tasks, Taskflows, Monitor, Runs. `CODE`
- **C03** Run a mapping task / linear taskflow: `POST /api/cdi/runs {task_id, task_type, task_name}`
  -> one `POST {baseApiUrl}/api/v2/job`; QUEUED run returned. `CODE`
- **C04** Refresh one run: `GET /api/cdi/runs/{run_key}` (activityMonitor, then activityLog; taskflow
  via tf status). `GET /api/cdi/runs` lists runs started here. `CODE` / `LIVE`
- **C05** Run a taskflow by name: `POST /api/cdi/taskflows/{name}/run {api_name?, parameters?}` ->
  `POST {pod}/active-bpel/rt/{api_name}`; input fields are top-level JSON keys, exact case. `CODE` / `LIVE`
- **C06** jobInstanceId guard: an MDM taskflow without `jobInstanceId`, or a CDI taskflow WITH one,
  -> 400 with a plain message, IDMC never called (both C03 and C05). A lone MDM mapping task start
  -> 400 ("runs via its taskflow"). `CODE` (IDMC's own 400 "extra: jobInstanceId" seen LIVE)
- **C07** Same taskflow may be started again while running (no 409 here); IDMC decides. `CODE`
- **C08** Run tab (stacked, full width): MASTER taskflow list one line per name -> input fields + Run;
  DETAIL run history below; after Run stays on Run and puts the new run on top. CDI taskflows start
  with no input fields. `CODE`
- **C09** History: `GET /api/cdi/taskflows/{name}/history?row_limit=` = app-started taskflow runs +
  child mapping-task rows from the monitor; children grouped under a parent by TIME only (start inside
  parent window + 60 s), indented, no colour; unmatched children stand alone and say so. `CODE`
- **C10** Each taskflow row links (second column) to Summary and Session log for that run id; matched
  child rows link to the parent. `CODE`
- **C11** Summary: `GET /api/cdi/taskflows/runs/{run_id}` - status, progress bar, poll clock, times,
  per-child rows, errors, totals. Deep link `/taskflows/runs/:id`. `CODE` / `LIVE`
- **C12** Session log: `GET /api/cdi/taskflows/runs/{run_id}/session-log?subtask=` plain text (default: last child with a log; 404 if none yet), child
  picker. `CODE` / `LIVE`
- **C13** Abort (only while running, no pop-up): `POST /api/cdi/taskflows/runs/{run_id}/terminate`
  -> `PUT {pod}/active-bpel/services/tf/terminate {"runid": [...]}` (max 200 ids); 204 -> terminated;
  IDMC 500 -> 502 with its text. `CODE`
- **C14** Clear buttons (Run history, Summary, Session log) are VIEW-ONLY: they hide rows / unselect,
  nothing is deleted or stopped. Running rows are never hidden. `CODE`
- **C15** Monitor: `GET /api/cdi/monitor?only_my_tasks=true&row_limit=50` - running jobs (elapsed
  minutes, child steps) + finished history; tabs Everything / Running now / History / Started here;
  15 s refresh with Pause. Read-only. `CODE` / `LIVE`

## Out of scope

Runtime parameter files; mapping C_S_* tables to tasks; stopping a mapping task on its own.

## Known gaps / UNVERIFIED

- Terminate has never been exercised against the live org (his aborts were from the portal). A
  person's abort reports FAILED / `processManuallyTerminated`, shown as "Aborted" (LIVE).
- IDMC lists only child mapping tasks in activityMonitor/Log, never the taskflow itself (LIVE), so
  portal-started taskflow runs appear only as children; the child-name guess `tf_X -> mt_m_X` is a guess.
- Whether IDMC accepts two concurrent instances of one taskflow: UNVERIFIED.
- Run id field casing in the rt reply (`RunId` / `runId`): both handled, which one is real UNVERIFIED.
