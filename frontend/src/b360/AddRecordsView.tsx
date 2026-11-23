// B360 Data "Add records" tab (0.9.8). Vamsi, voice 2026-11-23 01:05-01:10 CST:
//   "either I can type the data there, otherwise I can ask you to generate some test data ...
//    a box for number of test data ... use the data faker ... show me a form based on the
//    metadata ... Pydantic ... then say save which will make a REST API call to save it."
// Two modes, stacked full width:
//   Type it:  a form built from the backend's dynamic Pydantic model (form-schema). Save = one
//             Create Master Record call.
//   Generate: Number of records (1-100) -> Faker rows from the backend (preview, nothing sent),
//             editable / removable, then Send to B360 = one call per row, in order.
// Source system: dropdown of [sources] allowed in backend/b360_entities.toml (default zlv_ttf).
// Every write asks the person to confirm first. 429 / 401 / 403 stop the send; never retried.

import { useEffect, useState } from "react";
import { Button } from "@ui-sdk/react/button";
import { errorText } from "../shared/api";
import type { CreateResult, FormField } from "./api-types";
import {
  b360Api,
  cleanValues,
  clampCount,
  MAX_ADD,
  missingRequired,
  parseInput,
  type CellValue,
  type CreateResponse,
  type FormSchema,
  type NewRecord,
  type SourceSystemList,
} from "./b360Api";

type Mode = "type" | "generate";

function FieldInput({
  field,
  value,
  onChange,
  testId,
}: {
  field: FormField;
  value: CellValue;
  onChange: (v: CellValue) => void;
  testId: string;
}): React.JSX.Element {
  if (field.input === "CHECKBOX") {
    return (
      <input
        type="checkbox"
        data-testid={testId}
        checked={value === true}
        onChange={(e) => onChange(e.target.checked)}
      />
    );
  }
  const kind =
    field.input === "DATE" ? "date" : field.input === "DATETIME" ? "datetime-local" : field.input === "TEXT" ? "text" : "number";
  return (
    <input
      type={kind}
      data-testid={testId}
      value={value === null || value === undefined ? "" : String(value)}
      step={field.input === "DECIMAL" ? "any" : undefined}
      onChange={(e) => onChange(parseInput(e.target.value, field.input))}
    />
  );
}

