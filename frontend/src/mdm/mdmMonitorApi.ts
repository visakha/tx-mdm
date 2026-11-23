// Business 360 "Currently running": every b360.* / c360.* job in the org, whoever started it
// (this app, the portal, another machine or user). Read-only backend calls.

import { getJson } from "../shared/api";
import type { RunCounts, RunStatus } from "../shared/run";
import type { MdmJobKind } from "./mdmApi";

export interface MdmJobInstance {
  /** Full job instance id - shown whole, never shortened. */
  instance_id: string;
  name: string;
  job_definition_id: string;
  job_type: string;
  kind: MdmJobKind;
  status: RunStatus;
  state_text: string;
  started_at: string | null;
  ended_at: string | null;
  elapsed_minutes: number | null;
  started_by: string;
  counts: RunCounts;
  errors: string[];
}

export interface MdmMonitorSnapshot {
  as_of: string;
  running: MdmJobInstance[];
  recent: MdmJobInstance[];
  other_types_hidden: number;
  notes: string[];
}

/** Trim spaces, quotes and a trailing "." from a pasted id. */
export function cleanInstanceId(text: string): string {
  return text.trim().replace(/^["']+|["'.]+$/g, "").trim();
}

/** "12.3 min" or "-". */
export function minutes(value: number | null): string {
  return value === null ? "-" : `${value.toFixed(1)} min`;
}

export const mdmMonitorApi = {
  get: (rowLimit = 25): Promise<MdmMonitorSnapshot> =>
    getJson<MdmMonitorSnapshot>(`/api/mdm/monitor?row_limit=${String(rowLimit)}`),
  lookup: (instanceId: string): Promise<MdmJobInstance> =>
    getJson<MdmJobInstance>(`/api/mdm/job-instances/${encodeURIComponent(cleanInstanceId(instanceId))}`),
};
