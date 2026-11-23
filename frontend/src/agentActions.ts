// Agent-facing navigation and actions: a small, typed, declared surface an AI agent (e.g. Muse)
// can call instead of clicking. Exposed as window.txmdm. Every action goes through the same
// backend API and the same URL routes the UI uses, so what the agent does is what a person sees.
//
// Starting a job is the only action with a side effect, and it asks a person first
// (window.confirm), the same rule the UI SDK agent bridge applies to button presses.

import { cdiApi, type CdiTask } from "./cdi/cdiApi";
import { monitorApi, type MonitorSnapshot } from "./cdi/monitorApi";
import {
  announceTaskflowStart,
  taskflowApi,
  type TaskflowHistory,
  type TaskflowRunStatus,
  type TaskflowStartResult,
  type TerminateResult,
} from "./cdi/taskflowApi";
import { mdmApi, type MdmJob } from "./mdm/mdmApi";
import { mdmMonitorApi, type MdmJobInstance, type MdmMonitorSnapshot } from "./mdm/mdmMonitorApi";
import {
  b360Api,
  type BusinessEntity,
  type BusinessEntityList,
  type GeneratedRows,
  type RecordPage,
  type SourceSystemList,
} from "./b360/b360Api";
import { openB360Record } from "./b360/B360DataPanel";
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
  B360_ROUTE,
  currentRoute,
  formatRoute,
  MDM_MONITOR_ROUTE,
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
  { name: "about", args: "()", description: "Backend version + its top three highlights (GET /api/about).", sideEffect: false },
  { name: "currentRoute", args: "()", description: "Current screen as a Route + its URL path.", sideEffect: false },
  { name: "openSection", args: "(service: 'mdm' | 'cdi')", description: "Show the job list of a section.", sideEffect: false },
  { name: "layout", args: "()", description: "OneNote layout: left-pane sections, the selected section, its ribbon tabs and the selected tab.", sideEffect: false },
  { name: "openNavSection", args: "(sectionId)", description: "Select a left-pane section (cdi-tasks, cdi-taskflows, cdi-monitor, cdi-runs, mdm-all, mdm-ingress, mdm-egress, mdm-taskflows, mdm-running, mdm-runs, b360-data).", sideEffect: false },
  { name: "selectRibbonTab", args: "(tabId)", description: "Select a ribbon tab of the current section (see layout()).", sideEffect: false },
  { name: "listMdmJobs", args: "()", description: "MDM job definitions from the metadata API (with runnable flag).", sideEffect: false },
  { name: "listCdiTasks", args: "()", description: "CDI tasks from the metadata API.", sideEffect: false },
  { name: "selectJob", args: "(service, jobId)", description: "Open one job's detail screen (/<service>/jobs/:jobId).", sideEffect: false },
  { name: "runJob", args: "(service, jobId, apiName?)", description: "Start one run after a person confirms; opens its results screen. Never retries.", sideEffect: true },
  { name: "openRun", args: "(service, runKey)", description: "Open the results screen for a run (/<service>/runs/:runKey).", sideEffect: false },
  { name: "getRun", args: "(service, runKey)", description: "Read a run's current state (status, counts, errors, log).", sideEffect: false },
  { name: "openMonitor", args: "()", description: "Show the CDI Monitor tab (/monitor).", sideEffect: false },
  { name: "runTaskflowByName", args: "(name, parameters = {}, apiName?)", description: "Start an advanced taskflow by name with its input fields. Business 360 taskflows (tf_MDM_*, *_EGR, *_IGR; task domain mdm) NEED { jobInstanceId: '<real id>' }; CDI taskflows (tf_Ldg_*, tf_Stg_*) must get none - the backend answers 400 otherwise. after a person confirms; stays on the Run tab and puts the run on top of the history (open it with openTaskflowSummary / openTaskflowLog). Parallel starts allowed. Never retries.", sideEffect: true },
  { name: "getTaskflowHistory", args: "(name, rowLimit = 100)", description: "Run history of one taskflow (Run tab detail): running first, then recent; taskflow rows from this app are trackable, child task rows are not.", sideEffect: false },
  { name: "openTaskflowSummary", args: "(runId, domain = 'cdi')", description: "Open the Summary tab of one taskflow run by IDMC run id (/taskflows/runs/:runId): status, progress, child rows, Abort.", sideEffect: false },
  { name: "openTaskflowLog", args: "(runId, domain = 'cdi')", description: "Open the Session log tab of one taskflow run by IDMC run id.", sideEffect: false },
  { name: "getTaskflowRun", args: "(runId)", description: "Read a taskflow run by IDMC run id: status, times, per-child rows and errors, totals.", sideEffect: false },
  { name: "terminateTaskflow", args: "(runId)", description: "Terminate (abort) a running taskflow by IDMC run id, after a person confirms. Never retried.", sideEffect: true },
  { name: "getTaskflowSessionLog", args: "(runId, childTask?)", description: "Plain-text session log of one child task of a taskflow run.", sideEffect: false },
  { name: "getMonitor", args: "(onlyMyTasks = true, rowLimit = 50)", description: "Read running CDI jobs (elapsed minutes) + recent history (status, rows, errors, taskflow steps).", sideEffect: false },
  { name: "openMdmMonitor", args: "()", description: "Show Business 360 Currently running (/mdm/running).", sideEffect: false },
  { name: "getMdmMonitor", args: "(rowLimit = 25)", description: "Read every running B360 job (b360.* / c360.*) in the org, whoever started it, plus recently finished ones.", sideEffect: false },
  { name: "listB360Entities", args: "(scope = 'focus')", description: "B360 Data: business entities derived from the metadata APIs (GET /api/b360/entities?scope=focus|all). focus (default) = only the entities in backend/b360_entities.toml (left pane); all = every entity with its category (CUSTOM, OUT_OF_THE_BOX c360.*, REFERENCE rdm.*, TEMPLATE entity.*). Opens the notebook (all-entities page).", sideEffect: false },
  { name: "getB360Metadata", args: "(name)", description: "B360 Data: one entity's typed fields + field groups from its metadata.", sideEffect: false },
  { name: "getB360Records", args: "(name)", description: "B360 Data: open an entity and read its first 10 records (top-level values + field group rows).", sideEffect: false },
  { name: "getB360SourceSystems", args: "()", description: "B360 Data Add records: source systems allowed in backend/b360_entities.toml (default zlv_ttf) plus any an undocumented IDMC metadata call found.", sideEffect: false },
  { name: "generateB360Rows", args: "(name, count = 5)", description: "B360 Data Add records: Faker test rows (1-100) for an entity from the backend. Preview only, nothing is sent to IDMC. Sending is a person's Save / Send to B360 button (it asks first).", sideEffect: false },
  { name: "openB360Record", args: "(businessId)", description: "B360 Data: open one record of the open entity; its field groups show stacked below.", sideEffect: false },
  { name: "lookupMdmJob", args: "(instanceId)", description: "Read any B360 job instance by its full id (status, times, started by, counts, errors).", sideEffect: false },
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
  parameters: Record<string, string> = {},
  apiName?: string,
): Promise<TaskflowStartResult> {
  const shown = Object.entries(parameters)
    .map(([k, v]) => `${k}=${v}`)
    .join(", ");
  if (!window.confirm(`Allow the agent to start taskflow ${name} with ${shown || "no input fields"}?`)) {
    throw new Error("Run not started: the person declined.");
  }
  const started = await taskflowApi.runByName(name, apiName ?? null, parameters);
  // 0.9.1: stay on the Run tab; the run shows on top of the history. Open it with
  // openTaskflowSummary(runId) / openTaskflowLog(runId) (the history row links).
  announceTaskflowStart(started);
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
  about: (): Promise<{ version: string; highlights: string[] }> =>
    getJson<{ version: string; highlights: string[] }>("/api/about"),
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
  openTaskflowSummary: (runId: string, domain: "cdi" | "mdm" = "cdi"): void => {
    navigate({ screen: "taskflows", service: domain, runId });
    selectRibbonTab(domain === "mdm" ? "mdm-taskflows" : "cdi-taskflows", "summary");
  },
  openTaskflowLog: (runId: string, domain: "cdi" | "mdm" = "cdi"): void => {
    navigate({ screen: "taskflows", service: domain, runId });
    selectRibbonTab(domain === "mdm" ? "mdm-taskflows" : "cdi-taskflows", "log");
  },
  terminateTaskflow,
  getTaskflowHistory: (name: string, rowLimit = 100): Promise<TaskflowHistory> =>
    taskflowApi.history(name, rowLimit),
  getTaskflowRun: (runId: string): Promise<TaskflowRunStatus> => taskflowApi.status(runId),
  getTaskflowSessionLog: (runId: string, childTask?: string): Promise<string> =>
    taskflowApi.sessionLog(runId, childTask ?? null),
  openMdmMonitor: (): void => navigate(MDM_MONITOR_ROUTE),
  getMdmMonitor: (rowLimit = 25): Promise<MdmMonitorSnapshot> => mdmMonitorApi.get(rowLimit),
  listB360Entities: (scope: "focus" | "all" = "focus"): Promise<BusinessEntityList> => {
    navigate(B360_ROUTE);
    return b360Api.entities(scope);
  },
  getB360Metadata: (name: string): Promise<BusinessEntity> => b360Api.metadata(name),
  getB360Records: (name: string): Promise<RecordPage> => {
    navigate({ screen: "b360", service: "mdm", entity: name });
    return b360Api.records(name);
  },
  getB360SourceSystems: (): Promise<SourceSystemList> => b360Api.sourceSystems(),
  generateB360Rows: (name: string, count = 5): Promise<GeneratedRows> => b360Api.generate(name, count),
  openB360Record,
  lookupMdmJob: (instanceId: string): Promise<MdmJobInstance> => mdmMonitorApi.lookup(instanceId),
  getMonitor: (onlyMyTasks = true, rowLimit = 50): Promise<MonitorSnapshot> =>
    monitorApi.get(onlyMyTasks, rowLimit),
};

export type TxMdmAgentActions = typeof txmdm;

Object.assign(window, { txmdm });
