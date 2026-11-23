// Monitor tab: what is running in CDI right now (minutes ticking live), recent history with
// success / failed counts and errors, taskflow child steps on demand, and runs started here.
// Auto-refreshes every 15 s; Pause stops it. A 429 from the backend stops auto-refresh for good
// (Informatica rate limit - never hammer it). Read-only: nothing here starts or stops a job.

import { useCallback, useEffect, useState } from "react";
import { Button } from "@ui-sdk/react/button";
import { ApiError, errorText } from "../shared/api";
import { POLL_MS } from "../shared/poll";
import { statusTone } from "../shared/run";
import {
  elapsedText,
  minutesText,
  monitorApi,
  summarize,
  type MonitorEntry,
  type MonitorSnapshot,
} from "./monitorApi";

const REFRESH_MS = POLL_MS;

function fmt(value: string | null): string {
  return value === null ? "-" : new Date(value).toLocaleString();
}

function num(value: number | null): string {
  return value === null ? "-" : value.toLocaleString();
}

function rowsText(success: number | null, failed: number | null): string {
  return `${num(success)} ok / ${num(failed)} failed`;
}

function EntryRows({
  entry,
  nowMs,
  running,
  depth,
  rowKey,
}: {
  entry: MonitorEntry;
  nowMs: number;
  running: boolean;
  depth: number;
  rowKey: string;
}): React.JSX.Element {
  const [open, setOpen] = useState<boolean>(false);
  const hasChildren = entry.children.length > 0;
  const duration = running
    ? elapsedText(entry.started_at, nowMs)
    : minutesText(entry.elapsed_minutes);
  return (
    <>
      <tr data-testid={`monitor-row-${rowKey}`} data-status={entry.status} className={depth > 0 ? "child" : ""}>
        <td style={{ paddingLeft: `${String(8 + depth * 18)}px` }}>
          {hasChildren && (
            <Button
              aria-label={`${open ? "Hide" : "Show"} steps of ${entry.task_name}`}
              data-testid={`monitor-steps-${rowKey}`}
              onClick={() => setOpen(!open)}
            >
              {open ? "-" : "+"}
            </Button>
          )}{" "}
          {entry.task_name}
          {!entry.in_my_tasks && depth === 0 && <span className="item-tag dim">not in my list</span>}
        </td>
        <td>{entry.task_type || "-"}</td>
        <td>
          <span className={`status ${statusTone(entry.status)}`} title={entry.state_text}>
            {entry.state_text}
          </span>
        </td>
        <td>{fmt(entry.started_at)}</td>
        {!running && <td>{fmt(entry.ended_at)}</td>}
        <td className="num">{duration}</td>
        <td className="num">{rowsText(entry.counts.source_success, entry.counts.source_failed)}</td>
        <td className="num">{rowsText(entry.counts.target_success, entry.counts.target_failed)}</td>
        <td>{entry.run_context || "-"}{entry.started_by !== "" ? ` (${entry.started_by})` : ""}</td>
        <td className="errors-cell">{entry.error || "-"}</td>
      </tr>
      {open &&
        entry.children.map((child, i) => (
          <EntryRows
            key={`${rowKey}-${String(i)}`}
            entry={child}
            nowMs={nowMs}
            running={running}
            depth={depth + 1}
            rowKey={`${rowKey}-${String(i)}`}
          />
        ))}
    </>
  );
}

function EntryTable({
  entries,
  nowMs,
  running,
  testId,
}: {
  entries: MonitorEntry[];
  nowMs: number;
  running: boolean;
  testId: string;
}): React.JSX.Element {
  return (
    <div className="table-wrap">
      <table className="monitor" data-testid={testId}>
        <thead>
          <tr>
            <th>Task</th>
            <th>Type</th>
            <th>Status</th>
            <th>Started</th>
            {!running && <th>Ended</th>}
            <th>{running ? "Running for" : "Duration"}</th>
            <th>Source rows</th>
            <th>Target rows</th>
            <th>Started by</th>
            <th>Error</th>
          </tr>
        </thead>
        <tbody>
          {entries.map((e, i) => {
            const key = `${running ? "run" : "hist"}-${e.run_id ?? "x"}-${String(i)}`;
            return <EntryRows key={key} entry={e} nowMs={nowMs} running={running} depth={0} rowKey={key} />;
          })}
        </tbody>
      </table>
    </div>
  );
}

