// Agent-facing navigation and actions: a small, typed, declared surface an AI agent (e.g. Muse)
// can call instead of clicking. Exposed as window.txmdm. Every action goes through the same
// backend API and the same URL routes the UI uses, so what the agent does is what a person sees.
//
// Starting a job is the only action with a side effect, and it asks a person first
// (window.confirm), the same rule the UI SDK agent bridge applies to button presses.

import { cdiApi, type CdiTask } from "./cdi/cdiApi";
import { monitorApi, type MonitorSnapshot } from "./cdi/monitorApi";
import {
  DEFAULT_PARAM_KEY,
  DEFAULT_PARAM_VALUE,
  taskflowApi,
  type TaskflowRunStatus,
  type TaskflowStartResult,
  type TerminateResult,
} from "./cdi/taskflowApi";
import { mdmApi, type MdmJob } from "./mdm/mdmApi";
import { getJson } from "./shared/api";
import type { RunView } from "./shared/run";
import {
  RIBBON,
  SECTIONS,
  sectionOf,
  selectRibbonTab,
  ribbonTab,
  type SectionId,
} from "./shell/sections";
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
  { name: "layout", args: "()", description: "OneNote layout: left-pane sections, the selected section, its ribbon tabs and the selected tab.", sideEffect: false },
  { name: "openNavSection", args: "(sectionId)", description: "Select a left-pane section (cdi-tasks, cdi-taskflows, cdi-monitor, cdi-runs, mdm-all, mdm-ingress, mdm-egress, mdm-runs).", sideEffect: false },
  { name: "selectRibbonTab", args: "(tabId)", description: "Select a ribbon tab of the current section (see layout()).", sideEffect: false },
  { name: "listMdmJobs", args: "()", description: "MDM job definitions from the metadata API (with runnable flag).", sideEffect: false },
  { name: "listCdiTasks", args: "()", description: "CDI tasks from the metadata API.", sideEffect: false },
  { name: "selectJob", args: "(service, jobId)", description: "Open one job's detail screen (/<service>/jobs/:jobId).", sideEffect: false },
  { name: "runJob", args: "(service, jobId, apiName?)", description: "Start one run after a person confirms; opens its results screen. Never retries.", sideEffect: true },
  { name: "openRun", args: "(service, runKey)", description: "Open the results screen for a run (/<service>/runs/:runKey).", sideEffect: false },
  { name: "getRun", args: "(service, runKey)", description: "Read a run's current state (status, counts, errors, log).", sideEffect: false },
  { name: "openMonitor", args: "()", description: "Show the CDI Monitor tab (/monitor).", sideEffect: false },
  { name: "runTaskflowByName", args: "(name, parameters = { jobInstanceId: 'ABC123' }, apiName?)", description: "Start an advanced taskflow by name with its input fields, after a person confirms; opens /taskflows/runs/:runId. Never retries.", sideEffect: true },
  { name: "trackTaskflowRun", args: "(runId)", description: "Show one taskflow run by IDMC run id (/taskflows/runs/:runId).", sideEffect: false },
  { name: "getTaskflowRun", args: "(runId)", description: "Read a taskflow run by IDMC run id: status, times, per-child rows and errors, totals.", sideEffect: false },
  { name: "terminateTaskflow", args: "(runId)", description: "Terminate (abort) a running taskflow by IDMC run id, after a person confirms. Never retried.", sideEffect: true },
  { name: "getTaskflowSessionLog", args: "(runId, childTask?)", description: "Plain-text session log of one child task of a taskflow run.", sideEffect: false },
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

async function runTaskflowByName(
  name: string,
  parameters: Record<string, string> = { [DEFAULT_PARAM_KEY]: DEFAULT_PARAM_VALUE },
  apiName?: string,
): Promise<TaskflowStartResult> {
  const shown = Object.entries(parameters)
    .map(([k, v]) => `${k}=${v}`)
    .join(", ");
  if (!window.confirm(`Allow the agent to start taskflow ${name} with ${shown || "no input fields"}?`)) {
    throw new Error("Run not started: the person declined.");
  }
  const started = await taskflowApi.runByName(name, apiName ?? null, parameters);
  navigate({ screen: "taskflows", service: "cdi", runId: started.run_id });
  return started;
}

function currentSection(): SectionId {
  return sectionOf(currentRoute(), null);
}

async function terminateTaskflow(runId: string): Promise<TerminateResult> {
  if (!window.confirm(`Allow the agent to TERMINATE taskflow run ${runId}?`)) {
    throw new Error("Not terminated: the person declined.");
  }
  return taskflowApi.terminate(runId);
}

export const txmdm = {
  describe: (): readonly ActionInfo[] => ACTIONS,
  layout: (): {
    sections: { id: SectionId; notebook: string; label: string }[];
    section: SectionId;
    tabs: readonly { id: string; label: string }[];
    tab: string;
  } => {
    const section = currentSection();
    return {
      sections: SECTIONS.map((s) => ({ id: s.id, notebook: s.notebook, label: s.label })),
      section,
      tabs: RIBBON[section],
      tab: ribbonTab(section),
    };
  },
  openNavSection: (sectionId: SectionId): void => {
    const found = SECTIONS.find((s) => s.id === sectionId);
    if (found === undefined) throw new Error(`No section ${sectionId}`);
    navigate(found.route);
  },
  selectRibbonTab: (tabId: string): void => selectRibbonTab(currentSection(), tabId),
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
  runTaskflowByName,
  trackTaskflowRun: (runId: string): void =>
    navigate({ screen: "taskflows", service: "cdi", runId }),
  terminateTaskflow,
  getTaskflowRun: (runId: string): Promise<TaskflowRunStatus> => taskflowApi.status(runId),
  getTaskflowSessionLog: (runId: string, childTask?: string): Promise<string> =>
    taskflowApi.sessionLog(runId, childTask ?? null),
  getMonitor: (onlyMyTasks = true, rowLimit = 50): Promise<MonitorSnapshot> =>
    monitorApi.get(onlyMyTasks, rowLimit),
};

export type TxMdmAgentActions = typeof txmdm;

Object.assign(window, { txmdm });
