import { describe, expect, it } from "vitest";
import { DEFAULT_ROUTE, formatRoute, parseRoute, type Route } from "./routes";

describe("routes", () => {
  const cases: [string, Route][] = [
    ["/mdm/jobs", { screen: "jobs", service: "mdm" }],
    ["/cdi/jobs", { screen: "jobs", service: "cdi" }],
    ["/mdm/jobs/A1", { screen: "job", service: "mdm", jobId: "A1" }],
    ["/cdi/runs/abc123", { screen: "run", service: "cdi", runKey: "abc123" }],
    ["/monitor", { screen: "monitor", service: "cdi" }],
    ["/cdi/runs", { screen: "runs", service: "cdi" }],
    ["/mdm/runs", { screen: "runs", service: "mdm" }],
    ["/mdm/ingress", { screen: "kind", service: "mdm", kind: "Ingress" }],
    ["/mdm/egress", { screen: "kind", service: "mdm", kind: "Egress" }],
    ["/taskflows", { screen: "taskflows", service: "cdi", runId: null }],
    ["/taskflows/runs/1309380263289049088", { screen: "taskflows", service: "cdi", runId: "1309380263289049088" }],
  ];

  it.each(cases)("parses and formats %s both ways", (path, route) => {
    expect(parseRoute(path)).toEqual(route);
    expect(formatRoute(route)).toBe(path);
  });

  it("encodes ids with slashes or spaces", () => {
    const route: Route = { screen: "job", service: "mdm", jobId: "a b/c" };
    expect(parseRoute(formatRoute(route))).toEqual(route);
  });

  it("falls back to the MDM job list for unknown paths", () => {
    expect(parseRoute("/")).toEqual(DEFAULT_ROUTE);
    expect(parseRoute("/nope/x")).toEqual(DEFAULT_ROUTE);
  });
});
