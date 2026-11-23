// App shell in the style of Microsoft OneNote:
//   left pane  = search box + notebooks (CDI, MDM) with coloured sections
//   top ribbon = contextual tabs for the selected section (e.g. Taskflows: Run / Track run id /
//                Summary / Session log) plus a one-line hint of what to do on that tab
//   page area  = the section's content; the ribbon tab sets data-view, CSS shows the parts.
// The URL still decides the section (deep links + agent bridge unchanged); every panel stays
// mounted so switching sections never drops a list already loaded.

import { useEffect, useRef, useState } from "react";
import { getJson } from "./shared/api";
import { Input } from "@ui-sdk/react/input";
import { Listbox, ListboxItem } from "@ui-sdk/react/listbox";
import { Tabs, TabsList, TabsTab } from "@ui-sdk/react/tabs";
import { CdiPanel } from "./cdi/CdiPanel";
import { MonitorPanel } from "./cdi/MonitorPanel";
import { TaskflowsPanel } from "./cdi/TaskflowsPanel";
import { MdmPanel } from "./mdm/MdmPanel";
import { TASKFLOWS_ROUTE, useRoute, type MdmKindFilter, type Route } from "./shared/routes";
import { RunsPanel } from "./shell/RunsPanel";
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
  "cdi-taskflows/run": "Pick a taskflow, check its input fields (jobInstanceId), press Run. The run is tracked on the right.",
  "cdi-taskflows/track": "Paste an IDMC run id and press Track to follow a run started anywhere.",
  "cdi-taskflows/summary": "Status, times and per child task rows ok / failed and errors.",
  "cdi-taskflows/log": "Press Session log on a child task to read its log.",
  "cdi-monitor/all": "Running now, recent history and runs started here. Refreshes every 15 s.",
  "cdi-monitor/running": "Only what is running in CDI right now.",
  "cdi-monitor/history": "Only finished runs from the activity log.",
  "cdi-monitor/app": "Only runs started from this app.",
  "cdi-runs/list": "Runs started from this backend. Pick one to see its result.",
  "cdi-runs/result": "Result of the selected run.",
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
  const mdmRoute: Route = route.service === "mdm" && route.screen !== "runs" ? route : { screen: "jobs", service: "mdm" };
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
        <Input
          aria-label="Search sections"
          data-testid="nav-search"
          placeholder="Search (e.g. taskflow, egress)"
          value={search}
          onValueChange={(value) => setSearch(value ?? "")}
        />
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
                    <span className="item-name">{s.label}</span>
                  </ListboxItem>
                ))}
              </Listbox>
            </div>
          );
        })}
        {visibleSections.length === 0 && <p className="muted">No section matches.</p>}
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
