// Left pane "Runs": runs started from this backend (since it started), newest first.
// Read-only list; clicking a run opens its result (/<service>/runs/:runKey).

import { useCallback, useEffect, useState } from "react";
import { Button } from "@ui-sdk/react/button";
import { Listbox, ListboxItem } from "@ui-sdk/react/listbox";
import { errorText, getJson } from "../shared/api";
import { statusTone, type RunView } from "../shared/run";
import type { Route, Service } from "../shared/routes";

function fmt(value: string | null): string {
  return value === null ? "-" : new Date(value).toLocaleString();
}

export function RunsPanel({
  service,
  active,
  go,
}: {
  service: Service;
  active: boolean;
  go: (route: Route) => void;
}): React.JSX.Element {
  const [runs, setRuns] = useState<RunView[] | null>(null);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback((): void => {
    getJson<RunView[]>(`/api/${service}/runs`)
      .then((all) => {
        setRuns([...all].reverse());
        setError(null);
      })
      .catch((err: unknown) => setError(errorText(err)));
  }, [service]);

  useEffect(() => {
    if (active) load();
  }, [active, load]);

  return (
    <section className="detail" aria-label={`${service.toUpperCase()} runs`} data-testid={`runs-${service}`}>
      <div className="picker-head">
        <h2>Runs started from this app ({runs === null ? "-" : String(runs.length)})</h2>
        <Button aria-label={`Refresh ${service.toUpperCase()} runs`} data-testid={`runs-refresh-${service}`} onClick={load}>
          Refresh
        </Button>
      </div>
      {error !== null && <p className="warn-text">{error}</p>}
      {runs !== null && runs.length === 0 && (
        <p className="muted">No runs since the backend started. Runs started in IDMC itself show in Monitor.</p>
      )}
      <Listbox
        aria-label={`${service.toUpperCase()} run list`}
        value={null}
        onValueChange={(value) => {
          if (value !== null) go({ screen: "run", service, runKey: value });
        }}
      >
        {(runs ?? []).map((r) => (
          <ListboxItem key={r.run_key} value={r.run_key} data-testid={`run-item-${r.run_key}`}>
            <span className={`status ${statusTone(r.status)}`}>{r.status}</span>
            <span className="item-name"> {r.job_name}</span>
            <span className="item-tag">{fmt(r.started_at)}</span>
          </ListboxItem>
        ))}
      </Listbox>
    </section>
  );
}
