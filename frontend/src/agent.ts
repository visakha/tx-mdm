// Agent bridge from the UI SDK (@ui-sdk/react/agent). Created before the app renders so it sees
// every ui-sdk component. See internal-notes/ui-sdk-philosophy.md.
//
// No confirmation for persons or agents, by owner decision 2026-11-23 01:53 CST (Vamsi: "Take it
// out."). data-agent-confirm sentences stay on Run/Abort/Save/Send as descriptive labels the agent
// sees in snapshot(); allow() answers yes for every step, so they no longer block.

import { createAgent } from "@ui-sdk/react/agent";

const agent = createAgent({
  allow: () => true,
});

// Agent-ready signal (0.9.10): the bridge test saw an empty snapshot for ~4 s after load while
// the first screen fetched its data. agentReady resolves (and <html data-agent-ready="true"> is
// set) once snapshot() lists at least one component; waits at most 20 s, then resolves anyway.
const agentReady: Promise<number> = new Promise((resolve) => {
  const started = Date.now();
  const tick = (): void => {
    const count = agent.snapshot().length;
    if (count > 0 || Date.now() - started > 20000) {
      document.documentElement.dataset["agentReady"] = count > 0 ? "true" : "timeout";
      resolve(count);
      return;
    }
    window.setTimeout(tick, 100);
  };
  window.setTimeout(tick, 0);
});

Object.assign(window, { agent, agentReady });

export { agent, agentReady };
