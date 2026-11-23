# Vercel UI SDK (ui-sdk) - its philosophy and how tx-mdm applies it

Written 2026-11-22 for 0.8.0. Vamsi's ask (23:03 CST): "fully use the philosophy behind the UI SDK
the way Vercel wants you to use it... so that it's agent friendly. So use it to its full extent."

## Sources (read for this note)

- Package docs shipped with the installed release, `@ui-sdk/react@0.1.0-beta.13`:
  `frontend/node_modules/@ui-sdk/react/docs/` - introduction.md, agents.md (Built for Agents,
  Get Started, The Agent Key, Permissions, Observe Changes, History and Undo, WebMCP, Reference),
  components/*.md. Its README says every page is "generated from the same source as the docs
  site, for the release this package came from".
- Docs site: https://ui-sdk.dev (homepage field of the package).
- Source repo: https://github.com/vercel-labs/ui (packages/react).
- Not read: any blog post or talk. Everything below is from the shipped docs only.

## What the SDK says it is (its own terms)

1. **Unstyled, accessible components.** "Use unstyled React components with keyboard, focus, and
   screen reader support built in." You choose markup and CSS; the SDK owns behaviour, focus and
   ARIA. So: use its Listbox / Tabs / Input / Button / Separator instead of hand-rolled divs.
2. **The accessible name IS the agent's handle.** An agent finds a component by its label
   (`aria-label` or a Field label). Same name a screen reader announces. So every SDK component we
   render carries a clear, unique `aria-label`.
3. **Agents use your components through one bridge.** `createAgent()` from `@ui-sdk/react/agent`,
   created before render: `snapshot()` (components, state, available actions), `act({ steps })`
   (call actions such as setValue / press by label or ref), `query({ text, within })` (find items
   in lists). Changes go through the component's own API and change callbacks with
   `source: "agent"`, so an agent's change is the same as a person's.
4. **Permissions: mark what needs a person.** `allow(step)` approves or refuses each action. A
   control with a real side effect gets `data-agent-confirm="<sentence>"`; the snapshot shows the
   sentence and `allow` receives it as `step.confirm`. The docs warn: an allow() that returns true
   without reading step.confirm "answers yes for the person". `data-agent-hidden` and
   `data-agent-secret` keep parts of the page from the agent.
5. **Your own primitives** (`definePrimitive` + an `agent` key with `actions`, `closed`,
   `reveals`, ...) join the same bridge. The `agent` key is marked experimental.
6. **Also offered:** observe changes (`subscribe`), history and undo of agent changes, and WebMCP
   registration of the tools in a supporting browser.

## How tx-mdm applies it (0.8.0)

| Principle | In this app |
|---|---|
| SDK components, own CSS | Left pane: Input (search), Listbox (sections, search matches), Separator. Ribbon: Tabs. Pages: Listbox (task/job/taskflow lists), Input, Button. Styles in styles.css, light theme. |
| Name = handle | Every SDK component has an aria-label: "Search tasks, taskflows and jobs", "Search results", "Taskflow list", "IDMC run id", "Run <name>", "Abort taskflow run <id>". |
| One bridge | `src/agent.ts` creates it before render and puts it on `window.agent`. |
| Mark what needs a person | SUPERSEDED in 0.9.10, see "No confirmation (0.9.10)" below. Run, Abort, Save, Send still carry `data-agent-confirm` sentences, now as descriptive labels only. |
| Agent changes = person changes | Search matches are a Listbox: `agent.act({steps:[{ref:"Search results", action:"setValue", args:["<value>"]}]})` opens the item exactly like a click. |

Our own typed surface `window.txmdm` (agentActions.ts) stays: it reads backend data and drives
routes. It is not part of the SDK; the SDK docs do not describe app-level action registries.

## Not used yet (and why)

- `definePrimitive` / the `agent` key: we have no custom interactive component yet; the key is
  experimental.
- Alert Dialog: not used, on purpose. The owner asked for no pop-ups at all (see below).
- WebMCP `registerTools`, `subscribe`, history/undo: no consumer for them here today.

## Where the docs are thin

- How `data-agent-confirm` interacts with a click handler that also confirms: not described
  (moot since 0.9.10: no handler confirms any more).
- Release is 0.1.0-beta.13; APIs can change. Re-read the shipped docs after any upgrade.

## No confirmation (0.9.10) - owner decision 2026-11-23 01:53 CST

Vamsi, 01:51-01:53 CST: "remove all those pop-ups ... we don't need those pop-ups", then for the
agent-permission asks too: "Take it out."

- No window.confirm / alert / prompt anywhere in frontend/src, for persons OR agents. Run (CDI
  task, MDM job, taskflow), Abort, Save (create / edit) and Send to B360 act at once; results and
  errors show inline on the page.
- `src/agent.ts`: `allow: () => true`. This deliberately departs from the SDK's "mark what needs a
  person" guidance; the owner chose it.
- `src/agentActions.ts`: runJob / runTaskflowByName / terminateTaskflow no longer ask; they are
  still listed with `sideEffect: true` so an agent can see they act on the live org.
- `data-agent-confirm` sentences are KEPT on those buttons as descriptive labels: snapshot() still
  shows the agent what the press does, but nothing blocks on them.
- Guard: `src/noPopups.test.ts` (vitest) fails on any confirm/alert/prompt call in frontend/src,
  no exceptions. Cypress `taskflows_fake.cy.js` now fails if a window:confirm ever fires.

## Used now (0.9.10) and still not

Used on the B360 screens: Input (filters, sourcePKey, generate count, typed fields), Button (every press,
incl. the Last updated sort), Select (source system, picklist fields), Checkbox (boolean fields), Listbox
(left pane; "Open master record" / "Open source record" pickers; "<group> field list" on Metadata), Tabs
(ribbon). Every one has a unique aria-label (scoped: "Add form ...", "Preview row N ...", "Edit ...").
Still own markup: tables (no SDK table component) - labelled with aria-label, with a Listbox picker next to
them so an agent can open a row; Field/FieldLabel not adopted yet (plain <label> wraps). data-agent-hidden /
data-agent-secret: checked, nothing is secret (no credentials in the frontend), so none is set.
Agent-ready: `window.agentReady` (see ui-observations v0.9.10).
