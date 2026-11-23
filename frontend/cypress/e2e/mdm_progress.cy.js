// 0.8.0 (Vamsi 23:40 CST): Business 360 (MDM) results pane shows a progress bar and a poll
// clock that changes colour on every 15 s status check, then stops when the run is final.
describe("MDM results pane: progress bar + poll clock (fake IDMC)", () => {
  it("indeterminate while running, clock ticks, full and green when SUCCESS", () => {
    cy.visit("/mdm/ingress");
    cy.get('[data-testid="mdm-job-A1"]').click();
    cy.get('[data-testid="mdm-run"]').click();
    cy.location("pathname").should("match", /\/mdm\/runs\/\w+/);
    cy.get('[data-testid="run-progress"]').should("have.attr", "data-final", "false").and("have.attr", "data-indeterminate");
    cy.get('[data-testid="poll-clock"]').should("have.attr", "data-final", "false").invoke("attr", "style").as("firstColour");
    cy.screenshot("mdm-progress-running");
    // second status check (15 s) -> SUCCESS in the fake; colour changed, bar full + ok tone
    cy.get('[data-testid="run-result"]', { timeout: 40000 }).should("have.attr", "data-status", "SUCCESS");
    cy.get('[data-testid="run-progress"]').should("have.attr", "data-final", "true").and("have.attr", "data-tone", "ok").and("have.attr", "data-complete");
    cy.get('[data-testid="poll-clock"]').should("have.attr", "data-final", "true").invoke("attr", "data-polls").then((n) => expect(Number(n)).to.be.at.least(2));
    cy.screenshot("mdm-progress-success");
  });
});
