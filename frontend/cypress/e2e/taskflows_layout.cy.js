// 0.8.0 (Vamsi 23:34 / 23:35 CST): full width, long names on one line.
// 0.9.1 (Vamsi 00:18 CST): "Run taskflow by name" keeps 100% width; the run history is stacked
// directly BELOW it, also 100% width (not side by side).
describe("Taskflows Run tab layout: form and history stacked, full width (fake IDMC)", () => {
  it("run form and run history are both full width, history below, long name on one line", () => {
    cy.viewport(1280, 720);
    cy.visit("/taskflows");
    const name = "tf_MDM_ZLV_TTF_Guest_Basic_EGR";
    cy.get(`[data-testid="tf-item-${name}"]`).click();
    cy.get('[data-testid="tf-history-refresh"]').should("exist");
    cy.get('[data-testid="taskflows-panel"]').then(($panel) => {
      const panel = $panel[0].getBoundingClientRect();
      const doc = $panel[0].ownerDocument;
      const run = doc.querySelector('[data-testid="tf-run-box"]').getBoundingClientRect();
      const hist = doc.querySelector('[data-testid="tf-history"]').getBoundingClientRect();
      expect(run.width).to.be.greaterThan(panel.width - 4);
      expect(hist.width).to.be.greaterThan(panel.width - 4);
      expect(hist.top).to.be.at.least(run.bottom);
      expect(run.right).to.be.at.most(panel.right + 1);
      expect(hist.right).to.be.at.most(panel.right + 1);
      const list = doc.querySelector('[data-testid="tf-list"]').getBoundingClientRect();
      expect(list.width).to.be.greaterThan(run.width - 40);
    });
    cy.get(`[data-testid="tf-item-${name}"] .tf-name`).then(($n) => {
      const el = $n[0];
      const lineHeight = parseFloat(getComputedStyle(el).lineHeight) || 20;
      expect(el.getBoundingClientRect().height).to.be.lessThan(lineHeight * 1.5); // one line
      const list = el.closest('[data-testid="tf-list"]');
      expect(list.scrollWidth).to.be.at.most(list.clientWidth + 1);
    });
    cy.screenshot("taskflows-run-tab-stacked-full-width");
  });
});
