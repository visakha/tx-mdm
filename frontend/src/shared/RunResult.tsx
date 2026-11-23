// Results screen, same for CDI and MDM: name on top, status, start time, short live log,
// counts on one side, errors on the other.

import { RunProgress } from "./RunProgress";
import { isTerminal, statusTone, type RunCounts, type RunView } from "./run";
import { RUN_POLL_SECONDS } from "./useRunPolling";

function fmt(value: string | null): string {
  return value === null ? "-" : new Date(value).toLocaleString();
}

function count(value: number | null): string {
  return value === null ? "-" : value.toLocaleString();
}

function CountsTable({ counts }: { counts: RunCounts }): React.JSX.Element {
  return (
    <table className="counts" data-testid="run-counts">
      <thead>
        <tr>
          <th />
          <th>Success</th>
          <th>Failed</th>
        </tr>
      </thead>
      <tbody>
        <tr>
          <th>Source / ingress</th>
          <td>{count(counts.source_success)}</td>
          <td>{count(counts.source_failed)}</td>
        </tr>
        <tr>
          <th>Target / egress</th>
          <td>{count(counts.target_success)}</td>
          <td>{count(counts.target_failed)}</td>
        </tr>
      </tbody>
    </table>
  );
}

export function RunResult({
  run,
  pollError,
  polls,
}: {
  run: RunView;
  pollError: string | null;
  polls: number;
}): React.JSX.Element {
  const c = run.counts;
  const known = [c.source_success, c.target_success].filter((v): v is number => v !== null);
  const detail = known.length === 0 ? "no row counts reported yet" : `${known.map((v) => v.toLocaleString()).join(" / ")} rows ok so far`;
  return (
    <section className="result" aria-label="Run result" data-testid="run-result" data-run-key={run.run_key} data-status={run.status}>
      <header>
        <h2 data-testid="run-job-name">{run.job_name}</h2>
        <span className={`status ${statusTone(run.status)}`} data-testid="run-status">{run.status}</span>
      </header>
      <RunProgress
        final={isTerminal(run.status)}
        tone={statusTone(run.status)}
        label={`Progress of ${run.job_name}`}
        detail={detail}
        polls={polls}
        everySeconds={RUN_POLL_SECONDS}
      />
      <dl className="times">
        <dt>Type</dt>
        <dd>{run.job_kind}</dd>
        <dt>Requested</dt>
        <dd data-testid="run-started" title="When this app submitted the run">
          {fmt(run.started_at)}
        </dd>
        <dt>Started in IDMC</dt>
        <dd data-testid="run-idmc-started" title="Start time reported by Informatica">
          {run.idmc_started_at === null ? "not reported yet" : fmt(run.idmc_started_at)}
        </dd>
        <dt>Ended</dt>
        <dd>{fmt(run.ended_at)}</dd>
      </dl>
      <ol className="log" data-testid="run-log">
        {run.log.slice(-8).map((line, index) => (
          <li key={`${line.at}-${index}`}>
            <time>{new Date(line.at).toLocaleTimeString()}</time> {line.message}
          </li>
        ))}
      </ol>
      {pollError !== null && <p className="warn-text">Status check failed: {pollError}</p>}
      <div className="split">
        <div>
          <h3>Counts</h3>
          <CountsTable counts={run.counts} />
        </div>
        <div>
          <h3>Errors</h3>
          {run.errors.length === 0 ? (
            <p className="muted">None reported.</p>
          ) : (
            <ul className="errors" data-testid="run-errors">
              {run.errors.map((error) => (
                <li key={error}>{error}</li>
              ))}
            </ul>
          )}
        </div>
      </div>
    </section>
  );
}
