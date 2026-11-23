// 0.9.0 (Vamsi 23:55 CST): Business 360 Currently running lists EVERY running b360.* / c360.*
// job in the org - including one started from the portal by someone else (fake id
// 800000000000007984) - with the full id on one line, a 15 s refresh, a Last refresh line,
// and a lookup of any instance id.
describe("Business 360 Currently running (fake IDMC)", () => {
  it("shows a portal-started running job, refreshes every 15 s, and looks up by id", () => {
    cy.visit("/mdm/running");
    cy.get('[data-testid="crumb"]').should("contain", "Currently running");
    cy.get('[data-testid="b360-row-800000000000007984"]')
      .should("have.attr", "data-status", "RUNNING")
      .and("contain", "someone.else")
      .and("contain", "b360.ingress.load");
    // full id on one line: the id cell is exactly one line high
    cy.get('[data-testid="b360-row-800000000000007984"] td.instance-id code').then(($c) => {
      const lh = parseFloat(getComputedStyle($c[0]).lineHeight) || 20;
      expect($c[0].getBoundingClientRect().height).to.be.lessThan(lh * 1.6);
      expect($c.text()).to.eq("800000000000007984");
    });
    cy.get('[data-testid="b360-recent"]').should("contain", "800000000000002720").and("contain", "c360.egress.etl");
    cy.get('[data-testid="b360-recent"]').should("not.contain", "fileImport");
    cy.get('[data-testid="b360-last-refresh"]').should("not.contain", "Last refresh: -").invoke("text").as("first");
    cy.get('[data-testid="b360-monitor"] [data-testid="poll-clock"]').invoke("attr", "data-polls").then((n) => {
      cy.screenshot("b360-currently-running");
      // the next refresh arrives after 15 s: the poll count goes up and the time line changes
      cy.get('[data-testid="b360-monitor"] [data-testid="poll-clock"]', { timeout: 25000 })
        .should(($c) => expect(Number($c.attr("data-polls"))).to.be.greaterThan(Number(n)));
    });
    cy.get("@first").then((first) => {
      cy.get('[data-testid="b360-last-refresh"]').invoke("text").should("not.eq", first);
    });
    cy.get('[data-testid="ribbon-tab-lookup"]').click();
    cy.get('[data-testid="b360-lookup-input"]').type(" 800000000000007984 ");
    cy.get('[data-testid="b360-lookup"]').click();
    cy.get('[data-testid="b360-lookup-result"]').should("contain", "800000000000007984").and("contain", "RUNNING");
    cy.screenshot("b360-lookup");
  });

  it("agent bridge reads the same data", () => {
    cy.visit("/mdm/running");
    cy.window().then(async (win) => {
      const snap = await win.txmdm.getMdmMonitor();
      expect(snap.running.map((j) => j.instance_id)).to.include("800000000000007984");
      const one = await win.txmdm.lookupMdmJob("800000000000002720");
      expect(one.job_type).to.eq("c360.egress.etl");
    });
  });

  it("MDM results pane shows a Last refresh line", () => {
    cy.visit("/mdm/ingress");
    cy.get('[data-testid="mdm-job-A1"]').click();
    cy.get('[data-testid="mdm-run"]').click();
    cy.get('[data-testid="run-last-refresh"]').filter(":visible").should("not.have.text", "-");
    cy.screenshot("mdm-last-refresh");
  });
});
