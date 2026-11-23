describe("Taskflows tab (fake IDMC)", () => {
  it("runs by name with jobInstanceId, tracks to SUCCESS, shows summary and session log", () => {
    cy.visit("/taskflows");
    cy.get('[data-testid="tf-item-tf_demo_advanced"]').click();
    cy.get('[data-testid="tf-param-key-0"]').should("have.value", "jobInstanceId");
    cy.get('[data-testid="tf-param-value-0"]').should("have.value", "ABC123");
    cy.on("window:confirm", (text) => { expect(text).to.contain("jobInstanceId=ABC123"); return true; });
    cy.get('[data-testid="tf-run"]').click();
    cy.location("pathname").should("match", /\/taskflows\/runs\/\d+/);
    cy.get('[data-testid="tf-run-view"]', { timeout: 30000 }).should("have.attr", "data-status", "SUCCESS");
    cy.get('[data-testid="tf-totals"]').should("contain", "2,397 ok");
    cy.get('[data-testid="tf-log-mt_demo_load"]').click();
    cy.get('[data-testid="tf-log-viewer"]').should("contain", "Committed 1200 rows");
    cy.screenshot("fake-success");
  });
  it("tracks a pasted run id (SUSPENDED with failed child)", () => {
    cy.visit("/taskflows");
    cy.get('[data-testid="ribbon-tab-track"]').click();
    cy.get('[data-testid="tf-runid-input"]').type("900000000000000002");
    cy.get('[data-testid="tf-track"]').click();
    cy.get('[data-testid="tf-status"]').should("contain", "STOPPED (SUSPENDED)");
    cy.get('[data-testid="tf-error"]').should("contain", "JobInstanceId");
    cy.get('[data-testid="tf-log-mt_demo_load"]').click();
    cy.get('[data-testid="tf-log-viewer"]').should("contain", "LOG13");
    cy.screenshot("fake-suspended");
  });
  it("agent bridge exposes taskflow actions", () => {
    cy.visit("/taskflows");
    cy.window().its("txmdm").then((t) => {
      const names = t.describe().map((a) => a.name);
      expect(names).to.include.members(["runTaskflowByName", "trackTaskflowRun", "getTaskflowRun", "getTaskflowSessionLog"]);
      return t.getTaskflowRun("900000000000000002");
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
