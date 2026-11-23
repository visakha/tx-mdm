// Types that mirror the backend's shared run view (backend/app/common/runs.py).
// Same shape for CDI and MDM so the results screen is one component.

export type RunStatus =
  | "STARTING"
  | "QUEUED"
  | "RUNNING"
  | "SUCCESS"
  | "WARNING"
  | "FAILED"
  | "STOPPED"
  | "UNKNOWN";

export interface RunCounts {
  source_success: number | null;
  source_failed: number | null;
  target_success: number | null;
  target_failed: number | null;
}

export interface LogLine {
  at: string;
  message: string;
}

export interface RunView {
  run_key: string;
  service: "cdi" | "mdm";
  job_name: string;
  job_kind: string;
  status: RunStatus;
  /** When this backend submitted the run. */
  started_at: string | null;
  /** Start time IDMC reports for the run (B360 job instance / CDI activity log), once known. */
  idmc_started_at: string | null;
  ended_at: string | null;
  log: LogLine[];
  counts: RunCounts;
  errors: string[];
  /** 0.9.15: MDM job instance id IDMC gave this run (MDM only). */
  idmc_instance_id?: string | null;
  /** 0.9.15: IDMC portal page of this run, built by the backend (CDI: null until known). */
  portal_url?: string | null;
}

const TERMINAL: ReadonlySet<RunStatus> = new Set(["SUCCESS", "WARNING", "FAILED", "STOPPED"]);

export function isTerminal(status: RunStatus): boolean {
  return TERMINAL.has(status);
}

export function statusTone(status: RunStatus): "ok" | "warn" | "bad" | "busy" {
  switch (status) {
    case "SUCCESS":
      return "ok";
    case "WARNING":
    case "STOPPED":
    case "UNKNOWN":
      return "warn";
    case "FAILED":
      return "bad";
    case "STARTING":
    case "QUEUED":
    case "RUNNING":
      return "busy";
  }
}
