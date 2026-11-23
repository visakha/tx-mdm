describe("OneNote layout (fake IDMC)", () => {
  it("left pane sections drive contextual ribbon tabs", () => {
    cy.visit("/");
    cy.location("pathname").should("eq", "/mdm/jobs");
    cy.get('[data-testid="ribbon-tab-jobs"]').should("exist");
    cy.get('[data-testid="tab-taskflows"]').click();
    cy.location("pathname").should("eq", "/taskflows");
    cy.get('[data-testid="ribbon-tab-run"]').should("exist");
    cy.get('[data-testid="ribbon-tab-log"]').should("exist");
    cy.get('[data-testid="crumb"]').should("contain", "Taskflows");
    cy.get('[data-testid="tf-item-tf_demo_advanced"]').should("be.visible");
    cy.get('[data-testid="tf-runid-input"]').should("not.be.visible");
    cy.get('[data-testid="ribbon-tab-track"]').click();
    cy.get('[data-testid="tf-runid-input"]').should("be.visible").type("900000000000000002");
    cy.get('[data-testid="tf-track"]').click();
    cy.get('[data-testid="tf-status"]').should("contain", "SUSPENDED");
    cy.get('[data-testid="ribbon-tab-log"]').click();
    cy.get('[data-testid="tf-log-mt_demo_load"]').click();
    cy.get('[data-testid="tf-log-viewer"]').should("be.visible").and("contain", "LOG13");
    cy.screenshot("onenote-taskflow-log");
    cy.get('[data-testid="ribbon-tab-summary"]').click();
    cy.get('[data-testid="tf-log-viewer"]').should("not.be.visible");
    cy.screenshot("onenote-taskflow-summary");
  });
  it("monitor ribbon filters sections; MDM ingress/egress filter jobs; search filters the pane", () => {
    cy.visit("/monitor");
    cy.get('[data-testid="monitor-panel"]').should("be.visible");
    cy.get('[data-testid="ribbon-tab-running"]').click();
    cy.get('section[aria-label="Recent history"]').should("not.be.visible");
    cy.screenshot("onenote-monitor-running");
    cy.get('[data-testid="nav-mdm-egress"]').click();
    cy.location("pathname").should("eq", "/mdm/egress");
    cy.get('[data-testid="mdm-panel"]').should("contain", "Egress jobs");
    cy.get('[data-testid="nav-search"]').type("ingress");
    cy.get('[data-testid="nav-mdm-ingress"]').should("exist");
    cy.get('[data-testid="tab-taskflows"]').should("not.exist");
    cy.screenshot("onenote-search");
  });
  it("agent bridge: layout, openNavSection, selectRibbonTab", () => {
    cy.visit("/cdi/jobs");
    cy.window().its("txmdm").then((t) => {
      t.openNavSection("cdi-taskflows");
      t.selectRibbonTab("track");
      const l = t.layout();
      expect(l.section).to.eq("cdi-taskflows");
      expect(l.tab).to.eq("track");
      expect(() => t.selectRibbonTab("bogus")).to.throw();
    });
    cy.get('[data-testid="tf-runid-input"]').should("be.visible");
  });
  it("CDI task run lands in Runs > Result", () => {
    cy.visit("/cdi/jobs");
    cy.get('[data-testid="cdi-task-FED1"]').click();
    cy.get('[data-testid="cdi-run"]').click();
    cy.location("pathname").should("match", /\/cdi\/runs\/\w+/);
    cy.get('[data-testid="crumb"]').should("contain", "Runs");
    cy.get('[data-testid="run-result"]', { timeout: 30000 }).should("have.attr", "data-status", "SUCCESS");
    cy.get('[data-testid="ribbon-tab-list"]').click();
    cy.get('[data-testid="runs-cdi"]').should("be.visible").find('[data-testid^="run-item-"]').should("have.length.at.least", 1);
    cy.screenshot("onenote-runs");
  });
});
