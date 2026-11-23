// One shared copy of the two metadata lists (CDI tasks, MDM jobs) for the whole page.
// The CDI panel, the Taskflows panel and the left-pane search all read the same list, so
// opening the app costs one call per list instead of one per panel. A Refresh button asks
// for a fresh copy; a failed load is forgotten so the next read tries again.

import { cdiApi, type CdiTask } from "../cdi/cdiApi";
import { mdmApi, type MdmJob } from "../mdm/mdmApi";

type Listener = () => void;

function cached<T>(load: () => Promise<T[]>): { read: (fresh?: boolean) => Promise<T[]>; onChange: (l: Listener) => () => void } {
  let current: Promise<T[]> | null = null;
  const listeners = new Set<Listener>();
  return {
    read: (fresh = false) => {
      if (fresh || current === null) {
        const next = load();
        current = next;
        next.then(
          () => listeners.forEach((l) => l()),
          () => {
            if (current === next) current = null;
          },
        );
      }
      return current;
    },
    onChange: (listener) => {
      listeners.add(listener);
      return () => {
        listeners.delete(listener);
      };
    },
  };
}

export const catalog = {
  tasks: cached<CdiTask>(cdiApi.listTasks),
  jobs: cached<MdmJob>(mdmApi.listJobs),
};