function ResultTable({ result }: { result: CreateResponse }): React.JSX.Element {
  return (
    <section className="b360-group" data-testid="b360-add-result">
      <h3>
        Sent to {result.source_system}: {result.created} created, {result.failed} failed, {result.not_sent} not sent
        {result.unknown > 0 ? `, ${result.unknown} unknown` : ""}
      </h3>
      {result.stopped_reason !== null && (
        <p className="warn-text" data-testid="b360-add-stopped">
          {result.stopped_reason}
        </p>
      )}
      <div className="table-wrap">
        <table className="monitor">
          <thead>
            <tr>
              <th>#</th>
              <th>sourcePKey</th>
              <th>Outcome</th>
              <th>businessId</th>
              <th>Needs approval</th>
              <th>Error</th>
            </tr>
          </thead>
          <tbody>
            {result.results.map((r: CreateResult) => (
              <tr key={r.index} data-testid={`b360-add-result-${r.index}`} data-outcome={r.outcome}>
                <td>{r.index + 1}</td>
                <td>
                  <code>{r.source_pkey}</code>
                </td>
                <td>{r.outcome}</td>
                <td>{r.business_id !== null && r.business_id !== undefined ? <code>{r.business_id}</code> : "-"}</td>
                <td>{r.approval_required === true ? "yes" : r.approval_required === false ? "no" : "-"}</td>
                <td className="errors-cell">{r.error ?? ""}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </section>
  );
}

export function AddRecordsView({ entity, onSaved }: { entity: string; onSaved: () => void }): React.JSX.Element {
  const [schema, setSchema] = useState<FormSchema | null>(null);
  const [sources, setSources] = useState<SourceSystemList | null>(null);
  const [source, setSource] = useState<string>("");
  const [mode, setMode] = useState<Mode>("type");
  const [form, setForm] = useState<Record<string, CellValue>>({});
  const [pkey, setPkey] = useState<string>("");
  const [countText, setCountText] = useState<string>("5");
  const [rows, setRows] = useState<NewRecord[]>([]);
  const [rules, setRules] = useState<string>("");
  const [busy, setBusy] = useState<boolean>(false);
  const [error, setError] = useState<string>("");
  const [result, setResult] = useState<CreateResponse | null>(null);

  useEffect(() => {
    let live = true;
    setError("");
    Promise.all([b360Api.formSchema(entity), b360Api.sourceSystems()])
      .then(([s, src]) => {
        if (!live) return;
        setSchema(s);
        setSources(src);
        setSource(src.default ?? src.allowed[0] ?? "");
      })
      .catch((err: unknown) => live && setError(errorText(err)));
    return () => {
      live = false;
    };
  }, [entity]);

  const send = (records: NewRecord[], what: string): void => {
    if (source === "" || records.length === 0) return;
    if (!window.confirm(`${what}: create ${records.length} record(s) in ${entity} with source system ${source} on the live B360 org?`))
      return;
    setBusy(true);
    setError("");
    b360Api
      .create(entity, { source_system: source, records })
      .then((r) => {
        setResult(r);
        if (r.created > 0) onSaved();
      })
      .catch((err: unknown) => setError(errorText(err)))
      .finally(() => setBusy(false));
  };

  if (schema === null || sources === null) {
    return (
      <div className="b360-add" data-testid="b360-add">
        {error !== "" ? <p className="warn-text" data-testid="b360-add-error">{error}</p> : <p className="muted">Loading the form...</p>}
      </div>
    );
  }

  const missing = missingRequired(schema.fields, form);

  return (
    <div className="b360-add" data-testid="b360-add">
      <section className="b360-group">
        <div className="toolbar">
          <label>
            Source system{" "}
            <select data-testid="b360-add-source" value={source} onChange={(e) => setSource(e.target.value)}>
              {sources.allowed.map((s) => (
                <option key={s} value={s}>
                  {s}
                </option>
              ))}
            </select>
          </label>
          <span className="muted small" data-testid="b360-add-discovery">
            {sources.discovery_note}
          </span>
        </div>
        {sources.allowed.length === 0 && (
          <p className="warn-text">No source systems allowed: add them under [sources] in backend/b360_entities.toml.</p>
        )}
        {sources.not_allowed.length > 0 && (
          <p className="muted small" data-testid="b360-add-not-allowed">
            Also found in IDMC: {sources.not_allowed.join(", ")} - add to b360_entities.toml to allow.
          </p>
        )}
        <div className="toolbar" role="tablist">
          <Button data-testid="b360-add-mode-type" aria-pressed={mode === "type"} onClick={() => setMode("type")}>
            Type it
          </Button>
          <Button data-testid="b360-add-mode-generate" aria-pressed={mode === "generate"} onClick={() => setMode("generate")}>
            Generate test data
          </Button>
        </div>
      </section>

      {error !== "" && (
        <p className="warn-text" data-testid="b360-add-error">
          {error}
        </p>
      )}

      {mode === "type" && (
        <section className="b360-group" data-testid="b360-add-form">
          <h3>
            New {schema.label} <span className="muted small">(form from Pydantic model {schema.model_name})</span>
          </h3>
          <table className="monitor kv">
            <tbody>
              {schema.fields.map((f) => (
                <tr key={f.name}>
                  <th>
                    {f.label}
                    {f.required ? " *" : ""} <code className="muted small">{f.name}</code>
                  </th>
                  <td>
                    <FieldInput
                      field={f}
                      value={form[f.name] ?? null}
                      testId={`b360-add-field-${f.name}`}
                      onChange={(v) => setForm((old) => ({ ...old, [f.name]: v }))}
                    />
                  </td>
                </tr>
              ))}
              <tr>
                <th>
                  sourcePKey <span className="muted small">(empty: TXMDM-yyyymmddHHMMSS-1)</span>
                </th>
                <td>
                  <input type="text" data-testid="b360-add-pkey" value={pkey} onChange={(e) => setPkey(e.target.value)} />
                </td>
              </tr>
            </tbody>
          </table>
          {schema.skipped_groups.length > 0 && (
            <p className="muted small">Field groups not in the form yet: {schema.skipped_groups.join(", ")}.</p>
          )}
          {missing.length > 0 && <p className="muted small">Required: {missing.join(", ")}</p>}
          <div className="toolbar">
            <Button
              data-testid="b360-add-save"
              data-agent-confirm={`Creates one ${entity} master record on the live B360 org`}
              disabled={busy || missing.length > 0 || source === ""}
              onClick={() =>
                send([{ source_pkey: pkey.trim() === "" ? null : pkey.trim(), values: cleanValues(form) }], "Save")
              }
            >
              {busy ? "Saving..." : "Save"}
            </Button>
            <Button data-testid="b360-add-clear-form" onClick={() => setForm({})} disabled={busy}>
              Clear form
            </Button>
          </div>
          <details>
            <summary className="muted small">Pydantic JSON schema</summary>
            <pre className="small" data-testid="b360-add-json-schema">
              {schema.json_schema_text}
            </pre>
          </details>
        </section>
      )}

      {mode === "generate" && (
        <section className="b360-group" data-testid="b360-add-generate">
          <div className="toolbar">
            <label>
              Number of records (1-{MAX_ADD}){" "}
              <input
                type="number"
                min={1}
                max={MAX_ADD}
                data-testid="b360-add-count"
                value={countText}
                onChange={(e) => setCountText(e.target.value)}
              />
            </label>
            <Button
              data-testid="b360-add-generate-btn"
              disabled={busy}
              onClick={() => {
                const n = clampCount(countText);
                setCountText(String(n));
                setBusy(true);
                setError("");
                b360Api
                  .generate(entity, n)
                  .then((g) => {
                    setRows(g.rows);
                    setRules(`Faker ${g.faker_version}: ` + g.rules.map((r) => `${r.field} = ${r.rule}`).join("; "));
                  })
                  .catch((err: unknown) => setError(errorText(err)))
                  .finally(() => setBusy(false));
              }}
            >
              Generate
            </Button>
            <Button
              data-testid="b360-add-send"
              data-agent-confirm={`Creates the previewed ${entity} master records on the live B360 org`}
              disabled={busy || rows.length === 0 || source === ""}
              onClick={() => send(rows, "Send to B360")}
            >
              {busy ? "Sending..." : `Send to B360 (${rows.length})`}
            </Button>
            <Button data-testid="b360-add-clear-preview" onClick={() => setRows([])} disabled={busy || rows.length === 0}>
              Clear preview
            </Button>
          </div>
          {rules !== "" && <p className="muted small" data-testid="b360-add-rules">{rules}</p>}
          {rows.length === 0 ? (
            <p className="muted">Preview is empty. Pick a number and press Generate; nothing is sent until Send to B360.</p>
          ) : (
            <div className="table-wrap">
              <table className="monitor" data-testid="b360-add-preview">
                <thead>
                  <tr>
                    <th>#</th>
                    <th>sourcePKey</th>
                    {schema.fields.map((f) => (
                      <th key={f.name}>
                        {f.name}
                        {f.required ? " *" : ""}
                      </th>
                    ))}
                    <th />
                  </tr>
                </thead>
                <tbody>
                  {rows.map((row, i) => (
                    <tr key={row.source_pkey ?? i} data-testid={`b360-add-row-${i}`}>
                      <td>{i + 1}</td>
                      <td>
                        <code>{row.source_pkey ?? ""}</code>
                      </td>
                      {schema.fields.map((f) => (
                        <td key={f.name}>
                          <FieldInput
                            field={f}
                            value={row.values[f.name] ?? null}
                            testId={`b360-add-cell-${i}-${f.name}`}
                            onChange={(v) =>
                              setRows((old) =>
                                old.map((r, j) => (j === i ? { ...r, values: { ...r.values, [f.name]: v } } : r)),
                              )
                            }
                          />
                        </td>
                      ))}
                      <td>
                        <Button data-testid={`b360-add-remove-${i}`} onClick={() => setRows((old) => old.filter((_, j) => j !== i))}>
                          Remove
                        </Button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </section>
      )}

      {result !== null && <ResultTable result={result} />}
    </div>
  );
}
