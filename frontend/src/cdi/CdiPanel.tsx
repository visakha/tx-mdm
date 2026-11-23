// CDI section: pick a task from the metadata list, run it, watch it.
// What is selected / shown is driven by the URL: /cdi/jobs, /cdi/jobs/:taskId, /cdi/runs/:runKey.

import { useCallback, useState } from "react";
import { Button } from "@ui-sdk/react/button";
import { Input } from "@ui-sdk/react/input";
import { Listbox, ListboxItem } from "@ui-sdk/react/listbox";
import { RunResult } from "../shared/RunResult";
import type { RunView } from "../shared/run";
import type { Route } from "../shared/routes";
import { catalog } from "../shared/catalog";
import { usePicker, useStarter } from "../shared/usePicker";
import { useRunPolling } from "../shared/useRunPolling";
import { CDI_TYPE_LABEL, cdiApi, type CdiTask } from "./cdiApi";

const idOf = (t: CdiTask): string => t.id;
const textOf = (t: CdiTask): string => `${t.path} ${t.type}`;

export function CdiPanel({
  route,
  go,
}: {
  route: Route;
  go: (route: Route) => void;
}): React.JSX.Element {
  const selectedId = route.screen === "job" ? route.jobId : null;
  const runKey = route.screen === "run" ? route.runKey : null;
  const picker = usePicker(catalog.tasks.read, idOf, textOf, selectedId);
  const onStarted = useCallback(
    (run: RunView) => go({ screen: "run", service: "cdi", runKey: run.run_key }),
    [go],
  );
  const starter = useStarter(onStarted);
  const { run, pollError, polls } = useRunPolling(runKey, cdiApi.runUrl);
  const [apiName, setApiName] = useState<string>("");

  const task = picker.selected;

  function runSelected(): void {
    if (task === undefined) return;
    starter.start(() =>
      cdiApi.startRun({
        task_id: task.id,
        task_type: task.type,
        task_name: task.name,
        api_name: task.type === "TASKFLOW" && apiName.trim() !== "" ? apiName.trim() : null,
      }),
    );
  }

  return (
    <div className="panel" data-testid="cdi-panel">
      <section className="picker" aria-label="CDI tasks">
        <div className="picker-head">
          <h2>CDI tasks</h2>
          <Button aria-label="Refresh CDI tasks" data-testid="cdi-refresh" onClick={picker.reload}>
            Refresh
          </Button>
        </div>
        <Input
          aria-label="Filter CDI tasks"
          data-testid="cdi-filter"
          placeholder="Filter by path or type"
          value={picker.filter}
          onValueChange={(value) => picker.setFilter(value ?? "")}
        />
        {picker.loading && <p className="muted">Loading tasks from IDMC...</p>}
        {picker.loadError !== null && (
          <p className="warn-text" data-testid="cdi-load-error">
            {picker.loadError}
          </p>
        )}
        <Listbox
          aria-label="CDI task list"
          data-testid="cdi-task-list"
          value={selectedId}
          onValueChange={(value) => {
            if (value !== null) go({ screen: "job", service: "cdi", jobId: value });
          }}
        >
          {picker.visible.map((t) => (
            <ListboxItem key={t.id} value={t.id} data-testid={`cdi-task-${t.id}`}>
              <span className="item-name">{t.path}</span>
              <span className="item-tag">{CDI_TYPE_LABEL[t.type]}</span>
            </ListboxItem>
          ))}
        </Listbox>
      </section>

      <section className="detail" aria-label="CDI detail">
        {route.screen === "jobs" && <p className="muted">Pick a task to run.</p>}
        {route.screen === "job" && task === undefined && !picker.loading && (
          <p className="warn-text">No CDI task with id {route.jobId}.</p>
        )}
        {route.screen === "job" && task !== undefined && (
          <div className="run-box" data-testid="cdi-task-detail">
            <h2>{task.name}</h2>
            <p className="muted">
              {CDI_TYPE_LABEL[task.type]} - {task.path}
            </p>
            {task.type === "TASKFLOW" && (
              <Input
                aria-label="Published API name"
                data-testid="cdi-api-name"
                placeholder={`Published API name (default: ${task.name})`}
                value={apiName}
                onValueChange={(value) => setApiName(value ?? "")}
              />
            )}
            <Button
              aria-label={`Run ${task.name}`}
              data-testid="cdi-run"
              data-agent-confirm={`Starts CDI task ${task.name} on the live IDMC org`}
              disabled={starter.starting}
              onClick={runSelected}
            >
              {starter.starting ? "Starting..." : "Run"}
            </Button>
            {starter.startError !== null && (
              <p className="warn-text" data-testid="cdi-start-error">
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
        {run !== null && <RunResult run={run} pollError={pollError} polls={polls} />}
      </section>
    </div>
  );
}
