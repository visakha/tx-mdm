// MDM (Business 360) API calls. Talks only to the FastAPI backend (/api/mdm/...).

import { getJson, postJson } from "../shared/api";
import type { RunView } from "../shared/run";

export type MdmJobKind = "Ingress" | "Egress" | "MatchMerge" | "Unknown";

export interface MdmJob {
  asset_id: string;
  name: string;
  path: string;
  description: string;
  updated_at: string | null;
  job_definition_id: string | null;
  job_type: string | null;
  kind: MdmJobKind;
  runnable: boolean;
  note: string;
}

export const mdmApi = {
  listJobs: (): Promise<MdmJob[]> => getJson<MdmJob[]>("/api/mdm/jobs"),
  startRun: (assetId: string): Promise<RunView> =>
    postJson<RunView>("/api/mdm/runs", { asset_id: assetId }),
  runUrl: (runKey: string): string => `/api/mdm/runs/${encodeURIComponent(runKey)}`,
};
