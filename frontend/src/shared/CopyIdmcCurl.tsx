// 0.9.12.4 (Vamsi 02:48-02:50 CST): "the true curl that I should be able to run so that it will
// hit the IDMC APIs and not the APIs that we are writing here." One button per screen: shows
// (inline, no pop-up) and copies a runnable script - PowerShell first (his laptop), bash below.
// Step 1 logs in with $env:IDMC_PASSWORD; the rest are the exact IDMC calls the backend made for
// the newest tx-mdm call of this screen. Never contains the session id or the password.
import { useState, useSyncExternalStore } from "react";
import { Button } from "@ui-sdk/react/button";
import type { IdmcEcho } from "../b360/api-types";
import { errorText, getJson, latestEcho, subscribeEchoes } from "./api";

async function copy(text: string): Promise<boolean> {
  try {
    await navigator.clipboard.writeText(text);
    return true;
  } catch {
    return false;
  }
}

/** prefix: tx-mdm path the screen calls; view: words for the aria-label; slug: testid part. */
export function CopyIdmcCurl({ prefix, view, slug }: { prefix: string; view: string; slug: string }): React.JSX.Element {
  const ref = useSyncExternalStore(subscribeEchoes, () => latestEcho(prefix));
  const [echo, setEcho] = useState<IdmcEcho | null>(null);
  const [status, setStatus] = useState<string>("");

  const open = (): void => {
    if (ref === null) return;
    setStatus("");
    getJson<IdmcEcho>(`/api/idmc/echo/${encodeURIComponent(ref.echoId)}`)
      .then(async (e) => {
        setEcho(e);
        const ok = await copy(e.powershell);
        setStatus(ok ? "PowerShell script copied." : "Copy blocked by the browser: select the text below.");
      })
      .catch((err: unknown) => setStatus(errorText(err)));
  };

  return (
    <div className="idmc-curl" data-testid={`idmc-curl-${slug}`}>
      <Button
        aria-label={`Copy IDMC curl (${view})`}
        data-testid={`idmc-curl-button-${slug}`}
        disabled={ref === null}
        onClick={open}
      >
        Copy IDMC curl
      </Button>
      {ref === null && <span className="muted small"> (no IDMC call on this screen yet)</span>}
      {echo !== null && (
        <span className="small">
          {" "}
          {status}
          {" "}
          <Button aria-label={`Hide IDMC curl (${view})`} data-testid={`idmc-curl-hide-${slug}`} onClick={() => setEcho(null)}>
            Hide
          </Button>
        </span>
      )}
      {echo !== null && (
        <div className="idmc-curl-body" data-testid={`idmc-curl-body-${slug}`}>
          <p className="muted small">
            For {echo.api_method} {echo.api_path} - {echo.calls.length} IDMC call(s)
            {(echo.calls_left_out ?? 0) > 0 ? `, ${echo.calls_left_out ?? 0} more left out` : ""}.
            {echo.writes ? " Contains WRITE calls: running them changes IDMC. Copying runs nothing." : " Read-only calls."}
          </p>
          <p className="muted small">{echo.readme}</p>
          <h4>
            PowerShell (Windows){" "}
            <Button aria-label={`Copy PowerShell IDMC script (${view})`} onClick={() => void copy(echo.powershell).then((ok) => setStatus(ok ? "PowerShell script copied." : "Copy blocked: select the text."))}>
              Copy
            </Button>
          </h4>
          <pre className="curl-script" data-testid={`idmc-curl-ps-${slug}`}>{echo.powershell}</pre>
          <h4>
            bash{" "}
            <Button aria-label={`Copy bash IDMC script (${view})`} onClick={() => void copy(echo.bash).then((ok) => setStatus(ok ? "bash script copied." : "Copy blocked: select the text."))}>
              Copy
            </Button>
          </h4>
          <pre className="curl-script" data-testid={`idmc-curl-sh-${slug}`}>{echo.bash}</pre>
        </div>
      )}
    </div>
  );
}
