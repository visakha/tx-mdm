// Stable, deep-linkable routes. One typed Route per screen; parse/format are pure and tested.
//
//   /                       -> /mdm/jobs
//   /mdm/jobs               MDM job list
//   /mdm/jobs/:assetId      one MDM job definition (with its Run button)
//   /mdm/runs/:runKey       results screen for one MDM run
//   /cdi/jobs               CDI task list
//   /cdi/jobs/:taskId       one CDI task (with its Run button)
//   /cdi/runs/:runKey       results screen for one CDI run
//   /monitor                CDI Monitor tab (running jobs + recent history)
//   /taskflows              Taskflows tab: run a taskflow by name, or paste a run id
//   /taskflows/runs/:runId  track one taskflow run by its IDMC run id

import { useCallback, useEffect, useState } from "react";

export type Service = "mdm" | "cdi";

export type Route =
  | { screen: "jobs"; service: Service }
  | { screen: "job"; service: Service; jobId: string }
  | { screen: "run"; service: Service; runKey: string }
  // The Monitor tab watches CDI jobs, so it carries service "cdi".
  | { screen: "monitor"; service: "cdi" }
  // Taskflows tab: runId is the IDMC run id (null = nothing tracked yet).
  | { screen: "taskflows"; service: "cdi"; runId: string | null };

export const MONITOR_ROUTE: Route = { screen: "monitor", service: "cdi" };

export const TASKFLOWS_ROUTE: Route = { screen: "taskflows", service: "cdi", runId: null };

export const DEFAULT_ROUTE: Route = { screen: "jobs", service: "mdm" };

export function parseRoute(pathname: string): Route {
  const parts = pathname.split("/").filter((p) => p !== "").map(decodeURIComponent);
  const [service, kind, id] = parts;
  if (service === "monitor" && kind === undefined) return MONITOR_ROUTE;
  if (service === "taskflows" && kind === undefined) return TASKFLOWS_ROUTE;
  if (service === "taskflows" && kind === "runs" && id !== undefined) {
    return { screen: "taskflows", service: "cdi", runId: id };
  }
  if (service !== "mdm" && service !== "cdi") return DEFAULT_ROUTE;
  if (kind === "jobs" && id === undefined) return { screen: "jobs", service };
  if (kind === "jobs" && id !== undefined) return { screen: "job", service, jobId: id };
  if (kind === "runs" && id !== undefined) return { screen: "run", service, runKey: id };
  return { screen: "jobs", service };
}

export function formatRoute(route: Route): string {
  switch (route.screen) {
    case "jobs":
      return `/${route.service}/jobs`;
    case "job":
      return `/${route.service}/jobs/${encodeURIComponent(route.jobId)}`;
    case "run":
      return `/${route.service}/runs/${encodeURIComponent(route.runKey)}`;
    case "monitor":
      return "/monitor";
    case "taskflows":
      return route.runId === null ? "/taskflows" : `/taskflows/runs/${encodeURIComponent(route.runId)}`;
  }
}

const ROUTE_EVENT = "txmdm:route";

/** Navigate without a page reload. Used by the UI and by the agent actions. */
export function navigate(route: Route): void {
  const path = formatRoute(route);
  if (window.location.pathname !== path) {
    window.history.pushState(null, "", path);
  }
  window.dispatchEvent(new Event(ROUTE_EVENT));
}

export function currentRoute(): Route {
  return parseRoute(window.location.pathname);
}

export function useRoute(): [Route, (route: Route) => void] {
  const [route, setRoute] = useState<Route>(currentRoute);

  useEffect(() => {
    const sync = (): void => setRoute(currentRoute());
    window.addEventListener("popstate", sync);
    window.addEventListener(ROUTE_EVENT, sync);
    if (window.location.pathname === "/") {
      window.history.replaceState(null, "", formatRoute(DEFAULT_ROUTE));
    }
    return () => {
      window.removeEventListener("popstate", sync);
      window.removeEventListener(ROUTE_EVENT, sync);
    };
  }, []);

  const go = useCallback((next: Route) => navigate(next), []);
  return [route, go];
}
