// Stable, deep-linkable routes. One typed Route per screen; parse/format are pure and tested.
//
//   /                       -> /mdm/jobs
//   /mdm/jobs               MDM job list
//   /mdm/jobs/:assetId      one MDM job definition (with its Run button)
//   /mdm/runs/:runKey       results screen for one MDM run
//   /cdi/jobs               CDI task list
//   /cdi/jobs/:taskId       one CDI task (with its Run button)
//   /cdi/runs/:runKey       results screen for one CDI run
//   /cdi/runs, /mdm/runs    runs started from this backend (left pane "Runs")
//   /mdm/ingress, /mdm/egress  MDM job list filtered to one kind (left pane)
//   /monitor                CDI Monitor tab (running jobs + recent history)
//   /taskflows              CDI Taskflows (tf_Ldg_*, tf_Stg_*, ...): run by name + history
//   /taskflows/runs/:runId  one CDI taskflow run by its IDMC run id
//   /mdm/taskflows          Business 360 taskflows (tf_MDM_*, *_EGR, *_IGR; need jobInstanceId)
//   /mdm/taskflows/runs/:runId  one B360 taskflow run
//   /mdm/running            Business 360 Currently running (any starter) + lookup by id
//   /b360, /b360/:entity    B360 Data notebook: business entities, first 10 records of one
//   /design                 Design notebook (0.9.15): CDI asset types -> assets -> metadata

import { useCallback, useEffect, useState } from "react";
import { SLASH, tokens } from "./text";

export type Service = "mdm" | "cdi";

export type MdmKindFilter = "Ingress" | "Egress";

export type Route =
  | { screen: "jobs"; service: Service }
  | { screen: "job"; service: Service; jobId: string }
  | { screen: "run"; service: Service; runKey: string }
  | { screen: "runs"; service: Service }
  | { screen: "kind"; service: "mdm"; kind: MdmKindFilter }
  // The Monitor tab watches CDI jobs, so it carries service "cdi".
  | { screen: "monitor"; service: "cdi" }
  // Taskflows tab: runId is the IDMC run id (null = nothing tracked yet).
  // service tells which notebook: cdi taskflows or Business 360 (MDM) taskflows (0.9.4).
  | { screen: "taskflows"; service: Service; runId: string | null }
  // Business 360 Currently running: every b360.* / c360.* job in the org.
  | { screen: "mdm-monitor"; service: "mdm" }
  // B360 Data notebook (0.9.5): entity = business entity internal id (null = none picked).
  | { screen: "b360"; service: "mdm"; entity: string | null }
  // Design notebook (0.9.15): read-only CDI asset metadata. Type = ribbon tab, asset = page state.
  | { screen: "design"; service: "cdi" };

export const MONITOR_ROUTE: Route = { screen: "monitor", service: "cdi" };

export const TASKFLOWS_ROUTE: Route = { screen: "taskflows", service: "cdi", runId: null };

export const MDM_TASKFLOWS_ROUTE: Route = { screen: "taskflows", service: "mdm", runId: null };

export const MDM_MONITOR_ROUTE: Route = { screen: "mdm-monitor", service: "mdm" };

export const B360_ROUTE: Route = { screen: "b360", service: "mdm", entity: null };

export const DESIGN_ROUTE: Route = { screen: "design", service: "cdi" };

export const DEFAULT_ROUTE: Route = { screen: "jobs", service: "mdm" };

export function parseRoute(pathname: string): Route {
  // URL path segments (browser boundary), read with the shared character-set helper.
  const parts = tokens(pathname, SLASH).map(decodeURIComponent);
  const [service, kind, id] = parts;
  if (service === "monitor" && kind === undefined) return MONITOR_ROUTE;
  if (service === "taskflows" && kind === undefined) return TASKFLOWS_ROUTE;
  if (service === "design" && kind === undefined) return DESIGN_ROUTE;
  if (service === "taskflows" && kind === "runs" && id !== undefined) {
    return { screen: "taskflows", service: "cdi", runId: id };
  }
  if (service === "mdm" && kind === "running" && id === undefined) return MDM_MONITOR_ROUTE;
  if (service === "mdm" && kind === "taskflows" && id === undefined) return MDM_TASKFLOWS_ROUTE;
  if (service === "mdm" && kind === "taskflows" && id === "runs" && parts[3] !== undefined) {
    return { screen: "taskflows", service: "mdm", runId: parts[3] };
  }
  if (service === "b360" && id === undefined) {
    return kind === undefined ? B360_ROUTE : { screen: "b360", service: "mdm", entity: kind };
  }
  if (service === "mdm" && kind === "ingress" && id === undefined) {
    return { screen: "kind", service: "mdm", kind: "Ingress" };
  }
  if (service === "mdm" && kind === "egress" && id === undefined) {
    return { screen: "kind", service: "mdm", kind: "Egress" };
  }
  if (service !== "mdm" && service !== "cdi") return DEFAULT_ROUTE;
  if (kind === "runs" && id === undefined) return { screen: "runs", service };
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
    case "runs":
      return `/${route.service}/runs`;
    case "kind":
      return `/mdm/${route.kind.toLowerCase()}`;
    case "monitor":
      return "/monitor";
    case "mdm-monitor":
      return "/mdm/running";
    case "design":
      return "/design";
    case "b360":
      return route.entity === null ? "/b360" : `/b360/${encodeURIComponent(route.entity)}`;
    case "taskflows":
    {
      const base = route.service === "mdm" ? "/mdm/taskflows" : "/taskflows";
      return route.runId === null ? base : `${base}/runs/${encodeURIComponent(route.runId)}`;
    }
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
