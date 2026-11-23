// CDI API calls. Talks only to the FastAPI backend (/api/cdi/...).

import { getJson, postJson } from "../shared/api";
import type { RunView } from "../shared/run";

export type CdiTaskType = "MTT" | "WORKFLOW" | "TASKFLOW";

export interface CdiTask {
  id: string;
  name: string;
  path: string;
  type: CdiTaskType;
  description: string;
  updated_at: string | null;
  /** mdm = Business 360 taskflow (tf_MDM_*, *_EGR, *_IGR; needs jobInstanceId). Set by the backend. */
  domain: "cdi" | "mdm";
}

export interface CdiRunRequest {
  task_id: string;
  task_type: CdiTaskType;
  task_name: string;
  api_name: string | null;
  /** Advanced taskflows: Start-step input fields, e.g. { jobInstanceId: "<id>" } (MDM taskflows only). */
  parameters?: Record<string, string>;
}

export const cdiApi = {
  listTasks: (): Promise<CdiTask[]> => getJson<CdiTask[]>("/api/cdi/tasks"),
  startRun: (request: CdiRunRequest): Promise<RunView> =>
    postJson<RunView>("/api/cdi/runs", request),
  runUrl: (runKey: string): string => `/api/cdi/runs/${encodeURIComponent(runKey)}`,
};

export const CDI_TYPE_LABEL: Record<CdiTaskType, string> = {
  MTT: "Mapping task",
  WORKFLOW: "Linear taskflow",
  TASKFLOW: "Taskflow",
};
