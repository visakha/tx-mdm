// 0.8.0 (Vamsi 23:34 / 23:35 CST): Run taskflow by name spans 100% of the section; Track a run
// id is stacked BELOW it at 100%; long names and run ids show on one line.
describe("Taskflows layout: stacked, full width (fake IDMC)", () => {
  it("run-by-name and track-run-id boxes are stacked, full width, long name on one line", () => {
    cy.viewport(1280, 720);
    cy.visit("/taskflows");
    const name = "tf_MDM_ZLV_TTF_Guest_Basic_EGR";
    cy.get(`[data-testid="tf-item-${name}"]`).click();
    cy.get('[data-testid="tf-runid-input"]').type("1309386379683184640");
    cy.get('[data-testid="taskflows-panel"]').then(($panel) => {
      const panel = $panel[0].getBoundingClientRect();
      const doc = $panel[0].ownerDocument;
      const run = doc.querySelector('[data-testid="tf-run-box"]').getBoundingClientRect();
      const track = doc.querySelector('[data-testid="tf-track-box"]').getBoundingClientRect();
      // both boxes span the section width (within padding) and Track sits below Run
      expect(run.width).to.be.greaterThan(panel.width - 4);
      expect(track.width).to.be.greaterThan(panel.width - 4);
      expect(track.top).to.be.at.least(run.bottom);
      // nothing spills past the section's right edge, and the list itself is full width
      expect(run.right).to.be.at.most(panel.right + 1);
      expect(track.right).to.be.at.most(panel.right + 1);
      const list = doc.querySelector('[data-testid="tf-list"]').getBoundingClientRect();
      expect(list.width).to.be.greaterThan(run.width - 40);
      const go = doc.querySelector('[data-testid="tf-track"]').getBoundingClientRect();
      expect(go.right).to.be.at.most(panel.right + 1);
    });
    cy.get(`[data-testid="tf-item-${name}"] .tf-name`).then(($n) => {
      const el = $n[0];
      const lineHeight = parseFloat(getComputedStyle(el).lineHeight) || 20;
      expect(el.getBoundingClientRect().height).to.be.lessThan(lineHeight * 1.5); // one line
      const list = el.closest('[data-testid="tf-list"]');
      expect(list.scrollWidth).to.be.at.most(list.clientWidth + 1); // whole name visible, no scroll
    });
    cy.get('[data-testid="tf-runid-input"]').then(($i) => {
      expect($i[0].getBoundingClientRect().width).to.be.greaterThan(400);
    });
    cy.screenshot("taskflows-stacked-full-width");
  });
});
