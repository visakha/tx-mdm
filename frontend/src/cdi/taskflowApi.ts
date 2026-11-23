// Taskflows by name / by IDMC run id. Mirrors backend/app/cdi/taskflow_runs.py:
//   POST /api/cdi/taskflows/{name}/run          -> TaskflowStartResult (IDMC run id)
//   GET  /api/cdi/taskflows/runs/{runId}        -> TaskflowRunStatus (status + summary)
//   GET  /api/cdi/taskflows/runs/{runId}/session-log?subtask=  -> plain text

import { isDigits } from "../shared/text";
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
  /** IDMC code processManuallyTerminated: a person aborted it. IDMC still says FAILED. */
  aborted: boolean;
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

/** The input field every Business 360 / MDM taskflow needs (exact, case-sensitive name).
 * MDM taskflows: tf_MDM_*, *_EGR, *_IGR (rule lives in backend app/cdi/taskflow_kind.py; the
 * backend tags each task with domain). CDI taskflows (tf_Ldg_*, tf_Stg_*) must NOT get it. 0.9.4:
 * no pre-filled value any more - he types the real id. */
export const JOB_INSTANCE_ID = "jobInstanceId";

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

/** One row of a taskflow's run history (GET /api/cdi/taskflows/{name}/history). */
export interface HistoryRow {
  run_id: string | null;
  level: "taskflow" | "child";
  task_name: string;
  task_type: string;
  source: "app" | "monitor";
  /** True when run_id is a taskflow run id (click opens Track run id). */
  trackable: boolean;
  status: RunStatus;
  state_text: string;
  is_running: boolean;
  started_at: string | null;
  ended_at: string | null;
  elapsed_minutes: number | null;
  rows_ok: number | null;
  rows_failed: number | null;
  error: string;
  started_by: string;
}

export interface TaskflowHistory {
  taskflow_name: string;
  as_of: string;
  rows: HistoryRow[];
  child_tasks: string[];
  child_names_guessed: boolean;
  /** 0.9.15: where child_tasks came from; "references" = IDMC v3 objects/<id>/references. */
  child_names_source?: "tracked run" | "references" | "guess" | "none";
  taskflow_in_monitor: boolean;
  notes: string[];
}

/** A just-accepted start as a history row, shown before the next 15 s refresh. */
export function startedRow(started: TaskflowStartResult): HistoryRow {
  return {
    run_id: started.run_id,
    level: "taskflow",
    task_name: started.taskflow_name,
    task_type: "TASKFLOW",
    source: "app",
    trackable: true,
    status: "QUEUED",
    state_text: "STARTED (accepted by IDMC)",
    is_running: true,
    started_at: started.requested_at ?? new Date().toISOString(),
    ended_at: null,
    elapsed_minutes: null,
    rows_ok: null,
    rows_failed: null,
    error: "",
    started_by: "",
  };
}

/** Put fresh local starts on top of a fetched history, without duplicates. */
export function mergeStarted(rows: readonly HistoryRow[], local: readonly HistoryRow[]): HistoryRow[] {
  const known = new Set(rows.map((r) => r.run_id));
  return [...local.filter((r) => !known.has(r.run_id)), ...rows];
}

/** 0.9.2: one taskflow run with its child mapping-task runs directly beneath it. */
export interface HistoryGroup {
  parent: HistoryRow | null;
  children: HistoryRow[];
}

const ms = (iso: string | null): number | null => {
  if (iso === null) return null;
  const t = Date.parse(iso);
  return Number.isNaN(t) ? null : t;
};

/**
 * Group history rows: each taskflow run on top, its child mapping tasks under it.
 * Child run ids are small mapping-task numbers (e.g. 10), never taskflow ids, so a child is
 * matched by time only: its start falls inside the parent's start..end window (end = now while
 * running; 60 s slack before start). The latest-starting matching parent wins. Children with no
 * matching parent stay as standalone groups (parent null). Running groups first, then newest.
 */
export function groupHistory(rows: readonly HistoryRow[], nowMs: number = Date.now()): HistoryGroup[] {
  const parents = rows.filter((r) => r.level === "taskflow");
  const groups: HistoryGroup[] = parents.map((p) => ({ parent: p, children: [] }));
  const loose: HistoryGroup[] = [];
  for (const child of rows.filter((r) => r.level !== "taskflow")) {
    const cs = ms(child.started_at);
    let best: HistoryGroup | null = null;
    let bestStart = -Infinity;
    if (cs !== null) {
      for (const g of groups) {
        const p = g.parent;
        const ps = p === null ? null : ms(p.started_at);
        if (p === null || ps === null) continue;
        const pe = ms(p.ended_at) ?? (p.is_running ? nowMs : null);
        if (pe === null) continue;
        if (cs >= ps - 60_000 && cs <= pe + 60_000 && ps > bestStart) {
          best = g;
          bestStart = ps;
        }
      }
    }
    if (best !== null) best.children.push(child);
    else loose.push({ parent: null, children: [child] });
  }
  const running = (g: HistoryGroup): boolean =>
    (g.parent?.is_running ?? false) || g.children.some((c) => c.is_running);
  const start = (g: HistoryGroup): number => ms((g.parent ?? g.children[0])?.started_at ?? null) ?? 0;
  for (const g of groups) g.children.sort((a, b) => (ms(a.started_at) ?? 0) - (ms(b.started_at) ?? 0));
  return [...groups, ...loose].sort(
    (a, b) => Number(running(b)) - Number(running(a)) || start(b) - start(a),
  );
}

// Starts made by the agent bridge also land in the Run tab's history at once.
type StartListener = (started: TaskflowStartResult) => void;
const startListeners = new Set<StartListener>();
export function announceTaskflowStart(started: TaskflowStartResult): void {
  for (const listener of startListeners) listener(started);
}
export function onTaskflowStart(listener: StartListener): () => void {
  startListeners.add(listener);
  return () => startListeners.delete(listener);
}

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
  history: (name: string, rowLimit = 100): Promise<TaskflowHistory> =>
    getJson<TaskflowHistory>(`/api/cdi/taskflows/${enc(name)}/history?row_limit=${String(rowLimit)}`),
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
  return isDigits(trimmed, 30) ? trimmed : null;
}

/** "SUSPENDED" shows as STOPPED in our status; keep IDMC's word visible next to it. */
export function statusLabel(status: Pick<TaskflowRunStatus, "status" | "state_text" | "aborted">): string {
  if (status.aborted) return `ABORTED (IDMC: ${status.state_text})`;
  return status.state_text === status.status ? status.status : `${status.status} (${status.state_text})`;
}
