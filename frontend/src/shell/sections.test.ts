import { describe, expect, it } from "vitest";
import { matchSections, ribbonTab, sectionOf, selectRibbonTab, selectSubTab, subTab } from "./sections";

describe("OneNote shell model", () => {
  it("maps every route to its left-pane section", () => {
    expect(sectionOf({ screen: "monitor", service: "cdi" }, null)).toBe("cdi-monitor");
    expect(sectionOf({ screen: "taskflows", service: "cdi", runId: "1" }, null)).toBe("cdi-taskflows");
    expect(sectionOf({ screen: "taskflows", service: "mdm", runId: null }, null)).toBe("mdm-taskflows");
    expect(sectionOf({ screen: "run", service: "mdm", runKey: "k" }, null)).toBe("mdm-runs");
    expect(sectionOf({ screen: "kind", service: "mdm", kind: "Egress" }, null)).toBe("mdm-egress");
    expect(sectionOf({ screen: "job", service: "mdm", jobId: "a" }, "Ingress")).toBe("mdm-ingress");
    expect(sectionOf({ screen: "job", service: "cdi", jobId: "a" }, "Ingress")).toBe("cdi-tasks");
  });

  it("search filters sections by label or notebook", () => {
    expect(matchSections("egress").map((s) => s.id)).toEqual(["mdm-egress"]);
    expect(matchSections("cdi").length).toBe(4);
    expect(matchSections("").length).toBe(11);
    expect(matchSections("b360 data").map((s) => s.id)).toEqual(["b360-data"]);
    expect(sectionOf({ screen: "b360", service: "mdm", entity: "c360.person" }, null)).toBe("b360-data");
    expect(sectionOf({ screen: "mdm-monitor", service: "mdm" }, null)).toBe("mdm-running");
  });

  it("ribbon tab defaults to the first and rejects unknown tabs", () => {
    expect(ribbonTab("cdi-taskflows")).toBe("run");
    selectRibbonTab("cdi-taskflows", "summary");
    expect(ribbonTab("cdi-taskflows")).toBe("summary");
    expect(() => selectRibbonTab("cdi-taskflows", "nope")).toThrow(/Tabs: run, summary, log/);
  });

  it("0.9.12.3: one Metadata tab with Master | Source; old ids redirect", () => {
    selectRibbonTab("b360-data", "metadata");
    expect(ribbonTab("b360-data")).toBe("metadata");
    expect(subTab("b360-data")).toBe("master");
    selectSubTab("b360-data", "source");
    expect(subTab("b360-data")).toBe("source");
    selectRibbonTab("b360-data", "records");
    selectRibbonTab("b360-data", "source-metadata");
    expect(ribbonTab("b360-data")).toBe("metadata");
    expect(subTab("b360-data")).toBe("source");
    selectRibbonTab("b360-data", "metadata-master");
    expect(subTab("b360-data")).toBe("master");
    expect(() => selectRibbonTab("b360-data", "nope")).toThrow(/Tabs: records, sources, metadata/);
  });
});

