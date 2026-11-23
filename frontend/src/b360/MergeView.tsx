// 0.9.12 Merge (M). Vamsi 2026-11-23 02:21 CST: "merge 100000000000141 and 100000000000150 and
// let first name from 141 win, while last name from 150 win."
// Every control sits on a typed backend endpoint (API first):
//   Load    -> POST /merge/preview  (Read Master Record per id; read-only)
//   Merge   -> POST /merge          (Merge API p. 106, then Update Master Record Field pp. 67-68
//                                     for the picked winners only, then read back)
//   Undo    -> GET  /records/{id}/sources + POST /records/{id}/unmerge (Unmerge API pp. 107-110)
// Per field the winner defaults to "IDMC decides" (no override). clns_<x> follows x's winner.
// No pop-ups (owner decision 01:53 CST): Merge sends at once; data-agent-confirm is a label only.
// Agents may preview; merging is a person's button (like create).

import { useState } from "react";
import { Button } from "@ui-sdk/react/button";
import { Checkbox, CheckboxIndicator } from "@ui-sdk/react/checkbox";
import { Input } from "@ui-sdk/react/input";
import { Radio, RadioGroup, RadioIndicator } from "@ui-sdk/react/radio";
import { errorText } from "../shared/api";
import type { SourceKey } from "./api-types";
import { b360Api, parseBusinessIds, winnersToSend, type MergePreview, type MergeResponse, type SourceRecordList } from "./b360Api";

const IDMC_DECIDES = "";

function show(v: unknown): string {
  if (v === null || v === undefined || v === "") return "-";
  if (typeof v === "boolean") return v ? "Yes" : "No";
  return String(v);
}

const keyOf = (s: SourceKey): string => `${s.source_system}/${s.source_pkey}`;

