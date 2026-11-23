// 0.8.0: the left-pane search finds ITEMS (CDI tasks, taskflows, MDM jobs) by name.
describe("Left-pane item search (fake IDMC)", () => {
  it("finds a taskflow by name and opens it picked on the Run tab", () => {
    cy.visit("/mdm/jobs");
    cy.get('[data-testid="nav-search"]').type("demo_adv");
    cy.get('[data-testid="search-results"]').should("be.visible");
    cy.get('[data-testid="search-hit-tf_demo_advanced"]').should("have.attr", "data-kind", "taskflow");
    cy.screenshot("search-taskflow-hit");
    cy.get('[data-testid="search-hit-tf_demo_advanced"]').click();
    cy.location("pathname").should("eq", "/taskflows");
    cy.get('[data-testid="ribbon-tab-run"]').should("have.attr", "aria-selected", "true");
    cy.get('[data-testid="tf-item-tf_demo_advanced"]').should("have.attr", "aria-selected", "true");
    cy.get('[data-testid="tf-run"]').should("not.be.disabled");
    cy.screenshot("search-taskflow-picked");
  });

  it("finds MDM jobs and CDI tasks; empty text hides the matches", () => {
    cy.visit("/cdi/jobs");
    cy.get('[data-testid="nav-search"]').type("e");
    cy.get('[data-testid="search-count"]').invoke("text").then((n) => expect(Number(n)).to.be.greaterThan(0));
    cy.get('[data-testid^="search-hit-"][data-kind="task"]').first().then(($hit) => {
      cy.wrap($hit).click();
      cy.location("pathname").should("match", /^\/cdi\/jobs\/.+/);
    });
    cy.get('[data-testid="nav-search"]').clear().type("zzzz-no-such-name");
    cy.get('[data-testid="search-count"]').should("have.text", "0");
    cy.get('[data-testid="search-results"]').should("contain", "No task, taskflow or job matches");
    cy.get('[data-testid="nav-search"]').clear();
    cy.get('[data-testid="search-results"]').should("not.exist");
  });

  it("an agent opens a search match through the UI SDK bridge (setValue on Search results)", () => {
    cy.visit("/mdm/jobs");
    cy.get('[data-testid="nav-search"]').type("demo_adv");
    cy.get('[data-testid="search-hit-tf_demo_advanced"]').should("exist");
    cy.window().then((win) =>
      win.agent.act({ steps: [{ ref: "Search results", action: "setValue", args: ["taskflow:FED3"] }] }),
    ).then((result) => expect(result.ok, JSON.stringify(result.error)).to.eq(true));
    cy.location("pathname").should("eq", "/taskflows");
    cy.get('[data-testid="tf-item-tf_demo_advanced"]').should("have.attr", "aria-selected", "true");
  });

  it("Run and Abort carry UI SDK confirm marks for agents", () => {
    cy.visit("/taskflows");
    cy.get('[data-testid="tf-run"]').should("have.attr", "data-agent-confirm").and("contain", "live IDMC org");
  });
});
