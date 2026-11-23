// 0.9.1 (Vamsi 2026-11-23 00:15-00:19 CST): Taskflows tabs are Run / Summary / Session log.
// Run = taskflow list + fields + Run, with the run history stacked below (Summary / Session log
// link per run). A start stays on Run and shows on top of the history at once.
describe("Taskflows tab (fake IDMC)", () => {
  it("runs by name, stays on Run, history shows the run, links open Summary and Session log", () => {
    cy.visit("/taskflows");
    cy.get('[data-testid="ribbon-tab-track"]').should("not.exist");
    cy.get('[data-testid="tf-run"]').should("not.exist"); // fields + Run appear once picked
    cy.get('[data-testid="tf-item-tf_demo_advanced"]').click();
    cy.get('[data-testid="tf-param-key-0"]').should("have.value", "jobInstanceId");
    cy.get('[data-testid="tf-param-value-0"]').should("have.value", "ABC123");
    cy.get('[data-testid="tf-history"]').should("be.visible");
    cy.get('[data-testid="tf-history-refresh"]').should("contain", "every 15 s");
    cy.get('[data-testid="tf-run-view"]').should("not.exist");
    cy.get('[data-testid="run-progress"]').should("not.exist");
    cy.on("window:confirm", (text) => { expect(text).to.contain("jobInstanceId=ABC123"); return true; });
    cy.get('[data-testid="tf-run"]').click();
    // stays on Run; the accepted run is on top of the history at once, marked running
    cy.get('[data-testid="ribbon-tab-run"]').should("have.attr", "aria-selected", "true");
    cy.location("pathname").should("eq", "/taskflows");
    cy.get('[data-testid="tf-history-table"] tbody tr').first()
      .should("have.attr", "data-trackable", "true")
      .and("have.attr", "data-running", "true")
      .invoke("attr", "data-testid")
      .then((testId) => {
        const runId = String(testId).replace("tf-history-row-", "");
        expect(runId).to.match(/^\d+$/);
        // Run button still usable for a parallel start
        cy.get('[data-testid="tf-run"]').should("not.be.disabled");
        cy.screenshot("taskflow-run-tab-after-run");
        cy.get(`[data-testid="tf-history-summary-${runId}"]`).click();
        cy.get('[data-testid="ribbon-tab-summary"]').should("have.attr", "aria-selected", "true");
        cy.get('[data-testid="tf-run-id"]').should("have.text", runId);
        cy.get('[data-testid="run-progress"]').should("exist");
        cy.get('[data-testid="tf-last-refresh"]').should("exist");
        cy.get('[data-testid="tf-run-view"]', { timeout: 30000 }).should("have.attr", "data-status", "SUCCESS");
        cy.get('[data-testid="tf-totals"]').should("contain", "2,397 ok");
        cy.screenshot("taskflow-summary-tab");
        cy.get('[data-testid="ribbon-tab-run"]').click();
        cy.get(`[data-testid="tf-history-log-${runId}"]`).click();
        cy.get('[data-testid="ribbon-tab-log"]').should("have.attr", "aria-selected", "true");
        cy.get('[data-testid="tf-log-mt_demo_load"]').click();
        cy.get('[data-testid="tf-log-viewer"]').should("contain", "Committed 1200 rows");
        cy.screenshot("taskflow-session-log-tab");
      });
  });
  it("Summary and Session log say so when no run is selected", () => {
    cy.visit("/taskflows");
    cy.get('[data-testid="ribbon-tab-summary"]').click();
    cy.get('[data-testid="tf-no-run"]').should("contain", "Session log on a run");
    cy.get('[data-testid="ribbon-tab-log"]').click();
    cy.get('[data-testid="tf-no-run"]').should("be.visible");
  });
  it("a run link (deep link) opens Summary (SUSPENDED with failed child)", () => {
    cy.visit("/taskflows/runs/900000000000000002");
    cy.get('[data-testid="ribbon-tab-summary"]').should("have.attr", "aria-selected", "true");
    cy.get('[data-testid="tf-status"]').should("contain", "STOPPED (SUSPENDED)");
    cy.get('[data-testid="tf-error"]').should("contain", "JobInstanceId");
    cy.get('[data-testid="tf-sum-log-mt_demo_load"]').click();
    cy.get('[data-testid="ribbon-tab-log"]').should("have.attr", "aria-selected", "true");
    cy.get('[data-testid="tf-log-viewer"]').should("contain", "LOG13");
    cy.screenshot("fake-suspended");
  });
  it("agent bridge exposes taskflow actions", () => {
    cy.visit("/taskflows");
    cy.window().its("txmdm").then((t) => {
      const names = t.describe().map((a) => a.name);
      expect(names).to.include.members(["runTaskflowByName", "openTaskflowSummary", "openTaskflowLog", "getTaskflowHistory", "getTaskflowRun", "getTaskflowSessionLog"]);
      expect(names).not.to.include("trackTaskflowRun");
      return t.getTaskflowHistory("tf_demo_advanced").then((h) => {
        expect(h.taskflow_name).to.eq("tf_demo_advanced");
        return t.getTaskflowRun("900000000000000002");
      });
    }).then((s) => expect(s.state_text).to.eq("SUSPENDED"));
  });
});

describe("Abort a running taskflow (fake IDMC)", () => {
  it("shows Abort only while running, confirms, then the run goes final", () => {
    cy.visit("/taskflows/runs/900000000000000003");
    cy.get('[data-testid="tf-status"]').should("contain", "RUNNING");
    cy.get('[data-testid="run-progress"]').should("have.attr", "data-final", "false");
    cy.get('[data-testid="poll-clock"]').should("have.attr", "data-final", "false");
    cy.screenshot("taskflow-running-progress");
    cy.on("window:confirm", (text) => { expect(text).to.contain("900000000000000003"); return true; });
    cy.get('[data-testid="tf-abort"]').should("be.visible").click();
    cy.get('[data-testid="tf-abort-note"]').should("contain", "accepted");
    cy.get('[data-testid="tf-run-view"]', { timeout: 30000 }).should("have.attr", "data-status", "FAILED");
    cy.get('[data-testid="tf-abort"]').should("not.exist");
    // IDMC reports a person's terminate as FAILED + processManuallyTerminated -> shown as ABORTED.
    cy.get('[data-testid="tf-status"]').should("contain", "ABORTED").and("have.attr", "data-aborted", "true");
    cy.get('[data-testid="run-progress"]').should("have.attr", "data-final", "true").and("have.attr", "data-tone", "warn");
    cy.get('[data-testid="poll-clock"]').should("have.attr", "data-final", "true");
    cy.screenshot("abort-done");
  });
});
