// App shell: the only thing CDI and MDM share. Each tab owns its own lists and runs.
// Panels stay mounted (hidden) so switching tabs never loses a run being watched.

import { useState } from "react";
import { Tabs, TabsList, TabsTab } from "@ui-sdk/react/tabs";
import { CdiPanel } from "./cdi/CdiPanel";
import { MdmPanel } from "./mdm/MdmPanel";

type Section = "cdi" | "mdm";

export function App(): React.JSX.Element {
  const [section, setSection] = useState<Section>("mdm");

  return (
    <div className="shell">
      <header className="topbar">
        <h1>TX MDM Job Runner</h1>
        <Tabs
          aria-label="Service"
          value={section}
          onValueChange={(value) => {
            if (value === "cdi" || value === "mdm") setSection(value);
          }}
        >
          <TabsList>
            <TabsTab value="mdm">Business 360 (MDM)</TabsTab>
            <TabsTab value="cdi">Data Integration (CDI)</TabsTab>
          </TabsList>
        </Tabs>
      </header>
      <main>
        <div hidden={section !== "mdm"}>
          <MdmPanel />
        </div>
        <div hidden={section !== "cdi"}>
          <CdiPanel />
        </div>
      </main>
    </div>
  );
}
