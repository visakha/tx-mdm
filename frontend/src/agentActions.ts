// Agent-facing navigation and actions: a small, typed, declared surface an AI agent (e.g. Muse)
// can call instead of clicking. Exposed as window.txmdm. Every action goes through the same
// backend API and the same URL routes the UI uses, so what the agent does is what a person sees.
//
// Starting a job is the only action with a side effect, and it asks a person first
// (window.confirm), the same rule the UI SDK agent bridge applies to button presses.

import { cdiApi, type CdiTask } from "./cdi/cdiApi";
import { monitorApi, type MonitorSnapshot } from "./cdi/monitorApi";
import { mdmApi, type MdmJob } from "./mdm/mdmApi";
import { getJson } from "./shared/api";
import type { RunView } from "./shared/run";
import {
  currentRoute,
  formatRoute,
  MONITOR_ROUTE,
  navigate,
  type Route,
  type Service,
} from "./shared/routes";

export interface ActionInfo {
  name: string;
  args: string;
  description: string;
  sideEffect: boolean;
}

export const ACTIONS: readonly ActionInfo[] = [
  { name: "describe", args: "()", description: "List these actions.", sideEffect: false },
  { name: "currentRoute", args: "()", description: "Current screen as a Route + its URL path.", sideEffect: false },
  { name: "openSection", args: "(service: 'mdm' | 'cdi')", description: "Show the job list of a section.", sideEffect: false },
  { name: "listMdmJobs", args: "()", description: "MDM job definitions from the metadata API (with runnable flag).", sideEffect: false },
  { name: "listCdiTasks", args: "()", description: "CDI tasks from the metadata API.", sideEffect: false },
  { name: "selectJob", args: "(service, jobId)", description: "Open one job's detail screen (/<service>/jobs/:jobId).", sideEffect: false },
  { name: "runJob", args: "(service, jobId, apiName?)", description: "Start one run after a person confirms; opens its results screen. Never retries.", sideEffect: true },
  { name: "openRun", args: "(service, runKey)", description: "Open the results screen for a run (/<service>/runs/:runKey).", sideEffect: false },
  { name: "getRun", args: "(service, runKey)", description: "Read a run's current state (status, counts, errors, log).", sideEffect: false },
  { name: "openMonitor", args: "()", description: "Show the CDI Monitor tab (/monitor).", sideEffect: false },
  { name: "getMonitor", args: "(onlyMyTasks = true, rowLimit = 50)", description: "Read running CDI jobs (elapsed minutes) + recent history (status, rows, errors, taskflow steps).", sideEffect: false },
];

async function runJob(service: Service, jobId: string, apiName?: string): Promise<RunView> {
  if (!window.confirm(`Allow the agent to start ${service.toUpperCase()} job ${jobId}?`)) {
    throw new Error("Run not started: the person declined.");
  }
  let run: RunView;
  if (service === "mdm") {
    run = await mdmApi.startRun(jobId);
  } else {
    const task = (await cdiApi.listTasks()).find((t) => t.id === jobId);
    if (task === undefined) throw new Error(`No CDI task ${jobId}`);
    run = await cdiApi.startRun({
      task_id: task.id,
      task_type: task.type,
      task_name: task.name,
      api_name: apiName ?? null,
    });
  }
  navigate({ screen: "run", service, runKey: run.run_key });
  return run;
}

export const txmdm = {
  describe: (): readonly ActionInfo[] => ACTIONS,
  currentRoute: (): { route: Route; path: string } => {
    const route = currentRoute();
    return { route, path: formatRoute(route) };
  },
  openSection: (service: Service): void => navigate({ screen: "jobs", service }),
  listMdmJobs: (): Promise<MdmJob[]> => mdmApi.listJobs(),
  listCdiTasks: (): Promise<CdiTask[]> => cdiApi.listTasks(),
  selectJob: (service: Service, jobId: string): void =>
    navigate({ screen: "job", service, jobId }),
  runJob,
  openRun: (service: Service, runKey: string): void =>
    navigate({ screen: "run", service, runKey }),
  getRun: (service: Service, runKey: string): Promise<RunView> =>
    getJson<RunView>(service === "mdm" ? mdmApi.runUrl(runKey) : cdiApi.runUrl(runKey)),
  openMonitor: (): void => navigate(MONITOR_ROUTE),
  getMonitor: (onlyMyTasks = true, rowLimit = 50): Promise<MonitorSnapshot> =>
    monitorApi.get(onlyMyTasks, rowLimit),
};

export type TxMdmAgentActions = typeof txmdm;

Object.assign(window, { txmdm });
