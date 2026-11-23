// Business 360 (MDM) "Currently running" (Vamsi 2026-11-22 23:55 CST): every b360.* / c360.*
// job running in the org, not only runs this app started - the portal, another machine or
// another user count too. Plus recently finished jobs and a box to look up ANY job instance
// by its full id. Refreshes every POLL_SECONDS (15 s) with the shared progress bar, poll clock
// and a "Last refresh" line. A 429 stops auto-refresh for good. Read-only: nothing here starts
// or stops a job.

import { useCallback, useEffect, useState } from "react";
import { Button } from "@ui-sdk/react/button";
import { Input } from "@ui-sdk/react/input";
import { ApiError, errorText } from "../shared/api";
import { POLL_MS, POLL_SECONDS } from "../shared/poll";
import { isTerminal, statusTone } from "../shared/run";
import { PortalLink } from "../shared/PortalLink";
import { RunProgress } from "../shared/RunProgress";
import {
  cleanInstanceId,
  mdmMonitorApi,
  minutes,
  type MdmJobInstance,
  type MdmMonitorSnapshot,
} from "./mdmMonitorApi";

function fmt(value: string | null): string {
  return value === null ? "-" : new Date(value).toLocaleString();
}

function num(value: number | null): string {
  return value === null ? "-" : value.toLocaleString();
}

function elapsedNow(job: MdmJobInstance, nowMs: number): string {
  if (job.started_at === null) return "-";
  if (job.ended_at !== null || isTerminal(job.status)) return minutes(job.elapsed_minutes);
  return minutes(Math.max(0, (nowMs - new Date(job.started_at).getTime()) / 60000));
}

