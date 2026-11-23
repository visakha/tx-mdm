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
  | "mdm-running"
  | "mdm-runs";

export interface Section {
  id: SectionId;
  notebook: "CDI" | "MDM";
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
  { id: "mdm-running", notebook: "MDM", label: "Currently running", route: { screen: "mdm-monitor", service: "mdm" }, legacyTestId: null, color: "green" },
  { id: "mdm-runs", notebook: "MDM", label: "Runs", route: { screen: "runs", service: "mdm" }, legacyTestId: null, color: "gray" },
];

export const NOTEBOOK_TITLE: Record<Section["notebook"], string> = {
  CDI: "Data Integration (CDI)",
  MDM: "Business 360 (MDM)",
};

/** Which left-pane section a route belongs to. lastMdmKind keeps Ingress/Egress lit on a job page. */
export function sectionOf(route: Route, lastMdmKind: MdmKindFilter | null): SectionId {
  switch (route.screen) {
    case "monitor":
      return "cdi-monitor";
    case "mdm-monitor":
      return "mdm-running";
    case "taskflows":
      return "cdi-taskflows";
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
    { id: "track", label: "Track run id" },
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

/** Select a ribbon tab. Unknown tab ids are rejected so the agent gets a clear error. */
export function selectRibbonTab(section: SectionId, tab: string): void {
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
