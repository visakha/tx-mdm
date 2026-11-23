// Agent bridge from the UI SDK (@ui-sdk/react/agent). Created before the app renders so it sees
// every ui-sdk component. See internal-notes/ui-sdk-philosophy.md.
//
// Permissions follow the SDK docs ("Mark What Needs a Person"): every control with a real side
// effect on the live org (Run, Abort) carries a data-agent-confirm sentence. allow() reads
// step.confirm and asks the person with that exact sentence; the SDK docs warn that an allow()
// returning true without reading step.confirm "answers yes for the person". Unmarked presses
// (Refresh, Track, Add field) only change this page, so they run without asking.

import { createAgent } from "@ui-sdk/react/agent";

const agent = createAgent({
  allow: (step) => {
    if (step.confirm !== undefined && step.confirm !== "") {
      return window.confirm(`The agent wants to: ${step.confirm}. Allow?`);
    }
    return true;
  },
});

Object.assign(window, { agent });

export { agent };