export function MergeView({ entity, initialIds, onMerged }: { entity: string; initialIds: string; onMerged: () => void }): React.JSX.Element {
  const [idsText, setIdsText] = useState(initialIds);
  const [preview, setPreview] = useState<MergePreview | null>(null);
  const [picks, setPicks] = useState<Record<string, string>>({});
  const [result, setResult] = useState<MergeResponse | null>(null);
  const [sources, setSources] = useState<SourceRecordList | null>(null);
  const [undoPick, setUndoPick] = useState<string[]>([]);
  const [undoNote, setUndoNote] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");

  const ids = parseBusinessIds(idsText);
  const followers = new Set((preview?.rows ?? []).filter((r) => r.follows).map((r) => r.field));
  const previewMatches = preview !== null && preview.business_ids.join(" ") === ids.join(" ");
  const canMerge = previewMatches && (preview.missing ?? []).length === 0 && !busy;

  async function load(): Promise<void> {
    setBusy(true);
    setError("");
    setResult(null);
    setSources(null);
    try {
      const p = await b360Api.mergePreview(entity, ids);
      setPreview(p);
      setPicks(Object.fromEntries(p.rows.map((r) => [r.field, IDMC_DECIDES])));
    } catch (e) {
      setPreview(null);
      setError(errorText(e));
    } finally {
      setBusy(false);
    }
  }

  async function merge(): Promise<void> {
    if (preview === null) return;
    setBusy(true);
    setError("");
    try {
      const r = await b360Api.merge(entity, { business_ids: preview.business_ids, winners: winnersToSend(picks, followers) });
      setResult(r);
      onMerged();
    } catch (e) {
      setError(errorText(e));
    } finally {
      setBusy(false);
    }
  }

  async function loadSources(): Promise<void> {
    if (result?.surviving_business_id == null) return;
    setBusy(true);
    try {
      setSources(await b360Api.masterSources(entity, result.surviving_business_id));
      setUndoPick([]);
    } catch (e) {
      setError(errorText(e));
    } finally {
      setBusy(false);
    }
  }

  async function unmerge(): Promise<void> {
    if (result?.surviving_business_id == null || sources === null) return;
    const chosen = sources.members.filter((m) => undoPick.includes(keyOf(m)));
    setBusy(true);
    try {
      const r = await b360Api.unmerge(entity, result.surviving_business_id, { sources: chosen, allow_merge_back: false });
      setUndoNote(`${r.note} approvalRequired: ${show(r.approval_required)}`);
      onMerged();
    } catch (e) {
      setError(errorText(e));
    } finally {
      setBusy(false);
    }
  }

  return (
    <section className="b360-merge" data-testid="b360-merge" aria-label="Merge master records">
      <p className="muted">
        Merge 2-10 master records of {entity}. Pick a winner only for the fields you want to force; the rest stay with IDMC survivorship. clns_ fields follow their field.
      </p>
      <div className="row">
        <label>
          Business IDs{" "}
          <Input type="text" aria-label="Merge business IDs" data-testid="b360-merge-ids" value={idsText} onValueChange={(v: string) => setIdsText(v)} placeholder="100000000000141 100000000000150" />
        </label>
        <Button aria-label="Load records to merge" data-testid="b360-merge-load" onClick={() => void load()} disabled={busy || ids.length < 2}>
          Load
        </Button>
        <span className="muted">{ids.length} id(s)</span>
      </div>
      {error !== "" && <p className="warn-text" data-testid="b360-merge-error">{error}</p>}
      {preview !== null && <p className="muted" data-testid="b360-merge-note">{preview.note}</p>}

      {preview !== null && (
        <div className="table-wrap">
          <table className="monitor" data-testid="b360-merge-table" aria-label="Merge field winners">
            <thead>
              <tr>
                <th>Field</th>
                {preview.business_ids.map((id) => (
                  <th key={id}>{id}</th>
                ))}
                <th>Winner</th>
              </tr>
            </thead>
            <tbody>
              {preview.rows.map((row) => (
                <tr key={row.field} data-testid={`b360-merge-row-${row.field}`}>
                  <td>
                    {row.label} <span className="muted">({row.field})</span>
                  </td>
                  {preview.business_ids.map((id) => (
                    <td key={id} className={picks[row.field] === id || (row.follows && picks[row.follows] === id) ? "pick" : undefined}>
                      {show(row.values[id])}
                    </td>
                  ))}
                  <td>
                    {row.follows ? (
                      <span className="muted">follows {row.follows}</span>
                    ) : (
                      <RadioGroup
                        aria-label={`Winner for ${row.field}`}
                        data-testid={`b360-merge-winner-${row.field}`}
                        value={picks[row.field] ?? IDMC_DECIDES}
                        onValueChange={(v: string | null) => setPicks((old) => ({ ...old, [row.field]: v ?? IDMC_DECIDES }))}
                      >
                        <label>
                          <Radio value={IDMC_DECIDES} aria-label={`${row.field} IDMC decides`}>
                            <RadioIndicator aria-hidden="true">o</RadioIndicator>
                          </Radio>{" "}
                          IDMC decides
                        </label>
                        {preview.business_ids.map((id) => (
                          <label key={id}>
                            {" "}
                            <Radio value={id} aria-label={`${row.field} from ${id}`}>
                              <RadioIndicator aria-hidden="true">o</RadioIndicator>
                            </Radio>{" "}
                            ...{id.slice(-4)}
                          </label>
                        ))}
                      </RadioGroup>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {preview !== null && (
        <div className="row">
          <Button
            aria-label="Merge records"
            data-testid="b360-merge-go"
            data-agent-confirm={`Merges ${preview.business_ids.length} ${entity} master records on the live B360 org and sets the picked field winners`}
            onClick={() => void merge()}
            disabled={!canMerge}
          >
            Merge {preview.business_ids.length} records
          </Button>
          <span className="muted">
            Winners: {Object.entries(winnersToSend(picks, followers)).map(([f, id]) => `${f} from ${id}`).join(", ") || "none (IDMC decides every field)"}
          </span>
        </div>
      )}

      {result !== null && (
        <div data-testid="b360-merge-result" aria-label="Merge result">
          <p>
            {result.note} Surviving master: <strong data-testid="b360-merge-survivor">{show(result.surviving_business_id)}</strong>
            {result.approval_required === true && " - waiting for steward approval, winners not applied."}
          </p>
          <table className="monitor kv" aria-label="Merge steps">
            <tbody>
              {result.steps.map((s) => (
                <tr key={s.step} data-testid={`b360-merge-step-${s.step}`}>
                  <th>{s.step}</th>
                  <td>{s.status}</td>
                  <td>{s.detail}</td>
                </tr>
              ))}
            </tbody>
          </table>
          {result.overrides.length > 0 && (
            <table className="monitor" aria-label="Field winners applied" data-testid="b360-merge-overrides">
              <thead>
                <tr>
                  <th>Field</th>
                  <th>From</th>
                  <th>Sent</th>
                  <th>Read back</th>
                  <th>Stuck</th>
                </tr>
              </thead>
              <tbody>
                {result.overrides.map((o) => (
                  <tr key={o.field}>
                    <td>
                      {o.field}
                      {o.carried_with ? <span className="muted"> (with {o.carried_with})</span> : null}
                    </td>
                    <td>{o.winner_business_id}</td>
                    <td>{show(o.value)}</td>
                    <td>{show(o.final_value)}</td>
                    <td>{o.stuck === null || o.stuck === undefined ? "-" : o.stuck ? "yes" : "NO"}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
          {result.surviving_business_id != null && (
            <div className="row">
              <Button aria-label="Show source records to unmerge" data-testid="b360-unmerge-load" onClick={() => void loadSources()} disabled={busy}>
                Undo: pick sources to unmerge
              </Button>
            </div>
          )}
          {sources !== null && (
            <div data-testid="b360-unmerge" aria-label="Unmerge source records">
              {sources.members.map((m) => (
                <label key={keyOf(m)} className="row">
                  <Checkbox
                    aria-label={`Unmerge ${keyOf(m)}`}
                    checked={undoPick.includes(keyOf(m))}
                    onCheckedChange={(c) => setUndoPick((old) => (c === true ? [...old, keyOf(m)] : old.filter((k) => k !== keyOf(m))))}
                  >
                    <CheckboxIndicator aria-hidden="true">x</CheckboxIndicator>
                  </Checkbox>{" "}
                  {keyOf(m)}
                </label>
              ))}
              <Button
                aria-label="Unmerge selected sources"
                data-testid="b360-unmerge-go"
                data-agent-confirm="Takes the selected source records out of the master on the live B360 org"
                onClick={() => void unmerge()}
                disabled={busy || undoPick.length === 0}
              >
                Unmerge {undoPick.length}
              </Button>
              {undoNote !== "" && <p data-testid="b360-unmerge-note">{undoNote}</p>}
            </div>
          )}
        </div>
      )}
    </section>
  );
}
