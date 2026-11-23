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
// 0.9.10: tab is "Add records (S)" - every create goes in with a source system (a source record
// B360 merges into a master). Field groups (any group in the metadata, e.g. x_phone) are a
// repeatable block in the form and stacked, editable, removable rows under each preview record.
// Writes go at once on Save / Send (no pop-up, owner decision 01:53 CST); results show inline. 429 / 401 / 403 stop the send; never retried.

import { useEffect, useState } from "react";
import { Button } from "@ui-sdk/react/button";
import { errorText } from "../shared/api";
import type { CreateResult, NewGroupRow } from "./api-types";
import { Input } from "@ui-sdk/react/input";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@ui-sdk/react/select";
import { FieldGrid, FieldInput, FormLine, GroupRowsEditor } from "./GroupRowsEditor";
import {
  b360Api,
  cleanGroups,
  cleanValues,
  clampCount,
  MAX_ADD,
  addSaveBlockers,
  type CellValue,
  type CreateResponse,
  type FormSchema,
  type NewRecord,
  type SourceSystemList,
} from "./b360Api";

type Mode = "type" | "generate";

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
  const [formGroups, setFormGroups] = useState<Record<string, NewGroupRow[]>>({});
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
    // 0.9.10 (owner decision 2026-11-23 01:53 CST): no pop-up for persons or agents; the result
    // shows inline. `what` is kept for the call sites (form vs preview send).
    void what;
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

  const blockers = addSaveBlockers(source, schema.fields, form);

  return (
    <div className="b360-add" data-testid="b360-add">
      <section className="b360-group">
        <div className="toolbar">
          <label>
            Source system{" "}
            <Select items={sources.allowed} value={source} onValueChange={(v: string | null) => setSource(v ?? "")}>
              <SelectTrigger aria-label="Add records source system" data-testid="b360-add-source">
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {sources.allowed.map((s) => (
                  <SelectItem key={s} value={s}>
                    {s}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
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
          <Button aria-label="Add records mode Type it" data-testid="b360-add-mode-type" aria-pressed={mode === "type"} onClick={() => setMode("type")}>
            Type it
          </Button>
          <Button aria-label="Add records mode Generate test data" data-testid="b360-add-mode-generate" aria-pressed={mode === "generate"} onClick={() => setMode("generate")}>
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
          <FieldGrid
            fields={schema.fields}
            values={form}
            testIdPrefix="b360-add-field-"
            labelPrefix="Add form"
            ariaLabel="Add form fields"
            onChange={(name, v) => setForm((old) => ({ ...old, [name]: v }))}
            extra={
              <FormLine label="sourcePKey" name="(empty: TXMDM-yyyymmddHHMMSS-1)">
                <Input type="text" aria-label="Add form sourcePKey" data-testid="b360-add-pkey" value={pkey} onValueChange={(v: string) => setPkey(v)} />
              </FormLine>
            }
          />
          {(schema.groups ?? []).map((g) => (
            <GroupRowsEditor
              key={g.name}
              group={g}
              rows={formGroups[g.name] ?? []}
              testId={`b360-add-group-${g.name}`}
              scope="Add form"
              onChange={(next) => setFormGroups((old) => ({ ...old, [g.name]: next }))}
            />
          ))}
          {schema.picklist_note !== "" && <p className="muted small" data-testid="b360-add-picklist-note">{schema.picklist_note}</p>}
          {blockers.length > 0 && (
            <p className="muted small pending-hint" data-testid="b360-add-save-why">
              Save is disabled: {blockers.join("; ")}.
            </p>
          )}
          <div className="toolbar">
            <Button
              aria-label="Add form Save"
              data-testid="b360-add-save"
              data-agent-confirm={`Creates one ${entity} source record (and its master) on the live B360 org`}
              disabled={busy || blockers.length > 0}
              onClick={() =>
                send(
                  [
                    {
                      source_pkey: pkey.trim() === "" ? null : pkey.trim(),
                      values: cleanValues(form),
                      groups: cleanGroups((schema.groups ?? []).map((g) => ({ group: g.name, rows: formGroups[g.name] ?? [] }))),
                    },
                  ],
                  "Save",
                )
              }
            >
              {busy ? "Saving..." : "Save"}
            </Button>
            <Button
              aria-label="Add form Clear form"
              data-testid="b360-add-clear-form"
              onClick={() => {
                setForm({});
                setFormGroups({});
              }}
              disabled={busy}
            >
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
              <Input
                type="number"
                min={1}
                max={MAX_ADD}
                aria-label="Generate number of records"
                data-testid="b360-add-count"
                value={countText}
                onValueChange={(v: string) => setCountText(v)}
              />
            </label>
            <Button
              aria-label="Generate test rows"
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
              aria-label="Send to B360"
              data-testid="b360-add-send"
              data-agent-confirm={`Creates the previewed ${entity} source records (and their masters) on the live B360 org`}
              disabled={busy || rows.length === 0 || source === ""}
              onClick={() => send(rows.map((r) => ({ ...r, groups: cleanGroups(r.groups ?? []) })), "Send to B360")}
            >
              {busy ? "Sending..." : `Send to B360 (${rows.length})`}
            </Button>
            <Button aria-label="Clear preview" data-testid="b360-add-clear-preview" onClick={() => setRows([])} disabled={busy || rows.length === 0}>
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
                  {rows.map((row, i) => [
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
                            label={`Preview row ${String(i + 1)} ${f.label}`}
                            onChange={(v) =>
                              setRows((old) =>
                                old.map((r, j) => (j === i ? { ...r, values: { ...r.values, [f.name]: v } } : r)),
                              )
                            }
                          />
                        </td>
                      ))}
                      <td>
                        <Button aria-label={`Preview remove row ${String(i + 1)}`} data-testid={`b360-add-remove-${i}`} onClick={() => setRows((old) => old.filter((_, j) => j !== i))}>
                          Remove
                        </Button>
                      </td>
                    </tr>,
                    (schema.groups ?? []).length > 0 && (
                      <tr key={`${row.source_pkey ?? i}-groups`} className="group-rows-line">
                        <td />
                        <td colSpan={schema.fields.length + 2}>
                          {(schema.groups ?? []).map((g) => (
                            <GroupRowsEditor
                              key={g.name}
                              group={g}
                              rows={row.groups?.find((b) => b.group === g.name)?.rows ?? []}
                              testId={`b360-add-preview-${i}-${g.name}`}
                              scope={`Preview row ${String(i + 1)}`}
                              onChange={(next) =>
                                setRows((old) =>
                                  old.map((r, j) =>
                                    j === i
                                      ? {
                                          ...r,
                                          groups: [
                                            ...(r.groups ?? []).filter((b) => b.group !== g.name),
                                            { group: g.name, rows: next },
                                          ],
                                        }
                                      : r,
                                  ),
                                )
                              }
                            />
                          ))}
                        </td>
                      </tr>
                    ),
                  ])}
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