export function MonitorPanel({ active }: { active: boolean }): React.JSX.Element {
  const [snapshot, setSnapshot] = useState<MonitorSnapshot | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [paused, setPaused] = useState<boolean>(false);
  const [stopped, setStopped] = useState<boolean>(false); // hard stop after a 429
  const [onlyMine, setOnlyMine] = useState<boolean>(true);
  const [loading, setLoading] = useState<boolean>(false);
  const [nowMs, setNowMs] = useState<number>(() => Date.now());

  const load = useCallback((): void => {
    setLoading(true);
    monitorApi
      .get(onlyMine)
      .then((next) => {
        setSnapshot(next);
        setError(null);
      })
      .catch((err: unknown) => {
        setError(errorText(err));
        if (err instanceof ApiError && err.status === 429) setStopped(true);
      })
      .finally(() => setLoading(false));
  }, [onlyMine]);

  // Load when the tab is shown, then every REFRESH_MS unless paused / stopped / hidden.
  useEffect(() => {
    if (!active || stopped) return;
    load();
    if (paused) return;
    const timer = window.setInterval(load, REFRESH_MS);
    return () => window.clearInterval(timer);
  }, [active, paused, stopped, load]);

  // Tick once a second so "Running for" counts up between refreshes.
  useEffect(() => {
    if (!active) return;
    const timer = window.setInterval(() => setNowMs(Date.now()), 1000);
    return () => window.clearInterval(timer);
  }, [active]);

  const history = snapshot === null ? { ok: 0, failed: 0, other: 0 } : summarize(snapshot.recent);

  return (
    <div className="monitor-panel" data-testid="monitor-panel">
      <section className="detail">
        <div className="picker-head">
          <h2>CDI Monitor</h2>
          <div className="toolbar">
            <Button
              aria-label={paused ? "Resume auto-refresh" : "Pause auto-refresh"}
              data-testid="monitor-pause"
              disabled={stopped}
              onClick={() => setPaused(!paused)}
            >
              {paused ? "Resume" : "Pause"}
            </Button>
            <Button aria-label="Refresh monitor now" data-testid="monitor-refresh" disabled={loading} onClick={load}>
              {loading ? "Refreshing..." : "Refresh now"}
            </Button>
            <Button
              aria-label={onlyMine ? "Show all CDI jobs" : "Show only my tasks"}
              data-testid="monitor-scope"
              onClick={() => setOnlyMine(!onlyMine)}
            >
              {onlyMine ? "Showing: my tasks" : "Showing: all jobs"}
            </Button>
          </div>
        </div>
        <p className="muted" data-testid="monitor-status-line">
          {snapshot === null
            ? "Loading from IDMC..."
            : `As of ${new Date(snapshot.as_of).toLocaleTimeString()} - ${String(snapshot.my_task_count)} tasks in my list - `}
          {stopped ? "auto-refresh stopped (rate limited)" : paused ? "auto-refresh paused" : "auto-refresh every 15 s"}
        </p>
        {error !== null && (
          <p className="warn-text" data-testid="monitor-error">
            {error}
          </p>
        )}
        {snapshot?.notes.map((note) => (
          <p key={note} className="warn-text">
            {note}
          </p>
        ))}
      </section>

      <section className="detail" aria-label="Running now">
        <h2>Running now ({snapshot === null ? "-" : String(snapshot.running.length)})</h2>
        {snapshot !== null && snapshot.running.length === 0 ? (
          <p className="muted">Nothing running.</p>
        ) : (
          snapshot !== null && (
            <EntryTable entries={snapshot.running} nowMs={nowMs} running testId="monitor-running" />
          )
        )}
      </section>

      <section className="detail" aria-label="Recent history">
        <h2>
          Recent history ({snapshot === null ? "-" : String(snapshot.recent.length)}) - {String(history.ok)} success,{" "}
          {String(history.failed)} failed, {String(history.other)} other
        </h2>
        {snapshot !== null && snapshot.recent.length === 0 ? (
          <p className="muted">No finished runs in the activity log window.</p>
        ) : (
          snapshot !== null && (
            <EntryTable entries={snapshot.recent} nowMs={nowMs} running={false} testId="monitor-history" />
          )
        )}
      </section>

      <section className="detail" aria-label="Started from this app">
        <h2>Started from this app ({snapshot === null ? "-" : String(snapshot.app_runs.length)})</h2>
        {snapshot !== null && snapshot.app_runs.length === 0 ? (
          <p className="muted">No CDI runs started from this backend since it was started.</p>
        ) : (
          <ul className="app-runs" data-testid="monitor-app-runs">
            {snapshot?.app_runs.map((r) => (
              <li key={r.run_key}>
                <span className={`status ${statusTone(r.status)}`}>{r.status}</span> {r.job_name} ({r.job_kind}) -
                requested {fmt(r.started_at)}
                {r.ended_at === null ? ` - running for ${elapsedText(r.started_at, nowMs)}` : ` - ended ${fmt(r.ended_at)}`}
                {r.errors.length > 0 && <span className="errors-cell"> - {r.errors[r.errors.length - 1]}</span>}
              </li>
            ))}
          </ul>
        )}
      </section>
    </div>
  );
}
