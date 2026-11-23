// App shell in the style of Microsoft OneNote:
//   left pane  = search box + notebooks (CDI, MDM) with coloured sections
//   top ribbon = contextual tabs for the selected section (e.g. Taskflows: Run / Track run id /
//                Summary / Session log) plus a one-line hint of what to do on that tab
//   page area  = the section's content; the ribbon tab sets data-view, CSS shows the parts.
// The URL still decides the section (deep links + agent bridge unchanged); every panel stays
// mounted so switching sections never drops a list already loaded.

import { useEffect, useMemo, useRef, useState } from "react";
import { getJson } from "./shared/api";
import { Input } from "@ui-sdk/react/input";
import { Listbox, ListboxItem } from "@ui-sdk/react/listbox";
import { Separator } from "@ui-sdk/react/separator";
import { Tabs, TabsList, TabsTab } from "@ui-sdk/react/tabs";
import { CdiPanel } from "./cdi/CdiPanel";
import { MonitorPanel } from "./cdi/MonitorPanel";
import { TaskflowsPanel } from "./cdi/TaskflowsPanel";
import { MdmPanel } from "./mdm/MdmPanel";
import { MdmMonitorPanel } from "./mdm/MdmMonitorPanel";
import { TASKFLOWS_ROUTE, useRoute, type MdmKindFilter, type Route } from "./shared/routes";
import type { CdiTask } from "./cdi/cdiApi";
import type { MdmJob } from "./mdm/mdmApi";
import { catalog } from "./shared/catalog";
import { HIT_ICON, Icon, SECTION_ICON } from "./shell/icons";
import { RunsPanel } from "./shell/RunsPanel";
import { HIT_LABEL, MAX_HITS, pickTaskflow, searchItems } from "./shell/search";
import {
  matchSections,
  NOTEBOOK_TITLE,
  RIBBON,
  SECTIONS,
  sectionOf,
  selectRibbonTab,
  useRibbonTab,
  type SectionId,
} from "./shell/sections";

const HINTS: Record<string, string> = {
  "cdi-tasks/tasks": "Pick a CDI task on the left of the page, then press Run.",
  "cdi-tasks/run": "The selected task, full width. Press Run to start it (one run at a time).",
  "cdi-taskflows/run": "Pick a taskflow, check its input fields (jobInstanceId), press Run. The run shows below.",
  "cdi-taskflows/track": "Paste an IDMC run id in Track a run id (below Run) and press Track.",
  "cdi-taskflows/summary": "Status, times and per child task rows ok / failed and errors.",
  "cdi-taskflows/log": "Press Session log on a child task to read its log.",
  "cdi-monitor/all": "Running now, recent history and runs started here. Refreshes every 15 s.",
  "cdi-monitor/running": "Only what is running in CDI right now.",
  "cdi-monitor/history": "Only finished runs from the activity log.",
  "cdi-monitor/app": "Only runs started from this app.",
  "cdi-runs/list": "Runs started from this backend. Pick one to see its result.",
  "cdi-runs/result": "Result of the selected run.",
  "mdm-running/all": "Every Business 360 job running in the org (any starter), recent finished, lookup. Refreshes every 15 s.",
  "mdm-running/running": "Only B360 jobs running right now, whoever started them.",
  "mdm-running/recent": "Only recently finished B360 jobs.",
  "mdm-running/lookup": "Paste any full job instance id and press Look up.",
  "mdm-runs/list": "Runs started from this backend. Pick one to see its result.",
  "mdm-runs/result": "Result of the selected run.",
};

function hintOf(section: SectionId, tab: string): string {
  return HINTS[`${section}/${tab}`] ?? "Pick a job definition, then press Run.";
}

