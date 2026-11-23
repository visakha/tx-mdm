// 0.9.10 agent-driven check (Vamsi 01:50 CST): drive the app ONLY through window.agent
// snapshot() / act() / query() - no cy.click / cy.type - against the FAKE IDMC. Never run this
// against his live org. Records what an agent sees: snapshot size per step and every label the
// agent could not find.
//
// Run: fake stack + `npm run dev` (README "UI end-to-end"), then
//   npx cypress@16 run --browser electron --spec cypress/e2e/agent_b360_fake.cy.js

const report = { snapshots: [], notFound: [], steps: [] };

function snap(win, stage) {
  const s = win.agent.snapshot();
  const text = JSON.stringify(s);
  report.snapshots.push({ stage, components: s.length, chars: text.length, labels: s.map((c) => c.label).filter(Boolean) });
  return s;
}

async function act(win, ref, action, args = []) {
  const r = await win.agent.act({ steps: [{ ref, action, args }] });
  report.steps.push({ ref, action, args, ok: r.ok, error: r.ok ? undefined : String(r.error && (r.error.message || r.error)) });
  if (!r.ok) report.notFound.push(`${ref} (${action}): ${JSON.stringify(r.error)}`);
  return r;
}

// Wait (agent-side only) until snapshot() lists a component with this label.
function waitLabel(label, tries = 0) {
  return cy.window().then((win) => {
    const found = win.agent.snapshot().some((c) => c.label === label);
    if (!found && tries < 60) return cy.wait(250).then(() => waitLabel(label, tries + 1));
    return undefined;
  });
}

function pressAction(snapshot, label) {
  const c = snapshot.find((x) => x.label === label);
  if (!c) return "press";
  return (c.actions || []).includes("press") ? "press" : (c.actions || [])[0] || "press";
}

describe("Agent drives B360 Data via window.agent (fake IDMC)", () => {
  after(() => {
    cy.writeFile("cypress/results/agent_b360_report.json", report);
  });

  it("opens ZLV Guest, pages, filters, opens Metadata (M), generates 2 rows", () => {
    cy.visit("/b360");
    cy.window().its("agent").should("exist");
    cy.window().then((win) => win.agentReady).then((n) => {
      report.readyComponents = n;
    });

    // 1. Open ZLV Guest from the left pane Listbox, once the agent can see it (query only).
    const waitItem = (tries = 0) =>
      cy.window().then(async (win) => {
        const q = await win.agent.query({ within: "B360 Data sections" });
        const ok = (q.items || []).some((i) => i.value === "entity:zlv_guest");
        if (!ok && tries < 40) return cy.wait(250).then(() => waitItem(tries + 1));
        report.listWaitMs = tries * 250;
        return undefined;
      });
    waitItem();
    cy.window().then(async (win) => {
      const s = snap(win, "start /b360");
      report.startLabels = s.map((c) => c.label).filter(Boolean);
      await act(win, "B360 Data sections", "setValue", ["entity:zlv_guest"]);
    });
    cy.location("pathname").should("contain", "zlv_guest");
    cy.get('[data-testid="b360-records-table"]', { timeout: 15000 }).should("exist");

    // 2. Page Records (M).
    cy.window().then(async (win) => {
      const s = snap(win, "Records (M) page 1");
      // 0.9.12.1: no picker box above the table; each row has an "Open master record <id>" button.
      const opener = s.find((c) => typeof c.label === "string" && c.label.startsWith("Open master record "));
      if (!opener) report.notFound.push("Open master record <id> (row button)");
      await act(win, "Next page", pressAction(s, "Next page"));
    });
    cy.get('[data-testid="b360-page-info"]').should("contain", "Page 2");

    // 3. First-name filter.
    cy.window().then(async (win) => {
      const s = snap(win, "Records (M) page 2");
      await act(win, "Filter First name", "setValue", ["Anna"]);
      await act(win, "Apply filters", pressAction(s, "Apply filters"));
    });
    cy.get('[data-testid="b360-filters-applied"]').should("contain", "Anna");

    // 4. Metadata > Master (default sub-tab) via the ribbon Tabs.
    cy.window().then(async (win) => {
      snap(win, "Records (M) filtered");
      await act(win, "Section tabs", "setValue", ["metadata"]);
    });
    cy.get('[data-testid="b360-meta-fields"]', { timeout: 15000 }).should("exist");

    // 5. Add records (S): generate 2 test rows.
    cy.window().then(async (win) => {
      snap(win, "Metadata (M)");
      await act(win, "Section tabs", "setValue", ["add"]);
    });
    waitLabel("Add records mode Generate test data");
    cy.window().then(async (win) => {
      const s = snap(win, "Add records (S)");
      await act(win, "Add records mode Generate test data", pressAction(s, "Add records mode Generate test data"));
    });
    waitLabel("Generate test rows");
    cy.window().then(async (win) => {
      const s = snap(win, "Generate mode");
      await act(win, "Generate number of records", "setValue", ["2"]);
      await act(win, "Generate test rows", pressAction(s, "Generate test rows"));
    });
    cy.get('[data-testid="b360-add-preview"] tbody tr[data-testid^="b360-add-row-"]', { timeout: 15000 }).should("have.length", 2);
    cy.window().then(async (win) => {
      snap(win, "2 rows generated");
      const q = await win.agent.query({ text: "Send" });
      report.querySend = JSON.stringify(q).length;
      expect(report.notFound, report.notFound.join("\n")).to.deep.equal([]);
    });
  });
});
