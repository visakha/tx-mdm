# Spec - CDI (Data Integration)

**Version:** 1.0.0 (2026-11-22) - **State:** Reconciled. Status: CODE. Nothing has been
checked LIVE yet.

## Why

Vamsi wants to run CDI mapping tasks and taskflows that load the MDM staging and C_S_* tables,
and to watch them through to a result, without the IDMC console.

## Requirements

**FR-C01 Task list from metadata.** `CODE`
- Given a valid session,
- when `GET /api/cdi/tasks` is called,
- then the backend queries `{baseApiUrl}/public/core/v3/objects` for `type=='MTT'`,
  `'WORKFLOW'` and `'TASKFLOW'`. It pages `limit=200` with `skip` until a page comes back
  short.
- It returns `{id, name, path, type}`, where `id` is the taskFederatedId.

**FR-C02 Run a mapping task or linear taskflow.** `CODE`
- Given a task of type MTT or WORKFLOW,
- when `POST /api/cdi/runs {task_id, task_type, task_name}` is called,
- then the backend sends `POST {baseApiUrl}/api/v2/job {taskFederatedId, taskType}` once,
  records the returned runId, and returns a QUEUED run.

**FR-C03 Run an advanced taskflow.** `CODE` (live auth UNVERIFIED)
- Given a TASKFLOW, when a run is started, then the backend calls
  `POST {pod}/active-bpel/rt/{api_name}`. `api_name` defaults to the task name, and the person
  can override it in the UI.

**FR-C04 Monitor.** `CODE`
- Given a run, when `GET /api/cdi/runs/{run_key}` is called:
  - The backend first checks `activityMonitor`, matching on runId and taskId.
  - Once the run has left the monitor, it reads `activityLog?runId&taskId`. State 1 -> SUCCESS,
    2 -> WARNING, 3 -> FAILED; `isStopped` -> STOPPED.
  - For an advanced taskflow, it reads `/active-bpel/services/tf/status/{runId}`.
  - Counts come from the success/failed source and target rows.
  - `idmc_started_at` comes from `startTimeUtc`.

**FR-C05 Failure on start.** `CODE`
- Given IDMC rejects the start,
- then the run is FAILED, the error text is shown, and nothing is retried.

## Out of scope

- Stopping jobs.
- Runtime parameter files.
- Mapping C_S_* tables to tasks (see `internal-notes/barebones-v2-and-cdi.md`).

## Success criteria

- SC-C01: the CDI tests in `backend/tests/` pass.
- SC-C02 (LIVE, pending): the first authorised live list returns the org's MTT, WORKFLOW and
  TASKFLOW assets.
