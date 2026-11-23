// Small inline SVG icons (ASCII-only source, no emoji, no icon font): they inherit the text
// colour via currentColor and are aria-hidden, so the accessible name stays the text label.

import type { HitKind } from "./search";
import type { SectionId } from "./sections";

type IconName = "task" | "taskflow" | "monitor" | "runs" | "jobs" | "ingress" | "egress" | "search" | "entity";

const PATHS: Record<IconName, React.JSX.Element> = {
  // gear-like square: a single mapping task
  task: <><rect x="3" y="3" width="10" height="10" rx="2" /><path d="M6 8h4M8 6v4" /></>,
  // three linked steps: a taskflow
  taskflow: <><circle cx="3.5" cy="8" r="2" /><circle cx="12.5" cy="4" r="2" /><circle cx="12.5" cy="12" r="2" /><path d="M5.5 8 10.5 4.5M5.5 8l5 3.5" /></>,
  // pulse line: monitor
  monitor: <path d="M1.5 8.5h3l2-5 3 9 2-4h3" />,
  // list with tick: runs started here
  runs: <><path d="M6 4h8M6 8h8M6 12h8" /><path d="M2 4h1M2 8h1M2 12h1" /></>,
  // stacked disks: MDM jobs
  jobs: <><ellipse cx="8" cy="4" rx="5" ry="2" /><path d="M3 4v8c0 1.1 2.2 2 5 2s5-.9 5-2V4M3 8c0 1.1 2.2 2 5 2s5-.9 5-2" /></>,
  // arrow into a box: ingress
  ingress: <><path d="M9 3h4v10H9" /><path d="M2 8h8M7 5l3 3-3 3" /></>,
  // arrow out of a box: egress
  egress: <><path d="M7 3H3v10h4" /><path d="M6 8h8M11 5l3 3-3 3" /></>,
  // table grid: B360 business entity data
  entity: <><rect x="2" y="3" width="12" height="10" rx="1.5" /><path d="M2 6.5h12M6 6.5V13" /></>,
  search: <><circle cx="7" cy="7" r="4.5" /><path d="m10.5 10.5 3.5 3.5" /></>,
};

export function Icon({ name }: { name: IconName }): React.JSX.Element {
  return (
    <svg className="icon" viewBox="0 0 16 16" width="16" height="16" fill="none" stroke="currentColor"
      strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true" focusable="false">
      {PATHS[name]}
    </svg>
  );
}

export const SECTION_ICON: Record<SectionId, IconName> = {
  "cdi-tasks": "task",
  "cdi-taskflows": "taskflow",
  "cdi-monitor": "monitor",
  "cdi-runs": "runs",
  "mdm-all": "jobs",
  "mdm-ingress": "ingress",
  "mdm-egress": "egress",
  "mdm-taskflows": "taskflow",
  "mdm-running": "monitor",
  "mdm-runs": "runs",
  "b360-data": "entity",
};

export const HIT_ICON: Record<HitKind, IconName> = {
  task: "task",
  "mdm-mapping-task": "task",
  taskflow: "taskflow",
  "mdm-taskflow": "taskflow",
  ingress: "ingress",
  egress: "egress",
  "mdm-job": "jobs",
};
