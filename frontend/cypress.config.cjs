// End-to-end specs (Cypress, Electron). Cypress is NOT a package.json dependency (keeps the
// install small); run it with npx against the fake IDMC stack - see README "UI end-to-end".
// Plain object (no require("cypress")) so it loads when Cypress comes from npx.
module.exports = {
  e2e: {
    baseUrl: process.env.TXMDM_UI_URL || "http://localhost:5173",
    specPattern: "cypress/e2e/**/*.cy.js",
    supportFile: false,
    video: false,
    viewportWidth: 1400,
    viewportHeight: 900,
    defaultCommandTimeout: 15000,
  },
};
