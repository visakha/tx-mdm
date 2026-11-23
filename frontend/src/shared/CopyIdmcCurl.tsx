// 0.9.12.4 (Vamsi 02:48-02:50 CST): "the true curl that I should be able to run so that it will
// hit the IDMC APIs and not the APIs that we are writing here." Step 1 logs in with
// $env:IDMC_PASSWORD; the rest are the exact IDMC calls the backend made for the newest tx-mdm call
// of this screen. Never contains the session id or the password.
// 0.9.13.1 (Vamsi 03:11 CST): "copy to the clipboard and just put a small message beneath the
// button ... You really don't have to show me on the screen." The script is NOT rendered: the
// button copies the PowerShell script (his laptop); "bash" copies the bash variant.
import { useState, useSyncExternalStore } from "react";
import { Button } from "@ui-sdk/react/button";
import type { IdmcEcho } from "../b360/api-types";
import { errorText, getJson, latestEcho, subscribeEchoes } from "./api";
import { copyMessage, copyText } from "./clipboard";

type Flavour = "powershell" | "bash";

/** prefix: tx-mdm path the screen calls; view: words for the aria-label; slug: testid part. */
export function CopyIdmcCurl({ prefix, view, slug }: { prefix: string; view: string; slug: string }): React.JSX.Element {
  const ref = useSyncExternalStore(subscribeEchoes, () => latestEcho(prefix));
  const [status, setStatus] = useState<string>("");

  const copyScript = (flavour: Flavour): void => {
    if (ref === null) return;
    setStatus("");
    getJson<IdmcEcho>(`/api/idmc/echo/${encodeURIComponent(ref.echoId)}`)
      .then(async (e) => {
        const result = await copyText(flavour === "powershell" ? e.powershell : e.bash);
        const writes = e.writes ? " It contains WRITE calls: running it changes IDMC." : "";
        setStatus(`${copyMessage(result)}${result.ok ? writes : ""}`);
      })
      .catch((err: unknown) => setStatus(`Could not copy to the clipboard: ${errorText(err)}`));
  };

  return (
    <div className="idmc-curl" data-testid={`idmc-curl-${slug}`}>
      <Button
        aria-label={`Copy IDMC curl (${view})`}
        data-testid={`idmc-curl-button-${slug}`}
        disabled={ref === null}
        onClick={() => copyScript("powershell")}
        title="Copies a PowerShell script: set $env:IDMC_PASSWORD first"
      >
        Copy IDMC curl
      </Button>{" "}
      <Button
        aria-label={`Copy IDMC curl bash (${view})`}
        data-testid={`idmc-curl-bash-${slug}`}
        disabled={ref === null}
        onClick={() => copyScript("bash")}
        title="Copies the bash variant: export IDMC_PASSWORD first"
      >
        bash
      </Button>
      {ref === null && <span className="muted small"> (no IDMC call on this screen yet)</span>}
      {status !== "" && (
        <p className="muted small copy-note" data-testid={`idmc-curl-status-${slug}`}>
          {status}
        </p>
      )}
    </div>
  );
}
