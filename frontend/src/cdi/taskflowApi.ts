// Taskflows by name / by IDMC run id. Mirrors backend/app/cdi/taskflow_runs.py:
//   POST /api/cdi/taskflows/{name}/run          -> TaskflowStartResult (IDMC run id)
//   GET  /api/cdi/taskflows/runs/{runId}        -> TaskflowRunStatus (status + summary)
//   GET  /api/cdi/taskflows/runs/{runId}/session-log?subtask=  -> plain text

import { getJson, getText, postJson } from "../shared/api";
import type { RunStatus } from "../shared/run";

export interface RowSplit {
  source_success: number | null;
  source_failed: number | null;
  target_success: number | null;
  target_failed: number | null;
}

export interface SubtaskRun {
  name: string;
  type: string;
  run_id: string | null;
  status: RunStatus;
  state_text: string;
  started_at: string | null;
  ended_at: string | null;
  elapsed_minutes: number | null;
  rows_processed: number | null;
  success_rows: number | null;
  error_rows: number | null;
  rows: RowSplit;
  error: string;
  location: string;
  /** Set once the child has an activity log entry; then its session log can be fetched. */
  log_entry_id: string | null;
}

export interface RunTotals {
  rows_processed: number;
  success_rows: number;
  error_rows: number;
  source_success: number;
  source_failed: number;
  target_success: number;
  target_failed: number;
}

export interface TaskflowRunStatus {
  run_id: string;
  taskflow_name: string;
  location: string;
  status: RunStatus;
  state_text: string;
  is_final: boolean;
  started_at: string | null;
  ended_at: string | null;
  updated_at: string | null;
  elapsed_minutes: number | null;
  started_by: string;
  error: string;
  subtask_count: number | null;
  subtasks: SubtaskRun[];
  totals: RunTotals;
  notes: string[];
}

export interface TaskflowStartResult {
  run_id: string;
  taskflow_name: string;
  task_id: string;
  api_name: string;
  run_key: string;
  requested_at: string | null;
  status_path: string;
  parameters: Record<string, string>;
}

/** The taskflow input field tf_MDM_ZLV_TTF_Guest_Basic needs (exact, case-sensitive name). */
export const DEFAULT_PARAM_KEY = "jobInstanceId";
/** Starting value Vamsi chose (2026-11-22). Edit it in the UI before Run. */
export const DEFAULT_PARAM_VALUE = "ABC123";

export interface ParamRow {
  key: string;
  value: string;
}

/** Key/value rows -> JSON body object. Blank keys are dropped; keys are kept exactly as typed. */
export function paramsOf(rows: readonly ParamRow[]): Record<string, string> {
  const out: Record<string, string> = {};
  for (const row of rows) {
    if (row.key.trim() !== "") out[row.key.trim()] = row.value;
  }
  return out;
}

export interface TerminateResult {
  run_ids: string[];
  terminated: boolean;
  note: string;
}

const enc = encodeURIComponent;

export const taskflowApi = {
  runByName: (
    name: string,
    apiName: string | null,
    parameters: Record<string, string>,
  ): Promise<TaskflowStartResult> =>
    postJson<TaskflowStartResult>(`/api/cdi/taskflows/${enc(name)}/run`, {
      api_name: apiName,
      parameters,
    }),
  status: (runId: string): Promise<TaskflowRunStatus> =>
    getJson<TaskflowRunStatus>(`/api/cdi/taskflows/runs/${enc(runId)}`),
  terminate: (runId: string): Promise<TerminateResult> =>
    postJson<TerminateResult>(`/api/cdi/taskflows/runs/${enc(runId)}/terminate`, { run_ids: [] }),
  sessionLog: (runId: string, subtask: string | null): Promise<string> =>
    getText(
      `/api/cdi/taskflows/runs/${enc(runId)}/session-log` +
        (subtask === null ? "" : `?subtask=${enc(subtask)}`),
    ),
};

/** IDMC run ids are long digit strings; accept surrounding spaces, nothing else. */
export function cleanRunId(text: string): string | null {
  const trimmed = text.trim();
  return /^\d{1,30}$/.test(trimmed) ? trimmed : null;
}

/** "SUSPENDED" shows as STOPPED in our status; keep IDMC's word visible next to it. */
export function statusLabel(status: TaskflowRunStatus): string {
  return status.state_text === status.status ? status.status : `${status.status} (${status.state_text})`;
}
