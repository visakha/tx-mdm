// OneNote-style shell model: the left pane lists notebooks (CDI, MDM) and their sections; the
// top ribbon shows contextual tabs for the selected section. Pure functions, tested.
//
// The section comes from the URL (so deep links and the agent bridge keep working). The
// ribbon tab is per section and lives in a tiny store so UI and agent see the same value.

import { useSyncExternalStore } from "react";
import type { MdmKindFilter, Route } from "../shared/routes";

export type SectionId =
  | "cdi-tasks"
  | "cdi-taskflows"
  | "cdi-monitor"
  | "cdi-runs"
  | "mdm-all"
  | "mdm-ingress"
  | "mdm-egress"
  | "mdm-taskflows"
  | "mdm-running"
  | "mdm-runs"
  | "b360-data";

export interface Section {
  id: SectionId;
  notebook: "CDI" | "MDM" | "B360";
  label: string;
  /** Where the left-pane item navigates to. */
  route: Route;
  /** Older top-tab test ids kept on the matching left-pane items. */
  legacyTestId: string | null;
  /** OneNote-like section colour (CSS variable suffix). */
  color: "purple" | "blue" | "green" | "orange" | "teal" | "red" | "gold" | "gray";
}

export const SECTIONS: readonly Section[] = [
  { id: "cdi-tasks", notebook: "CDI", label: "Tasks", route: { screen: "jobs", service: "cdi" }, legacyTestId: "tab-cdi", color: "blue" },
  { id: "cdi-taskflows", notebook: "CDI", label: "Taskflows", route: { screen: "taskflows", service: "cdi", runId: null }, legacyTestId: "tab-taskflows", color: "purple" },
  { id: "cdi-monitor", notebook: "CDI", label: "Monitor", route: { screen: "monitor", service: "cdi" }, legacyTestId: "tab-monitor", color: "green" },
  { id: "cdi-runs", notebook: "CDI", label: "Runs", route: { screen: "runs", service: "cdi" }, legacyTestId: null, color: "gray" },
  { id: "mdm-all", notebook: "MDM", label: "All jobs", route: { screen: "jobs", service: "mdm" }, legacyTestId: "tab-mdm", color: "teal" },
  { id: "mdm-ingress", notebook: "MDM", label: "Ingress jobs", route: { screen: "kind", service: "mdm", kind: "Ingress" }, legacyTestId: null, color: "orange" },
  { id: "mdm-egress", notebook: "MDM", label: "Egress jobs", route: { screen: "kind", service: "mdm", kind: "Egress" }, legacyTestId: null, color: "red" },
  { id: "mdm-taskflows", notebook: "MDM", label: "Taskflows (jobInstanceId)", route: { screen: "taskflows", service: "mdm", runId: null }, legacyTestId: null, color: "purple" },
  { id: "mdm-running", notebook: "MDM", label: "Currently running", route: { screen: "mdm-monitor", service: "mdm" }, legacyTestId: null, color: "green" },
  { id: "mdm-runs", notebook: "MDM", label: "Runs", route: { screen: "runs", service: "mdm" }, legacyTestId: null, color: "gray" },
  { id: "b360-data", notebook: "B360", label: "All business entities", route: { screen: "b360", service: "mdm", entity: null }, legacyTestId: null, color: "purple" },
];

export const NOTEBOOK_TITLE: Record<Section["notebook"], string> = {
  CDI: "Data Integration (CDI)",
  MDM: "Business 360 (MDM)",
  B360: "B360 Data",
};

/** Which left-pane section a route belongs to. lastMdmKind keeps Ingress/Egress lit on a job page. */
export function sectionOf(route: Route, lastMdmKind: MdmKindFilter | null): SectionId {
  switch (route.screen) {
    case "monitor":
      return "cdi-monitor";
    case "mdm-monitor":
      return "mdm-running";
    case "b360":
      return "b360-data";
    case "taskflows":
      return route.service === "mdm" ? "mdm-taskflows" : "cdi-taskflows";
    case "runs":
    case "run":
      return route.service === "cdi" ? "cdi-runs" : "mdm-runs";
    case "kind":
      return route.kind === "Ingress" ? "mdm-ingress" : "mdm-egress";
    case "jobs":
      return route.service === "cdi" ? "cdi-tasks" : "mdm-all";
    case "job":
      if (route.service === "cdi") return "cdi-tasks";
      if (lastMdmKind === "Ingress") return "mdm-ingress";
      if (lastMdmKind === "Egress") return "mdm-egress";
      return "mdm-all";
  }
}

export interface RibbonTab {
  id: string;
  label: string;
}