export function App(): React.JSX.Element {
  const [route, go] = useRoute();
  const [search, setSearch] = useState<string>("");
  const [version, setVersion] = useState<string>("");
  useEffect(() => {
    getJson<{ version: string }>("/api/about")
      .then((about) => setVersion(about.version))
      .catch(() => setVersion(""));
  }, []);
  // Item search: the lists load from the shared catalog only once someone types.
  const [tasks, setTasks] = useState<readonly CdiTask[]>([]);
  const [jobs, setJobs] = useState<readonly MdmJob[]>([]);
  const [searchNote, setSearchNote] = useState<string>("");
  const searching = search.trim() !== "";
  useEffect(() => {
    if (!searching) return;
    const load = (): void => {
      setSearchNote("");
      catalog.tasks.read().then(setTasks, () => setSearchNote("CDI tasks did not load."));
      catalog.jobs.read().then(setJobs, () => setSearchNote("MDM jobs did not load."));
    };
    load();
    const stopTasks = catalog.tasks.onChange(load);
    const stopJobs = catalog.jobs.onChange(load);
    return () => {
      stopTasks();
      stopJobs();
    };
  }, [searching]);
  const hits = useMemo(() => searchItems(search, tasks, jobs), [search, tasks, jobs]);

  const lastKind = useRef<MdmKindFilter | null>(null);
  if (route.screen === "kind") lastKind.current = route.kind;
  if (route.screen === "jobs" && route.service === "mdm") lastKind.current = null;

  const section = sectionOf(route, lastKind.current);
  const tab = useRibbonTab(section);

  // A run result route opens the Result tab; the Runs list route opens the list.
  useEffect(() => {
    if (route.screen === "run") selectRibbonTab(section, "result");
    if (route.screen === "runs") selectRibbonTab(section, "list");
  }, [route, section]);

  const isCdiList = section === "cdi-tasks";
  const isMdmList = section === "mdm-all" || section === "mdm-ingress" || section === "mdm-egress";
  const cdiRoute: Route = route.service === "cdi" && (route.screen === "jobs" || route.screen === "job" || route.screen === "run") ? route : { screen: "jobs", service: "cdi" };
  const mdmRoute: Route = route.service === "mdm" && route.screen !== "runs" && route.screen !== "mdm-monitor" ? route : { screen: "jobs", service: "mdm" };
  const tfRoute: Route = route.screen === "taskflows" ? route : TASKFLOWS_ROUTE;
  const mdmKind: MdmKindFilter | null =
    section === "mdm-ingress" ? "Ingress" : section === "mdm-egress" ? "Egress" : null;
  const visibleSections = matchSections(search);
  const showCdi = isCdiList || (section === "cdi-runs" && tab === "result");
  const showMdm = isMdmList || (section === "mdm-runs" && tab === "result");

  return (
    <div className="onenote" data-section={section} data-view={tab}>
      <header className="titlebar">
        <h1>TX MDM Job Runner</h1>
        <span className="crumb" data-testid="crumb">
          {NOTEBOOK_TITLE[SECTIONS.find((s) => s.id === section)?.notebook ?? "CDI"]} -{" "}
          {SECTIONS.find((s) => s.id === section)?.label}
        </span>
        <span className="about-version" data-testid="about-version" title="Backend version (GET /api/about)">
          {version === "" ? "" : `v${version}`}
        </span>
      </header>

      <aside className="navpane" aria-label="Notebooks">
        <div className="search-box">
          <Icon name="search" />
          <Input
            aria-label="Search tasks, taskflows and jobs"
            data-testid="nav-search"
            placeholder="Search by name (e.g. guest, egress)"
            value={search}
            onValueChange={(value) => setSearch(value ?? "")}
          />
        </div>
        {searching && (
          <div className="notebook matches" data-testid="search-results">
            <h2>
              Matches <span className="count" data-testid="search-count">{hits.length}</span>
            </h2>
            {hits.length > 0 && (
              <Listbox
                aria-label="Search results"
                value={null}
                onValueChange={(value) => {
                  const hit = hits.find((h) => h.value === value);
                  if (hit === undefined) return;
                  go(hit.route);
                  if (hit.taskflowName !== null) pickTaskflow(hit.taskflowName);
                }}
              >
                {hits.slice(0, MAX_HITS).map((hit) => (
                  <ListboxItem
                    key={hit.value}
                    value={hit.value}
                    className={`hit-item k-${hit.kind}`}
                    data-testid={`search-hit-${hit.name}`}
                    data-kind={hit.kind}
                    title={`${HIT_LABEL[hit.kind]} - ${hit.where}`}
                  >
                    <Icon name={HIT_ICON[hit.kind]} />
                    <span className="hit-text">
                      <span className="item-name">{hit.name}</span>
                      <span className="hit-where">
                        {HIT_LABEL[hit.kind]} - {hit.where}
                      </span>
                    </span>
                  </ListboxItem>
                ))}
              </Listbox>
            )}
            {hits.length > MAX_HITS && (
              <p className="muted">{hits.length - MAX_HITS} more - type more of the name.</p>
            )}
            {hits.length === 0 && searchNote === "" && <p className="muted">No task, taskflow or job matches.</p>}
            {searchNote !== "" && <p className="warn-text">{searchNote}</p>}
            <Separator />
          </div>
        )}
        {(["CDI", "MDM"] as const).map((notebook) => {
          const items = visibleSections.filter((s) => s.notebook === notebook);
          if (items.length === 0) return null;
          return (
            <div className="notebook" key={notebook} data-testid={`notebook-${notebook}`}>
              <h2>{NOTEBOOK_TITLE[notebook]}</h2>
              <Listbox
                aria-label={`${NOTEBOOK_TITLE[notebook]} sections`}
                value={items.some((s) => s.id === section) ? section : null}
                onValueChange={(value) => {
                  const picked = SECTIONS.find((s) => s.id === value);
                  if (picked !== undefined) go(picked.route);
                }}
              >
                {items.map((s) => (
                  <ListboxItem
                    key={s.id}
                    value={s.id}
                    className={`nav-item c-${s.color}`}
                    data-testid={s.legacyTestId ?? `nav-${s.id}`}
                    data-nav={s.id}
                  >
                    <span className="swatch" aria-hidden="true" />
                    <Icon name={SECTION_ICON[s.id]} />
                    <span className="item-name">{s.label}</span>
                  </ListboxItem>
                ))}
              </Listbox>
            </div>
          );
        })}
      </aside>

      <div className="ribbon">
        <Tabs
          aria-label="Section tabs"
          data-testid="ribbon-tabs"
          value={tab}
          onValueChange={(value) => {
            if (typeof value === "string") selectRibbonTab(section, value);
          }}
        >
          <TabsList>
            {RIBBON[section].map((t) => (
              <TabsTab key={t.id} value={t.id} data-testid={`ribbon-tab-${t.id}`}>
                {t.label}
              </TabsTab>
            ))}
          </TabsList>
        </Tabs>
        <p className="ribbon-hint" data-testid="ribbon-hint">
          {hintOf(section, tab)}
        </p>
      </div>

      <main className="page">
        <div hidden={!showMdm}>
          <MdmPanel route={mdmRoute} go={go} kind={mdmKind} />
        </div>
        <div hidden={!showCdi}>
          <CdiPanel route={cdiRoute} go={go} />
        </div>
        <div hidden={section !== "cdi-monitor"}>
          <MonitorPanel active={section === "cdi-monitor"} />
        </div>
        <div hidden={section !== "mdm-running"}>
          <MdmMonitorPanel active={section === "mdm-running"} />
        </div>
        <div hidden={section !== "cdi-taskflows"}>
          <TaskflowsPanel route={tfRoute} go={go} active={section === "cdi-taskflows"} />
        </div>
        <div hidden={!(section === "cdi-runs" && tab === "list")}>
          <RunsPanel service="cdi" active={section === "cdi-runs" && tab === "list"} go={go} />
        </div>
        <div hidden={!(section === "mdm-runs" && tab === "list")}>
          <RunsPanel service="mdm" active={section === "mdm-runs" && tab === "list"} go={go} />
        </div>
      </main>
    </div>
  );
}
