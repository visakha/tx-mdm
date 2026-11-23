// MDM (Business 360) section: pick an ingress / egress / match-merge job definition, run it,
// watch it. Jobs whose internal id is not resolved yet are listed but cannot be run.

import { Button } from "@ui-sdk/react/button";
import { Input } from "@ui-sdk/react/input";
import { Listbox, ListboxItem } from "@ui-sdk/react/listbox";
import { RunResult } from "../shared/RunResult";
import { isTerminal } from "../shared/run";
import { usePicker, useStarter } from "../shared/usePicker";
import { useRunPolling } from "../shared/useRunPolling";
import { mdmApi, type MdmJob } from "./mdmApi";

const idOf = (j: MdmJob): string => j.asset_id;
const textOf = (j: MdmJob): string => `${j.path} ${j.kind}`;

export function MdmPanel(): React.JSX.Element {
  const picker = usePicker(mdmApi.listJobs, idOf, textOf);
  const starter = useStarter();
  const { run, pollError } = useRunPolling(starter.started, mdmApi.runUrl);

  const job = picker.selected;
  const busy = starter.starting || (run !== null && !isTerminal(run.status));

  return (
    <div className="panel">
      <section className="picker" aria-label="MDM jobs">
        <div className="picker-head">
          <h2>Business 360 jobs</h2>
          <Button aria-label="Refresh MDM jobs" onClick={picker.reload}>
            Refresh
          </Button>
        </div>
        <Input
          aria-label="Filter MDM jobs"
          placeholder="Filter by name or kind"
          value={picker.filter}
          onValueChange={(value) => picker.setFilter(value ?? "")}
        />
        {picker.loading && <p className="muted">Loading job definitions from IDMC...</p>}
        {picker.loadError !== null && <p className="warn-text">{picker.loadError}</p>}
        <Listbox
          aria-label="MDM job list"
          value={job?.asset_id ?? null}
          onValueChange={(value) => {
            if (value !== null) picker.select(value);
          }}
        >
          {picker.visible.map((j) => (
            <ListboxItem key={j.asset_id} value={j.asset_id}>
              <span className="item-name">{j.name}</span>
              <span className={`item-tag ${j.runnable ? "" : "dim"}`}>{j.kind}</span>
            </ListboxItem>
          ))}
        </Listbox>
      </section>

      <section className="detail" aria-label="MDM run">
        {job === undefined ? (
          <p className="muted">Pick a job definition to run.</p>
        ) : (
          <div className="run-box">
            <h2>{job.name}</h2>
            <p className="muted">
              {job.kind} · {job.path}
              {job.job_definition_id !== null && <> · id {job.job_definition_id}</>}
            </p>
            {job.note !== "" && <p className="warn-text">{job.note}</p>}
            <Button
              aria-label={`Run ${job.name}`}
              disabled={busy || !job.runnable}
              onClick={() => starter.start(() => mdmApi.startRun(job.asset_id))}
            >
              {busy ? "Running..." : `Run ${job.kind}`}
            </Button>
            {starter.startError !== null && <p className="warn-text">{starter.startError}</p>}
          </div>
        )}
        {run !== null && <RunResult run={run} pollError={pollError} />}
      </section>
    </div>
  );
}
