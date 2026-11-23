// App shell: the only thing CDI and MDM share. The URL decides which section is shown;
// both panels stay mounted so switching tabs never drops a list already loaded.

import { Tabs, TabsList, TabsTab } from "@ui-sdk/react/tabs";
import { CdiPanel } from "./cdi/CdiPanel";
import { MdmPanel } from "./mdm/MdmPanel";
import { DEFAULT_ROUTE, useRoute, type Route } from "./shared/routes";

export function App(): React.JSX.Element {
  const [route, go] = useRoute();
  const mdmRoute: Route = route.service === "mdm" ? route : DEFAULT_ROUTE;
  const cdiRoute: Route = route.service === "cdi" ? route : { screen: "jobs", service: "cdi" };

  return (
    <div className="shell">
      <header className="topbar">
        <h1>TX MDM Job Runner</h1>
        <Tabs
          aria-label="Service"
          data-testid="service-tabs"
          value={route.service}
          onValueChange={(value) => {
            if (value === "cdi" || value === "mdm") go({ screen: "jobs", service: value });
          }}
        >
          <TabsList>
            <TabsTab value="mdm" data-testid="tab-mdm">
              Business 360 (MDM)
            </TabsTab>
            <TabsTab value="cdi" data-testid="tab-cdi">
              Data Integration (CDI)
            </TabsTab>
          </TabsList>
        </Tabs>
      </header>
      <main>
        <div hidden={route.service !== "mdm"}>
          <MdmPanel route={mdmRoute} go={go} />
        </div>
        <div hidden={route.service !== "cdi"}>
          <CdiPanel route={cdiRoute} go={go} />
        </div>
      </main>
    </div>
  );
}
