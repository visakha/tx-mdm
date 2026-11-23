// Left-pane search over the ITEMS (CDI tasks, taskflows, MDM jobs), not only the section names.
// Pure and tested: the App feeds it the shared catalog lists and the typed text.

import type { CdiTask } from "../cdi/cdiApi";
import type { MdmJob } from "../mdm/mdmApi";
import type { Route } from "../shared/routes";

export type HitKind = "task" | "mdm-mapping-task" | "taskflow" | "mdm-taskflow" | "ingress" | "egress" | "mdm-job";

export interface SearchHit {
  /** Unique listbox value, e.g. "task:4H16HBEOd4ekHq2fXGZ9kI". */
  value: string;
  kind: HitKind;
  name: string;
  /** Folder path without the name, for the second line. */
  where: string;
  /** Where a press goes. Taskflows open the Taskflows section with this name picked. */
  route: Route;
  taskflowName: string | null;
}

export const MAX_HITS = 25;

function folderOf(path: string, name: string): string {
  return path.endsWith(name) ? path.slice(0, Math.max(0, path.length - name.length - 1)) : path;
}

function mdmKind(job: MdmJob): HitKind {
  if (job.kind === "Ingress") return "ingress";
  if (job.kind === "Egress") return "egress";
  return "mdm-job";
}

/** Every item whose name (or folder) contains all the typed words, any case. Names first. */
export function searchItems(text: string, tasks: readonly CdiTask[], jobs: readonly MdmJob[]): SearchHit[] {
  const words = text.trim().toLowerCase().split(/\s+/).filter((w) => w !== "");
  if (words.length === 0) return [];
  const hits: SearchHit[] = [
    ...tasks.map((t): SearchHit =>
      t.type === "TASKFLOW"
        ? { value: `taskflow:${t.id}`, kind: t.domain === "mdm" ? "mdm-taskflow" : "taskflow", name: t.name, where: folderOf(t.path, t.name), route: { screen: "taskflows", service: t.domain === "mdm" ? "mdm" : "cdi", runId: null }, taskflowName: t.name }
        : t.domain === "mdm"
          ? // 0.9.6: Business 360 child mapping task - opens the B360 Taskflows section (read only).
            { value: `task:${t.id}`, kind: "mdm-mapping-task", name: t.name, where: folderOf(t.path, t.name), route: { screen: "taskflows", service: "mdm", runId: null }, taskflowName: null }
          : { value: `task:${t.id}`, kind: "task", name: t.name, where: folderOf(t.path, t.name), route: { screen: "job", service: "cdi", jobId: t.id }, taskflowName: null },
    ),
    ...jobs.map((j): SearchHit => ({ value: `job:${j.asset_id}`, kind: mdmKind(j), name: j.name, where: folderOf(j.path, j.name), route: { screen: "job", service: "mdm", jobId: j.asset_id }, taskflowName: null })),
  ];
  const matches = (h: SearchHit): boolean => words.every((w) => `${h.name} ${h.where}`.toLowerCase().includes(w));
  const inName = (h: SearchHit): boolean => words.every((w) => h.name.toLowerCase().includes(w));
  return hits
    .filter(matches)
    .sort((a, b) => Number(inName(b)) - Number(inName(a)) || a.name.localeCompare(b.name));
}

export const HIT_LABEL: Record<HitKind, string> = {
  task: "CDI task",
  "mdm-mapping-task": "MDM mapping task (runs via its taskflow)",
  taskflow: "CDI taskflow",
  "mdm-taskflow": "MDM taskflow",
  ingress: "MDM ingress",
  egress: "MDM egress",
  "mdm-job": "MDM job",
};

// ---- "open this taskflow" hand-off from the search to the Taskflows panel ----

const PICK_EVENT = "txmdm:pick-taskflow";

interface PickDetail {
  name: string;
  domain: "cdi" | "mdm";
}

/** domain picks which Taskflows panel takes it: CDI notebook or Business 360 notebook (0.9.4). */
export function pickTaskflow(name: string, domain: "cdi" | "mdm" = "cdi"): void {
  window.dispatchEvent(new CustomEvent<PickDetail>(PICK_EVENT, { detail: { name, domain } }));
}

export function onPickTaskflow(handler: (name: string, domain: "cdi" | "mdm") => void): () => void {
  const listener = (event: Event): void => {
    if (!(event instanceof CustomEvent)) return;
    const detail: unknown = event.detail;
    if (typeof detail === "object" && detail !== null && "name" in detail && "domain" in detail) {
      const { name, domain } = detail as PickDetail;
      handler(name, domain);
    }
  };
  window.addEventListener(PICK_EVENT, listener);
  return () => window.removeEventListener(PICK_EVENT, listener);
}
