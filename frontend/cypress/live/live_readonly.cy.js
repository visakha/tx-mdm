// Run against a LIVE backend through dev/forward_readonly.py (see README). Never clicks Run.
// LIVE, READ-ONLY: never clicks Run. Any POST is blocked by the forwarder as well.
describe("live backend (read-only)", () => {
  beforeEach(() => {
    cy.intercept({ method: "POST", url: "/api/**" }, () => { throw new Error("POST attempted in live read-only test"); });
  });
  it("CDI task list loads", () => {
    cy.visit("/cdi/jobs");
    cy.get('[data-testid="cdi-task-list"] [data-testid^="cdi-task-"]').should("have.length.at.least", 10);
    cy.screenshot("live-cdi-tasks");
  });
  it("Taskflows list loads with tf_MDM_ZLV_TTF_Guest_Basic and jobInstanceId prefilled", () => {
    cy.visit("/taskflows");
    cy.get('[data-testid="tf-item-tf_MDM_ZLV_TTF_Guest_Basic"]').should("exist");
    cy.get('[data-testid="tf-param-key-0"]').should("have.value", "jobInstanceId");
    cy.get('[data-testid="tf-param-value-0"]').should("have.value", "ABC123");
    cy.screenshot("live-taskflows-run-tab");
  });
  it("Monitor loads", () => {
    cy.visit("/monitor");
    cy.get('[data-testid="monitor-status-line"]').should("contain", "As of");
    cy.screenshot("live-monitor");
  });
  it("pasted run id 1309380263289049088 shows status, summary and session log", () => {
    cy.visit("/taskflows");
    cy.get('[data-testid="ribbon-tab-track"]').click();
    cy.get('[data-testid="tf-runid-input"]').type("1309380263289049088");
    cy.get('[data-testid="tf-track"]').click();
    cy.location("pathname").should("eq", "/taskflows/runs/1309380263289049088");
    cy.get('[data-testid="tf-status"]').should("contain", "SUSPENDED");
    cy.get('[data-testid="tf-child-mt_m_MDM_ZLV_TTF_Guest_Basic"]').should("contain", "FAILED").and("contain", "JobInstanceId");
    cy.get('[data-testid="ribbon-tab-summary"]').click();
    cy.screenshot("live-run-summary");
    cy.get('[data-testid="ribbon-tab-log"]').click();
    cy.get('[data-testid="tf-log-mt_m_MDM_ZLV_TTF_Guest_Basic"]').click();
    cy.get('[data-testid="tf-log-viewer"]').should("contain", "[FATAL] Invalid/Default JobInstanceId");
    cy.screenshot("live-run-session-log");
  });
});