/** Contextual ribbon tabs per section (first = default). */
export const RIBBON: Record<SectionId, readonly RibbonTab[]> = {
  "cdi-tasks": [
    { id: "tasks", label: "Tasks" },
    { id: "run", label: "Run" },
  ],
  "cdi-taskflows": [
    { id: "run", label: "Run" },
    { id: "summary", label: "Summary" },
    { id: "log", label: "Session log" },
  ],
  "cdi-monitor": [
    { id: "all", label: "Everything" },
    { id: "running", label: "Running now" },
    { id: "history", label: "History" },
    { id: "app", label: "Started here" },
  ],
  "cdi-runs": [
    { id: "list", label: "Runs" },
    { id: "result", label: "Result" },
  ],
  "mdm-all": [
    { id: "jobs", label: "Jobs" },
    { id: "run", label: "Run" },
  ],
  "mdm-ingress": [
    { id: "jobs", label: "Jobs" },
    { id: "run", label: "Run" },
  ],
  "mdm-egress": [
    { id: "jobs", label: "Jobs" },
    { id: "run", label: "Run" },
  ],
  "mdm-taskflows": [
    { id: "run", label: "Run" },
    { id: "summary", label: "Summary" },
    { id: "log", label: "Session log" },
  ],
  "mdm-running": [
    { id: "all", label: "Everything" },
    { id: "running", label: "Running now" },
    { id: "recent", label: "Recently finished" },
    { id: "lookup", label: "Look up id" },
  ],
  "mdm-runs": [
    { id: "list", label: "Runs" },
    { id: "result", label: "Result" },
  ],
  "b360-data": [
    // 0.9.10: (M) = master / golden records, (S) = source (xref) records. Adds are always source.
    // 0.9.12.3 (Vamsi 02:45 CST): ONE Metadata tab with a Master | Source sub-tab strip below it.
    { id: "records", label: "Records (M)" },
    { id: "sources", label: "Records (S)" },
    { id: "metadata", label: "Metadata" },
    { id: "add", label: "Add records (S)" },
    { id: "edit", label: "Edit records (S)" },
    // 0.9.12: merge master records, per-field winners applied on the survivor.
    { id: "merge", label: "Merge (M)" },
  ],
};

/** Left-pane search: sections whose label or notebook matches the text. */
export function matchSections(text: string): readonly Section[] {
  const needle = text.trim().toLowerCase();
  if (needle === "") return SECTIONS;
  return SECTIONS.filter((s) => `${s.label} ${NOTEBOOK_TITLE[s.notebook]}`.toLowerCase().includes(needle));
}

// ---- ribbon tab store (one selected tab per section) ----

type Listener = () => void;
const listeners = new Set<Listener>();
let selected: Partial<Record<SectionId, string>> = {};

export function ribbonTab(section: SectionId): string {
  return selected[section] ?? RIBBON[section][0]?.id ?? "";
}

// ---- second-level tabs (0.9.12.3: Metadata -> Master | Source) ----

export type SubTabId = "master" | "source";

export interface SubTab {
  readonly id: SubTabId;
  readonly label: string;
}

/** Tabs that carry a second-level strip directly beneath them. First entry is the default. */
export const SUB_TABS: Partial<Record<SectionId, Readonly<Record<string, readonly SubTab[]>>>> = {
  "b360-data": {
    metadata: [
      { id: "master", label: "Master" },
      { id: "source", label: "Source" },
    ],
  },
};

/** Old tab ids that now live under a parent tab + sub-tab. Kept so old links / agent calls work. */
interface TabAlias {
  readonly tab: string;
  readonly sub: SubTabId;
}

const TAB_ALIASES: Partial<Record<SectionId, Readonly<Record<string, TabAlias>>>> = {
  "b360-data": {
    "source-metadata": { tab: "metadata", sub: "source" },
    "metadata-master": { tab: "metadata", sub: "master" },
    "metadata-source": { tab: "metadata", sub: "source" },
  },
};

let selectedSub: Partial<Record<SectionId, SubTabId>> = {};

export function subTabs(section: SectionId, tab: string): readonly SubTab[] {
  return SUB_TABS[section]?.[tab] ?? [];
}

export function subTab(section: SectionId): SubTabId {
  return selectedSub[section] ?? subTabs(section, ribbonTab(section))[0]?.id ?? "master";
}

export function selectSubTab(section: SectionId, sub: SubTabId): void {
  if (!subTabs(section, ribbonTab(section)).some((t) => t.id === sub)) {
    throw new Error(`Tab ${ribbonTab(section)} in ${section} has no sub-tab ${sub}`);
  }
  selectedSub = { ...selectedSub, [section]: sub };
  for (const listener of listeners) listener();
}

export function useSubTab(section: SectionId): SubTabId {
  return useSyncExternalStore(subscribe, () => subTab(section));
}

/** Select a ribbon tab. Unknown tab ids are rejected so the agent gets a clear error. Old ids
 * (Metadata (M) / (S) = "metadata" / "source-metadata") redirect to Metadata + its sub-tab. */
export function selectRibbonTab(section: SectionId, tab: string): void {
  const alias = TAB_ALIASES[section]?.[tab];
  if (alias !== undefined) {
    selected = { ...selected, [section]: alias.tab };
    selectedSub = { ...selectedSub, [section]: alias.sub };
    for (const listener of listeners) listener();
    return;
  }
  const subs = subTabs(section, tab);
  if (subs.length > 0 && subs[0] !== undefined) selectedSub = { ...selectedSub, [section]: subs[0].id };
  if (!RIBBON[section].some((t) => t.id === tab)) {
    const known = RIBBON[section].map((t) => t.id).join(", ");
    throw new Error(`No ribbon tab ${tab} in ${section}. Tabs: ${known}`);
  }
  selected = { ...selected, [section]: tab };
  for (const listener of listeners) listener();
}

function subscribe(listener: Listener): () => void {
  listeners.add(listener);
  return () => listeners.delete(listener);
}

export function useRibbonTab(section: SectionId): string {
  return useSyncExternalStore(subscribe, () => ribbonTab(section));
}
