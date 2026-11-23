// Results screen, same for CDI and MDM: name on top, status, start time, short live log,
// counts on one side, errors on the other.

import { statusTone, type RunCounts, type RunView } from "./run";

function fmt(value: string | null): string {
  return value === null ? "-" : new Date(value).toLocaleString();
}

function count(value: number | null): string {
  return value === null ? "-" : value.toLocaleString();
}

function CountsTable({ counts }: { counts: RunCounts }): React.JSX.Element {
  return (
    <table className="counts">
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
}: {
  run: RunView;
  pollError: string | null;
}): React.JSX.Element {
  return (
    <section className="result" aria-label="Run result">
      <header>
        <h2>{run.job_name}</h2>
        <span className={`status ${statusTone(run.status)}`}>{run.status}</span>
      </header>
      <dl className="times">
        <dt>Type</dt>
        <dd>{run.job_kind}</dd>
        <dt>Started</dt>
        <dd>{fmt(run.started_at)}</dd>
        <dt>Ended</dt>
        <dd>{fmt(run.ended_at)}</dd>
      </dl>
      <ol className="log">
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
            <ul className="errors">
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
