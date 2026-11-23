// Taskflows tab: run an advanced taskflow BY NAME (with its input fields, e.g. jobInstanceId),
// then follow its runs: started at, ticking "running for", status, and once
// final the per-child summary (rows ok / failed, errors) plus a session log viewer per child.
// The URL /taskflows/runs/:runId is the tracked run, so a reload or a shared link keeps it.
// Polls every 15 s (shared/poll.ts) until final; a 429 stops polling for good.
// 0.9.1 (Vamsi 2026-11-23 00:15-00:19 CST): three tabs, each showing only its own part.
//   Run         = taskflow list + input fields + Run (master, 100% width), and below it the run
//                 history of the picked taskflow (detail, 100% width, running first) with a
//                 Summary and a Session log link per run. A start stays on Run (parallel starts
//                 allowed) and the new run is put on top of the history at once.
//   Summary     = the selected run: status, progress bar, poll clock, times, Last refresh,
//                 Abort while running, per child rows ok / failed and errors.
//   Session log = the selected run's child task logs (pick the child).
// The Track run id tab was removed at his request (2026-11-23).

import { useCallback, useEffect, useMemo, useState } from "react";
import { Button } from "@ui-sdk/react/button";
import { Input } from "@ui-sdk/react/input";
import { Listbox, ListboxItem } from "@ui-sdk/react/listbox";
import { ApiError, errorText } from "../shared/api";
import { catalog } from "../shared/catalog";
import { RunProgress } from "../shared/RunProgress";
import { statusTone } from "../shared/run";
import { onPickTaskflow } from "../shell/search";
import { ribbonTab, selectRibbonTab, useRibbonTab } from "../shell/sections";
import type { Route } from "../shared/routes";
import type { CdiTask } from "./cdiApi";
import { elapsedText, minutesText } from "./monitorApi";
import {
  announceTaskflowStart,
  mergeStarted,
  onTaskflowStart,
  startedRow,
  type HistoryRow,
  type TaskflowHistory,
  DEFAULT_PARAM_KEY,
  DEFAULT_PARAM_VALUE,
  paramsOf,
  statusLabel,
  taskflowApi,
  type ParamRow,
  type SubtaskRun,
  type TaskflowRunStatus,
} from "./taskflowApi";
import { POLL_MS, POLL_SECONDS } from "../shared/poll";


function fmt(value: string | null): string {
  return value === null ? "-" : new Date(value).toLocaleString();
}

function num(value: number | null): string {
  return value === null ? "-" : value.toLocaleString();
}

function okFailed(ok: number | null, failed: number | null): string {
  return `${num(ok)} ok / ${num(failed)} failed`;
}

interface Props {
  route: Route;
  go: (route: Route) => void;
  active: boolean;
}

