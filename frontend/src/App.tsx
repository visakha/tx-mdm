// App shell: the only thing CDI and MDM share, plus the CDI Monitor tab. The URL decides which section is shown;
// both panels stay mounted so switching tabs never drops a list already loaded.

import { Tabs, TabsList, TabsTab } from "@ui-sdk/react/tabs";
import { CdiPanel } from "./cdi/CdiPanel";
import { MonitorPanel } from "./cdi/MonitorPanel";
import { TaskflowsPanel } from "./cdi/TaskflowsPanel";
import { MdmPanel } from "./mdm/MdmPanel";
import {
  DEFAULT_ROUTE,
  MONITOR_ROUTE,
  TASKFLOWS_ROUTE,
  useRoute,
  type Route,
} from "./shared/routes";

export function App(): React.JSX.Element {
  const [route, go] = useRoute();
  const mdmRoute: Route = route.service === "mdm" ? route : DEFAULT_ROUTE;
  const onMonitor = route.screen === "monitor";
  const onTaskflows = route.screen === "taskflows";
  const cdiRoute: Route =
    route.service === "cdi" && !onMonitor && !onTaskflows
      ? route
      : { screen: "jobs", service: "cdi" };
  const tfRoute: Route = onTaskflows ? route : TASKFLOWS_ROUTE;
  const tab = onMonitor ? "monitor" : onTaskflows ? "taskflows" : route.service;

  return (
    <div className="shell">
      <header className="topbar">
        <h1>TX MDM Job Runner</h1>
        <Tabs
          aria-label="Service"
          data-testid="service-tabs"
          value={tab}
          onValueChange={(value) => {
            if (value === "cdi" || value === "mdm") go({ screen: "jobs", service: value });
            if (value === "monitor") go(MONITOR_ROUTE);
            if (value === "taskflows") go(TASKFLOWS_ROUTE);
          }}
        >
          <TabsList>
            <TabsTab value="mdm" data-testid="tab-mdm">
              Business 360 (MDM)
            </TabsTab>
            <TabsTab value="cdi" data-testid="tab-cdi">
              Data Integration (CDI)
            </TabsTab>
            <TabsTab value="monitor" data-testid="tab-monitor">
              Monitor (CDI)
            </TabsTab>
            <TabsTab value="taskflows" data-testid="tab-taskflows">
              Taskflows (CDI)
            </TabsTab>
          </TabsList>
        </Tabs>
      </header>
      <main>
        <div hidden={tab !== "mdm"}>
          <MdmPanel route={mdmRoute} go={go} />
        </div>
        <div hidden={tab !== "cdi"}>
          <CdiPanel route={cdiRoute} go={go} />
        </div>
        <div hidden={!onMonitor}>
          <MonitorPanel active={onMonitor} />
        </div>
        <div hidden={!onTaskflows}>
          <TaskflowsPanel route={tfRoute} go={go} active={onTaskflows} />
        </div>
      </main>
    </div>
  );
}
