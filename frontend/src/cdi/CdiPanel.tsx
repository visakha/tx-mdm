// CDI section: pick a task from the metadata list, run it, watch it.

import { useState } from "react";
import { Button } from "@ui-sdk/react/button";
import { Input } from "@ui-sdk/react/input";
import { Listbox, ListboxItem } from "@ui-sdk/react/listbox";
import { RunResult } from "../shared/RunResult";
import { isTerminal } from "../shared/run";
import { usePicker, useStarter } from "../shared/usePicker";
import { useRunPolling } from "../shared/useRunPolling";
import { CDI_TYPE_LABEL, cdiApi, type CdiTask } from "./cdiApi";

const idOf = (t: CdiTask): string => t.id;
const textOf = (t: CdiTask): string => `${t.path} ${t.type}`;

export function CdiPanel(): React.JSX.Element {
  const picker = usePicker(cdiApi.listTasks, idOf, textOf);
  const starter = useStarter();
  const { run, pollError } = useRunPolling(starter.started, cdiApi.runUrl);
  const [apiName, setApiName] = useState<string>("");

  const task = picker.selected;
  const busy = starter.starting || (run !== null && !isTerminal(run.status));

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
    <div className="panel">
      <section className="picker" aria-label="CDI tasks">
        <div className="picker-head">
          <h2>CDI tasks</h2>
          <Button aria-label="Refresh CDI tasks" onClick={picker.reload}>
            Refresh
          </Button>
        </div>
        <Input
          aria-label="Filter CDI tasks"
          placeholder="Filter by path or type"
          value={picker.filter}
          onValueChange={(value) => picker.setFilter(value ?? "")}
        />
        {picker.loading && <p className="muted">Loading tasks from IDMC...</p>}
        {picker.loadError !== null && <p className="warn-text">{picker.loadError}</p>}
        <Listbox
          aria-label="CDI task list"
          value={task?.id ?? null}
          onValueChange={(value) => {
            if (value !== null) picker.select(value);
          }}
        >
          {picker.visible.map((t) => (
            <ListboxItem key={t.id} value={t.id}>
              <span className="item-name">{t.path}</span>
              <span className="item-tag">{CDI_TYPE_LABEL[t.type]}</span>
            </ListboxItem>
          ))}
        </Listbox>
      </section>

      <section className="detail" aria-label="CDI run">
        {task === undefined ? (
          <p className="muted">Pick a task to run.</p>
        ) : (
          <div className="run-box">
            <h2>{task.name}</h2>
            <p className="muted">
              {CDI_TYPE_LABEL[task.type]} · {task.path}
            </p>
            {task.type === "TASKFLOW" && (
              <Input
                aria-label="Published API name"
                placeholder={`Published API name (default: ${task.name})`}
                value={apiName}
                onValueChange={(value) => setApiName(value ?? "")}
              />
            )}
            <Button aria-label={`Run ${task.name}`} disabled={busy} onClick={runSelected}>
              {busy ? "Running..." : "Run"}
            </Button>
            {starter.startError !== null && <p className="warn-text">{starter.startError}</p>}
          </div>
        )}
        {run !== null && <RunResult run={run} pollError={pollError} />}
      </section>
    </div>
  );
}