export function TaskflowsPanel({ route, go, active }: Props): React.JSX.Element {
  const runId = route.screen === "taskflows" ? route.runId : null;
  const tab = useRibbonTab("cdi-taskflows");

  // ---- taskflow list + run by name ----
  const [taskflows, setTaskflows] = useState<CdiTask[]>([]);
  const [listError, setListError] = useState<string | null>(null);
  const [picked, setPicked] = useState<string | null>(null);
  const [params, setParams] = useState<ParamRow[]>([
    { key: DEFAULT_PARAM_KEY, value: DEFAULT_PARAM_VALUE },
  ]);
  const [starting, setStarting] = useState<boolean>(false);
  const [startError, setStartError] = useState<string | null>(null);

  useEffect(() => {
    if (!active || taskflows.length > 0) return;
    catalog.tasks
      .read()
      .then((all) => setTaskflows(all.filter((t) => t.type === "TASKFLOW")))
      .catch((err: unknown) => setListError(errorText(err)));
  }, [active, taskflows.length]);

  // A press on a taskflow in the left-pane search picks it here and opens the Run tab.
  useEffect(
    () =>
      onPickTaskflow((name) => {
        setPicked(name);
        selectRibbonTab("cdi-taskflows", "run");
      }),
    [],
  );

  const runPicked = useCallback((): void => {
    if (picked === null) return;
    const body = paramsOf(params);
    const shown = Object.entries(body)
      .map(([k, v]) => `${k}=${v}`)
      .join(", ");
    if (!window.confirm(`Start taskflow ${picked} with ${shown || "no input fields"}?`)) return;
    setStarting(true);
    setStartError(null);
    taskflowApi
      .runByName(picked, null, body)
      .then((started) => {
        // 0.9.1 (his 00:17 CST correction): stay on Run - he starts runs in parallel. The new
        // run goes on top of the history at once; a click on its row opens Track run id.
        announceTaskflowStart(started);
      })
      .catch((err: unknown) => setStartError(errorText(err)))
      .finally(() => setStarting(false));
  }, [picked, params]);

  // ---- run history of the picked taskflow (detail pane under the Run form) ----
  const [history, setHistory] = useState<TaskflowHistory | null>(null);
  const [localStarts, setLocalStarts] = useState<HistoryRow[]>([]);
  const [histError, setHistError] = useState<string | null>(null);
  const [histStopped, setHistStopped] = useState<boolean>(false);
  const [histPolls, setHistPolls] = useState<number>(0);
  const [histRefreshAt, setHistRefreshAt] = useState<Date | null>(null);

  useEffect(
    () =>
      onTaskflowStart((started) => {
        setLocalStarts((rows) => [startedRow(started), ...rows]);
      }),
    [],
  );

  useEffect(() => {
    setHistory(null);
    setHistError(null);
    setHistPolls(0);
    setHistRefreshAt(null);
  }, [picked]);

  useEffect(() => {
    if (picked === null || !active || tab !== "run" || histStopped) return;
    let cancelled = false;
    let timer: number | undefined;
    const load = (): void => {
      taskflowApi
        .history(picked)
        .then((next) => {
          if (cancelled) return;
          setHistory(next);
          setHistPolls((n) => n + 1);
          setHistRefreshAt(new Date());
          setHistError(null);
          timer = window.setTimeout(load, POLL_MS);
        })
        .catch((err: unknown) => {
          if (cancelled) return;
          setHistError(errorText(err));
          if (err instanceof ApiError && err.status === 429) setHistStopped(true);
          else timer = window.setTimeout(load, POLL_MS);
        });
    };
    load();
    return () => {
      cancelled = true;
      window.clearTimeout(timer);
    };
  }, [picked, active, tab, histStopped]);

  const historyRows = useMemo(
    () =>
      mergeStarted(
        history?.rows ?? [],
        localStarts.filter((r) => r.task_name === picked),
      ),
    [history, localStarts, picked],
  );

  const openRun = useCallback(
    (row: HistoryRow, where: "summary" | "log"): void => {
      if (!row.trackable || row.run_id === null) return;
      go({ screen: "taskflows", service: "cdi", runId: row.run_id });
      selectRibbonTab("cdi-taskflows", where);
    },
    [go],
  );

  // ---- tracking one run id ----
  const [status, setStatus] = useState<TaskflowRunStatus | null>(null);
  const [pollError, setPollError] = useState<string | null>(null);
  const [stopped, setStopped] = useState<boolean>(false);
  const [nowMs, setNowMs] = useState<number>(() => Date.now());
  const [polls, setPolls] = useState<number>(0);
  const [lastRefreshAt, setLastRefreshAt] = useState<Date | null>(null);
  const [logFor, setLogFor] = useState<string | null>(null);
  const [logText, setLogText] = useState<string>("");

  useEffect(() => {
    setStatus(null);
    setPollError(null);
    setStopped(false);
    setPolls(0);
    setLastRefreshAt(null);
    setLogFor(null);
    setLogText("");
    setAbortNote(null);
    // A deep link /taskflows/runs/:id (or the agent's openTaskflowSummary) opens its Summary.
    if (runId !== null && ribbonTab("cdi-taskflows") === "run") {
      selectRibbonTab("cdi-taskflows", "summary");
    }
  }, [runId]);

  useEffect(() => {
    if (runId === null || !active || stopped) return;
    let cancelled = false;
    let timer: number | undefined;
    const poll = (): void => {
      taskflowApi
        .status(runId)
        .then((next) => {
          if (cancelled) return;
          setStatus(next);
          setPolls((n) => n + 1);
          setLastRefreshAt(new Date());
          setPollError(null);
          if (!next.is_final) timer = window.setTimeout(poll, POLL_MS);
        })
        .catch((err: unknown) => {
          if (cancelled) return;
          setPollError(errorText(err));
          if (err instanceof ApiError && err.status === 429) setStopped(true);
          else timer = window.setTimeout(poll, POLL_MS);
        });
    };
    poll();
    return () => {
      cancelled = true;
      window.clearTimeout(timer);
    };
  }, [runId, active, stopped]);

  const running = status !== null && !status.is_final;
  useEffect(() => {
    if (!running) return;
    const tick = window.setInterval(() => setNowMs(Date.now()), 1000);
    return () => window.clearInterval(tick);
  }, [running]);

  const openLog = useCallback(
    (child: SubtaskRun): void => {
      if (runId === null) return;
      setLogFor(child.name);
      setLogText("Loading session log...");
      taskflowApi
        .sessionLog(runId, child.name)
        .then(setLogText)
        .catch((err: unknown) => setLogText(`Session log unavailable: ${errorText(err)}`));
    },
    [runId],
  );

  const [aborting, setAborting] = useState<boolean>(false);
  const [abortNote, setAbortNote] = useState<string | null>(null);
  const abortRun = useCallback((): void => {
    if (runId === null) return;
    if (!window.confirm(`Terminate (abort) taskflow run ${runId}? This stops the live run.`)) return;
    setAborting(true);
    setAbortNote(null);
    taskflowApi
      .terminate(runId)
      .then((result) => {
        setAbortNote(result.note);
        setStopped(false);
      })
      .catch((err: unknown) => setAbortNote(`Abort failed: ${errorText(err)}`))
      .finally(() => setAborting(false));
  }, [runId]);


  const header =
    status === null ? null : (
      <>
        <h2>{status.taskflow_name || "(taskflow name not reported)"}</h2>
        <p>
          Run id <code data-testid="tf-run-id">{status.run_id}</code>{" "}
          <span
            className={`status ${status.aborted ? "aborted" : statusTone(status.status)}`}
            data-testid="tf-status"
            data-aborted={status.aborted ? "true" : "false"}
            title={status.aborted ? "Terminated by a person; IDMC reports it as FAILED" : status.state_text}
          >
            {statusLabel(status)}
          </span>
        </p>
      </>
    );

  const loadingOrError = (
    <>
      {runId !== null && status === null && pollError === null && (
        <p className="muted">Loading run {runId}...</p>
      )}
      {pollError !== null && (
        <p className="warn-text" data-testid="tf-poll-error">
          {pollError}
          {stopped ? " (auto-refresh stopped: rate limited)" : ""}
        </p>
      )}
    </>
  );

  const noRun = (
    <p className="muted" data-testid="tf-no-run">
      No run selected yet. On the Run tab, pick a taskflow, scroll to its run history and press
      Summary or Session log on a run.
    </p>
  );

  return (
    <div className="panel tf-panel" data-testid="taskflows-panel" data-tab={tab}>
      {tab === "run" && (
        <section className="picker" aria-label="Run taskflow by name">
          <div className="tf-run-box" data-testid="tf-run-box">
            <h2>Run taskflow by name</h2>
            {listError !== null && (
              <p className="warn-text" data-testid="tf-list-error">
                {listError}
              </p>
            )}
            <Listbox
              aria-label="Taskflow list"
              data-testid="tf-list"
              value={picked}
              onValueChange={(value) => setPicked(value)}
            >
              {taskflows.map((t) => (
                <ListboxItem key={t.id} value={t.name} data-testid={`tf-item-${t.name}`} title={t.path}>
                  <span className="tf-name">{t.name}</span>
                  <span className="tf-path">{t.path.slice(0, Math.max(0, t.path.length - t.name.length - 1))}</span>
                </ListboxItem>
              ))}
            </Listbox>
            {picked === null && <p className="muted">Pick a taskflow to see its input fields and the Run button.</p>}
            {picked !== null && (
              <>
            <h3>Input fields (exact names, case-sensitive)</h3>
            {params.map((row, index) => (
              <div className="param-row" key={String(index)}>
                <Input
                  aria-label={`Input field name ${String(index + 1)}`}
                  data-testid={`tf-param-key-${String(index)}`}
                  value={row.key}
                  onValueChange={(value) =>
                    setParams(params.map((r, i) => (i === index ? { ...r, key: value ?? "" } : r)))
                  }
                />
                <Input
                  aria-label={`Input field value ${String(index + 1)}`}
                  data-testid={`tf-param-value-${String(index)}`}
                  value={row.value}
                  onValueChange={(value) =>
                    setParams(params.map((r, i) => (i === index ? { ...r, value: value ?? "" } : r)))
                  }
                />
              </div>
            ))}
            <Button
              aria-label="Add input field"
              data-testid="tf-param-add"
              onClick={() => setParams([...params, { key: "", value: "" }])}
            >
              Add field
            </Button>
            <Button
              aria-label={picked === null ? "Pick a taskflow first" : `Run ${picked}`}
              data-testid="tf-run"
              data-agent-confirm={`Starts taskflow ${picked ?? "(none picked)"} on the live IDMC org`}
              disabled={picked === null || starting}
              onClick={runPicked}
            >
              {starting ? "Starting..." : "Run"}
            </Button>
              </>
            )}
            {startError !== null && (
              <p className="warn-text" data-testid="tf-start-error">
                {startError}
              </p>
            )}
            <p className="muted">
              Runs can be started in parallel. Each accepted run appears on top of the history below;
              click a taskflow row to follow it on Track run id.
            </p>
          </div>
        </section>
      )}

      {tab === "run" && (
        <section className="detail tf-history" aria-label="Run history" data-testid="tf-history">
          <h2>Run history{picked !== null ? `: ${picked}` : ""}</h2>
          {picked === null && <p className="muted">Pick a taskflow above to see its runs.</p>}
          {picked !== null && (
            <p className="muted last-refresh" data-testid="tf-history-refresh">
              Last refresh: {histRefreshAt === null ? "-" : histRefreshAt.toLocaleTimeString()}
              {histStopped ? " (auto-refresh stopped: rate limited)" : ` (every ${String(POLL_SECONDS)} s, ${String(histPolls)} checks)`}
            </p>
          )}
          {histError !== null && (
            <p className="warn-text" data-testid="tf-history-error">
              {histError}
            </p>
          )}
          {picked !== null && history === null && histError === null && localStarts.length === 0 && (
            <p className="muted">Loading run history...</p>
          )}
          {(history?.notes ?? []).map((note) => (
            <p className="muted" key={note} data-testid="tf-history-note">
              {note}
            </p>
          ))}
          {picked !== null && (
            <div className="table-wrap"><table className="monitor tf-history-table" data-testid="tf-history-table">
              <thead>
                <tr>
                  <th>Run id</th>
                  <th>What</th>
                  <th>Status</th>
                  <th>Started</th>
                  <th>Ended</th>
                  <th>Minutes</th>
                  <th>Rows ok / failed</th>
                  <th>Error</th>
                  <th>Open</th>
                </tr>
              </thead>
              <tbody>
                {historyRows.map((row, index) => (
                  <tr
                    key={`${row.level}-${row.task_name}-${row.run_id ?? "none"}-${String(index)}`}
                    data-testid={row.trackable ? `tf-history-row-${row.run_id ?? ""}` : `tf-history-child-${String(index)}`}
                    data-running={row.is_running ? "true" : "false"}
                    data-trackable={row.trackable ? "true" : "false"}
                    title={row.trackable ? "Taskflow run id" : "Child task run number - not a taskflow run id"}
                  >
                    <td className="nowrap"><code>{row.run_id ?? "-"}</code></td>
                    <td className="nowrap">
                      {row.level === "taskflow" ? "Taskflow" : `Child ${row.task_name}`}
                      {row.source === "app" ? " (started here)" : ""}
                    </td>
                    <td>
                      <span className={`status ${statusTone(row.status)}`} title={row.state_text}>
                        {row.is_running ? `RUNNING - ${row.state_text}` : row.state_text}
                      </span>
                    </td>
                    <td className="nowrap">{fmt(row.started_at)}</td>
                    <td className="nowrap">{fmt(row.ended_at)}</td>
                    <td className="num">{minutesText(row.elapsed_minutes)}</td>
                    <td className="num">{okFailed(row.rows_ok, row.rows_failed)}</td>
                    <td className="errors-cell">{row.error || "-"}</td>
                    <td className="nowrap">
                      {row.trackable && row.run_id !== null ? (
                        <>
                          <a
                            href={`/taskflows/runs/${row.run_id}`}
                            data-testid={`tf-history-summary-${row.run_id}`}
                            onClick={(e) => {
                              e.preventDefault();
                              openRun(row, "summary");
                            }}
                          >
                            Summary
                          </a>
                          {" | "}
                          <a
                            href={`/taskflows/runs/${row.run_id}`}
                            data-testid={`tf-history-log-${row.run_id}`}
                            onClick={(e) => {
                              e.preventDefault();
                              openRun(row, "log");
                            }}
                          >
                            Session log
                          </a>
                        </>
                      ) : (
                        <span className="muted" title="IDMC lists this child task run without its taskflow run id">
                          see its taskflow run
                        </span>
                      )}
                    </td>
                  </tr>
                ))}
                {historyRows.length === 0 && history !== null && (
                  <tr>
                    <td colSpan={9} className="muted">No runs of this taskflow or its child tasks in the recent history.</td>
                  </tr>
                )}
              </tbody>
            </table></div>
          )}
        </section>
      )}

      {tab === "summary" && (
        <section className="detail" aria-label="Taskflow run">
          {runId === null && noRun}
          {loadingOrError}
          {status !== null && (
            <div className="run-box" data-testid="tf-run-view" data-status={status.status}>
              <span hidden data-testid="tf-summary" />
              {header}
              <RunProgress
                final={status.is_final}
                tone={status.aborted ? "warn" : statusTone(status.status)}
                label={`Progress of taskflow run ${status.run_id}`}
                detail={
                  status.subtasks.length === 0
                    ? "no child steps reported yet"
                    : `${String(status.subtasks.filter((c) => c.status === "SUCCESS").length)} of ${String(status.subtask_count ?? status.subtasks.length)} child steps done, ${status.totals.source_success.toLocaleString()} source rows ok`
                }
                polls={polls}
                everySeconds={POLL_SECONDS}
              />
              <p className="muted last-refresh" data-testid="tf-last-refresh">
                Last refresh: {lastRefreshAt === null ? "-" : lastRefreshAt.toLocaleTimeString()}
                {status.is_final ? " (final, checks stopped)" : ` (every ${String(POLL_SECONDS)} s)`}
              </p>
              {running && (
                <Button
                  aria-label={`Abort taskflow run ${status.run_id}`}
                  data-testid="tf-abort"
                  data-agent-confirm={`Terminates (aborts) taskflow run ${status.run_id} on the live IDMC org`}
                  disabled={aborting}
                  onClick={abortRun}
                >
                  {aborting ? "Aborting..." : "Abort run"}
                </Button>
              )}
              {abortNote !== null && (
                <p className="muted" data-testid="tf-abort-note">
                  {abortNote}
                </p>
              )}
              <p data-testid="tf-times">
                Started {fmt(status.started_at)}
                {running
                  ? ` - running for ${elapsedText(status.started_at, nowMs)}`
                  : ` - ended ${fmt(status.ended_at)} (${minutesText(status.elapsed_minutes)})`}
                {status.started_by !== "" ? ` - by ${status.started_by}` : ""}
              </p>
              {status.error !== "" && (
                <p className="warn-text" data-testid="tf-error">
                  {status.error}
                </p>
              )}
              {status.notes.map((note) => (
                <p className="muted" key={note} data-testid="tf-note">
                  {note}
                </p>
              ))}
              <h3>Child tasks</h3>
              <div className="table-wrap"><table className="monitor" data-testid="tf-subtasks">
                <thead>
                  <tr>
                    <th>Child task</th>
                    <th>Status</th>
                    <th>Started</th>
                    <th>Duration</th>
                    <th>Rows ok / error</th>
                    <th>Source</th>
                    <th>Target</th>
                    <th>Error</th>
                    <th>Log</th>
                  </tr>
                </thead>
                <tbody>
                  {status.subtasks.map((child, index) => (
                    <tr key={`${child.name}-${String(index)}`} data-testid={`tf-child-${child.name}`}>
                      <td>
                        {child.name} <span className="item-tag dim">{child.type}</span>
                      </td>
                      <td>
                        <span className={`status ${statusTone(child.status)}`} title={child.state_text}>
                          {child.state_text}
                        </span>
                      </td>
                      <td>{fmt(child.started_at)}</td>
                      <td className="num">{minutesText(child.elapsed_minutes)}</td>
                      <td className="num">{okFailed(child.success_rows, child.error_rows)}</td>
                      <td className="num">{okFailed(child.rows.source_success, child.rows.source_failed)}</td>
                      <td className="num">{okFailed(child.rows.target_success, child.rows.target_failed)}</td>
                      <td className="errors-cell">{child.error || "-"}</td>
                      <td>
                        <Button
                          aria-label={`Open session log of ${child.name}`}
                          data-testid={`tf-sum-log-${child.name}`}
                          disabled={child.log_entry_id === null}
                          onClick={() => {
                            openLog(child);
                            selectRibbonTab("cdi-taskflows", "log");
                          }}
                        >
                          Open log
                        </Button>
                      </td>
                    </tr>
                  ))}
                  {status.subtasks.length === 0 && (
                    <tr>
                      <td colSpan={9} className="muted">
                        {running ? "Child tasks appear as they start." : "No child task details."}
                      </td>
                    </tr>
                  )}
                </tbody>
                {status.is_final && status.subtasks.length > 0 && (
                  <tfoot>
                    <tr data-testid="tf-totals">
                      <td colSpan={4}>Totals</td>
                      <td className="num">{okFailed(status.totals.success_rows, status.totals.error_rows)}</td>
                      <td className="num">
                        {okFailed(status.totals.source_success, status.totals.source_failed)}
                      </td>
                      <td className="num">
                        {okFailed(status.totals.target_success, status.totals.target_failed)}
                      </td>
                      <td colSpan={2} />
                    </tr>
                  </tfoot>
                )}
              </table></div>
            </div>
          )}
        </section>
      )}

      {tab === "log" && (
        <section className="detail" aria-label="Taskflow session log">
          {runId === null && noRun}
          {loadingOrError}
          {status !== null && (
            <div className="run-box" data-testid="tf-log-pane">
              {header}
              {status.subtasks.length === 0 && (
                <p className="muted">{running ? "Child tasks appear as they start." : "No child task details."}</p>
              )}
              <div className="tf-log-buttons">
                {status.subtasks.map((child, index) => (
                  <Button
                    key={`${child.name}-${String(index)}`}
                    aria-label={`Session log of ${child.name}`}
                    data-testid={`tf-log-${child.name}`}
                    disabled={child.log_entry_id === null}
                    onClick={() => openLog(child)}
                  >
                    {child.name}
                  </Button>
                ))}
              </div>
              {logFor !== null && (
                <div data-testid="tf-log-viewer">
                  <h3>Session log: {logFor}</h3>
                  <pre className="log-box">{logText}</pre>
                </div>
              )}
            </div>
          )}
        </section>
      )}
    </div>
  );
}