function JobTable({
  jobs,
  testId,
  nowMs,
  empty,
}: {
  jobs: readonly MdmJobInstance[];
  testId: string;
  nowMs: number;
  empty: string;
}): React.JSX.Element {
  if (jobs.length === 0) return <p className="muted" data-testid={`${testId}-empty`}>{empty}</p>;
  return (
    <div className="table-wrap">
      <table className="monitor b360-jobs" data-testid={testId}>
        <thead>
          <tr>
            <th>Instance id</th>
            <th>Job</th>
            <th>Type</th>
            <th>Status</th>
            <th>Started</th>
            <th>Elapsed</th>
            <th>Started by</th>
            <th>Rows in</th>
          </tr>
        </thead>
        <tbody>
          {jobs.map((job) => (
            <tr key={job.instance_id} data-testid={`b360-row-${job.instance_id}`} data-status={job.status}>
              <td className="instance-id">
                <PortalLink id={job.instance_id} url={job.portal_url} slug={testId} />
              </td>
              <td className="nowrap" title={job.job_definition_id}>{job.name || job.job_definition_id}</td>
              <td className="nowrap">{job.job_type}</td>
              <td>
                <span className={`status ${statusTone(job.status)}`}>{job.state_text}</span>
              </td>
              <td className="nowrap">{fmt(job.started_at)}</td>
              <td className="num">{elapsedNow(job, nowMs)}</td>
              <td className="nowrap">{job.started_by || "-"}</td>
              <td className="num">{num(job.counts.source_success)}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

export function MdmMonitorPanel({ active }: { active: boolean }): React.JSX.Element {
  const [snapshot, setSnapshot] = useState<MdmMonitorSnapshot | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [stopped, setStopped] = useState<boolean>(false);
  const [polls, setPolls] = useState<number>(0);
  const [lastRefreshAt, setLastRefreshAt] = useState<Date | null>(null);
  const [nowMs, setNowMs] = useState<number>(() => Date.now());
  const [lookupText, setLookupText] = useState<string>("");
  const [lookup, setLookup] = useState<MdmJobInstance | null>(null);
  const [lookupError, setLookupError] = useState<string | null>(null);

  const load = useCallback((): void => {
    mdmMonitorApi
      .get()
      .then((next) => {
        setSnapshot(next);
        setError(null);
        setPolls((n) => n + 1);
        setLastRefreshAt(new Date());
      })
      .catch((err: unknown) => {
        setError(errorText(err));
        if (err instanceof ApiError && err.status === 429) setStopped(true);
      });
  }, []);

  useEffect(() => {
    if (!active || stopped) return;
    load();
    const timer = window.setInterval(load, POLL_MS);
    return () => window.clearInterval(timer);
  }, [active, stopped, load]);

  useEffect(() => {
    if (!active) return;
    const timer = window.setInterval(() => setNowMs(Date.now()), 1000);
    return () => window.clearInterval(timer);
  }, [active]);

  const doLookup = (): void => {
    const id = cleanInstanceId(lookupText);
    if (id === "") return;
    setLookupError(null);
    mdmMonitorApi.lookup(id).then(setLookup, (err: unknown) => {
      setLookup(null);
      setLookupError(errorText(err));
    });
  };

  const runningCount = snapshot?.running.length ?? 0;
  return (
    <div className="b360-monitor" data-testid="b360-monitor">
      <section className="detail" aria-label="Currently running">
        <div className="picker-head">
          <h2>
            Business 360 - currently running <span className="count" data-testid="b360-running-count">{runningCount}</span>
          </h2>
          <Button aria-label="Refresh currently running now" data-testid="b360-refresh" disabled={stopped} onClick={load}>
            Refresh now
          </Button>
        </div>
        {/* Only rendered while shown: the other panes use the same run-progress / poll-clock ids. */}
        {active && (
        <RunProgress
          final={stopped}
          tone={stopped ? "bad" : "busy"}
          label="Currently running auto-refresh"
          detail={`${String(runningCount)} B360 job(s) running in the org, any starter`}
          polls={polls}
          everySeconds={POLL_SECONDS}
        />
        )}
        <p className="muted" data-testid="b360-last-refresh">
          Last refresh: {lastRefreshAt === null ? "-" : lastRefreshAt.toLocaleTimeString()}
          {stopped ? " (auto-refresh stopped: rate limited)" : ` (every ${String(POLL_SECONDS)} s)`}
        </p>
        {error !== null && <p className="warn-text" data-testid="b360-error">{error}</p>}
        <JobTable jobs={snapshot?.running ?? []} testId="b360-running" nowMs={nowMs} empty="No B360 job is running right now." />
      </section>

      <section className="detail" aria-label="Recently finished">
        <h3>Recently finished</h3>
        <JobTable jobs={snapshot?.recent ?? []} testId="b360-recent" nowMs={nowMs} empty="No finished B360 jobs in the recent page." />
        {snapshot !== null && snapshot.other_types_hidden > 0 && (
          <p className="muted">{snapshot.other_types_hidden} non-B360 job instance(s) (not b360.* / c360.*) not listed.</p>
        )}
      </section>

      <section className="detail" aria-label="Look up a job instance">
        <h3>Look up a job instance by id</h3>
        <div className="lookup-row">
          <Input
            aria-label="Job instance id"
            data-testid="b360-lookup-input"
            placeholder="Paste a full job instance id, e.g. 1309395637279657984"
            value={lookupText}
            onValueChange={(value) => setLookupText(value ?? "")}
          />
          <Button aria-label="Look up job instance" data-testid="b360-lookup" onClick={doLookup}>
            Look up
          </Button>
        </div>
        {lookupError !== null && <p className="warn-text" data-testid="b360-lookup-error">{lookupError}</p>}
        {lookup !== null && (
          <JobTable jobs={[lookup]} testId="b360-lookup-result" nowMs={nowMs} empty="" />
        )}
        {lookup !== null && lookup.errors.length > 0 && (
          <ul className="errors">
            {lookup.errors.map((e) => (
              <li key={e}>{e}</li>
            ))}
          </ul>
        )}
      </section>
    </div>
  );
}
