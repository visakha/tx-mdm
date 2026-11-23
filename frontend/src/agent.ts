// Agent bridge from the UI SDK. Created before the app renders so it sees every ui-sdk
// component. Starting a job is a button press, so the bridge asks a person before any press.

import { createAgent } from "@ui-sdk/react/agent";

const agent = createAgent({
  allow: (step) => step.action !== "press" || window.confirm(`Allow the agent to press ${String(step.args[0])}?`),
});

Object.assign(window, { agent });

export { agent };
