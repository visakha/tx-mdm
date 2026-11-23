// CDI Monitor API + pure helpers. Mirrors backend/app/cdi/monitor.py (GET /api/cdi/monitor).

import { getJson } from "../shared/api";
import type { RunCounts, RunStatus, RunView } from "../shared/run";

export interface MonitorEntry {
  task_name: string;
  task_type: string;
  run_id: string | null;
  status: RunStatus;
  /** IDMC's own state word, e.g. RUNNING, COMPLETED_WITH_ERRORS. */
  state_text: string;
  started_at: string | null;
  ended_at: string | null;
  /** Server-computed: running = start -> now, finished = start -> end. */
  elapsed_minutes: number | null;
  counts: RunCounts;
  error: string;
  started_by: string;
  run_context: string;
  in_my_tasks: boolean;
  children: MonitorEntry[];
}

export interface MonitorSnapshot {
  as_of: string;
  running: MonitorEntry[];
  recent: MonitorEntry[];
  app_runs: RunView[];
  my_task_count: number;
  notes: string[];
}

export const monitorApi = {
  get: (onlyMyTasks: boolean, rowLimit = 50): Promise<MonitorSnapshot> =>
    getJson<MonitorSnapshot>(
      `/api/cdi/monitor?only_my_tasks=${String(onlyMyTasks)}&row_limit=${String(rowLimit)}`,
    ),
};

/** Whole minutes and seconds between two instants, e.g. "12m 05s". "-" when unknown. */
export function elapsedText(startIso: string | null, endMs: number | null): string {
  if (startIso === null || endMs === null) return "-";
  const seconds = Math.max(0, Math.floor((endMs - new Date(startIso).getTime()) / 1000));
  const m = Math.floor(seconds / 60);
  const s = seconds % 60;
  return `${String(m)}m ${String(s).padStart(2, "0")}s`;
}

/** Minutes as one decimal, e.g. "12.5 min". */
export function minutesText(minutes: number | null): string {
  return minutes === null ? "-" : `${minutes.toFixed(1)} min`;
}

/** Short summary counts for the header line. */
export function summarize(entries: MonitorEntry[]): { ok: number; failed: number; other: number } {
  let ok = 0;
  let failed = 0;
  let other = 0;
  for (const e of entries) {
    if (e.status === "SUCCESS") ok += 1;
    else if (e.status === "FAILED") failed += 1;
    else other += 1;
  }
  return { ok, failed, other };
}
