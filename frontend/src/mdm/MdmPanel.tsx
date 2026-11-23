// MDM (Business 360) section: pick an ingress / egress / match-merge job definition, run it,
// watch it. URL-driven: /mdm/jobs, /mdm/jobs/:assetId, /mdm/runs/:runKey.
// Jobs whose internal id is not resolved yet are listed but cannot be run.

import { useCallback } from "react";
import { Button } from "@ui-sdk/react/button";
import { Input } from "@ui-sdk/react/input";
import { Listbox, ListboxItem } from "@ui-sdk/react/listbox";
import { RunResult } from "../shared/RunResult";
import type { RunView } from "../shared/run";
import type { Route } from "../shared/routes";
import { usePicker, useStarter } from "../shared/usePicker";
import { useRunPolling } from "../shared/useRunPolling";
import { mdmApi, type MdmJob } from "./mdmApi";

const idOf = (j: MdmJob): string => j.asset_id;
const textOf = (j: MdmJob): string => `${j.path} ${j.kind}`;

export function MdmPanel({
  route,
  go,
}: {
  route: Route;
  go: (route: Route) => void;
}): React.JSX.Element {
  const selectedId = route.screen === "job" ? route.jobId : null;
  const runKey = route.screen === "run" ? route.runKey : null;
  const picker = usePicker(mdmApi.listJobs, idOf, textOf, selectedId);
  const onStarted = useCallback(
    (run: RunView) => go({ screen: "run", service: "mdm", runKey: run.run_key }),
    [go],
  );
  const starter = useStarter(onStarted);
  const { run, pollError } = useRunPolling(runKey, mdmApi.runUrl);

  const job = picker.selected;

  return (
    <div className="panel" data-testid="mdm-panel">
      <section className="picker" aria-label="MDM jobs">
        <div className="picker-head">
          <h2>Business 360 jobs</h2>
          <Button aria-label="Refresh MDM jobs" data-testid="mdm-refresh" onClick={picker.reload}>
            Refresh
          </Button>
        </div>
        <Input
          aria-label="Filter MDM jobs"
          data-testid="mdm-filter"
          placeholder="Filter by name or kind"
          value={picker.filter}
          onValueChange={(value) => picker.setFilter(value ?? "")}
        />
        {picker.loading && <p className="muted">Loading job definitions from IDMC...</p>}
        {picker.loadError !== null && (
          <p className="warn-text" data-testid="mdm-load-error">
            {picker.loadError}
          </p>
        )}
        <Listbox
          aria-label="MDM job list"
          data-testid="mdm-job-list"
          value={selectedId}
          onValueChange={(value) => {
            if (value !== null) go({ screen: "job", service: "mdm", jobId: value });
          }}
        >
          {picker.visible.map((j) => (
            <ListboxItem key={j.asset_id} value={j.asset_id} data-testid={`mdm-job-${j.asset_id}`}>
              <span className="item-name">{j.name}</span>
              <span className={`item-tag ${j.runnable ? "" : "dim"}`}>{j.kind}</span>
            </ListboxItem>
          ))}
        </Listbox>
      </section>

      <section className="detail" aria-label="MDM detail">
        {route.screen === "jobs" && <p className="muted">Pick a job definition to run.</p>}
        {route.screen === "job" && job === undefined && !picker.loading && (
          <p className="warn-text">No MDM job definition with id {route.jobId}.</p>
        )}
        {route.screen === "job" && job !== undefined && (
          <div className="run-box" data-testid="mdm-job-detail">
            <h2>{job.name}</h2>
            <p className="muted">
              {job.kind} · {job.path}
              {job.job_definition_id !== null && <> · id {job.job_definition_id}</>}
            </p>
            {job.note !== "" && <p className="warn-text">{job.note}</p>}
            <Button
              aria-label={`Run ${job.name}`}
              data-testid="mdm-run"
              disabled={starter.starting || !job.runnable}
              onClick={() => starter.start(() => mdmApi.startRun(job.asset_id))}
            >
              {starter.starting ? "Starting..." : `Run ${job.kind}`}
            </Button>
            {starter.startError !== null && (
              <p className="warn-text" data-testid="mdm-start-error">
                {starter.startError}
              </p>
            )}
          </div>
        )}
        {route.screen === "run" && run === null && pollError === null && (
          <p className="muted">Loading run...</p>
        )}
        {route.screen === "run" && run === null && pollError !== null && (
          <p className="warn-text">{pollError}</p>
        )}
        {run !== null && <RunResult run={run} pollError={pollError} />}
      </section>
    </div>
  );
}
