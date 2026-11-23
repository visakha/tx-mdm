// 0.9.12.4 (Vamsi 02:48-02:49 CST): Merge history (M) and Merge history (S) tabs. IDMC exposes no
// merge-event log through its API, so these show who contributes what NOW (content meta,
// _showContentMeta=true, p. 19) plus merges / unmerges pressed in THIS app (backend memory, lost
// on restart). Read-only. UI SDK Input / Button with unique aria-labels; tables labelled.
import { useCallback, useEffect, useState } from "react";
import { Button } from "@ui-sdk/react/button";
import { Input } from "@ui-sdk/react/input";
import { errorText, getJson } from "../shared/api";
import type { AppMergeEvent, MasterMergeHistory, SourceMergeHistory, TrustEntry } from "./api-types";
import { cellText, type CellValue } from "./b360Api";

const base = (entity: string): string => `/api/b360/entities/${encodeURIComponent(entity)}`;

function when(v: string | null | undefined): string {
  return v === null || v === undefined ? "-" : v;
}

function score(t: TrustEntry | null | undefined): string {
  return t?.trust_score === null || t?.trust_score === undefined ? "-" : String(t.trust_score);
}

function override(t: TrustEntry | null | undefined): string {
  return t?.manual_override === null || t?.manual_override === undefined ? "-" : t.manual_override ? "yes" : "no";
}

function show(v: CellValue | undefined): string {
  return cellText(v, "STRING");
}

function AppEvents({ events, testId }: { events: readonly AppMergeEvent[]; testId: string }): React.JSX.Element {
  return (
    <section data-testid={testId}>
      <h4>Pressed in this app (backend memory, lost on restart)</h4>
      {events.length === 0 ? (
        <p className="muted small">None since the backend started.</p>
      ) : (
        <ul>
          {events.map((e) => (
            <li key={`${e.at}-${e.kind}`}>
              {e.kind === "MERGE"
                ? `merged from this app at ${e.at}: ${e.business_ids.join(", ")} -> survivor ${e.surviving_business_id ?? "?"}`
                : `unmerged from this app at ${e.at}: ${(e.sources ?? []).map((s) => `${s.source_system}/${s.source_pkey}`).join(", ")} out of ${e.business_ids.join(", ")}`}
              {e.approval_required === true ? " (approval required)" : ""}
            </li>
          ))}
        </ul>
      )}
    </section>
  );
}

export function MasterHistoryView({ entity, initial }: { entity: string; initial: string | null }): React.JSX.Element {
  const [bid, setBid] = useState<string>(initial ?? "");
  const [data, setData] = useState<MasterMergeHistory | null>(null);
  const [error, setError] = useState<string>("");
  const [busy, setBusy] = useState<boolean>(false);

  const load = useCallback(
    (id: string): void => {
      if (id.trim() === "") return;
      setBusy(true);
      setError("");
      getJson<MasterMergeHistory>(`${base(entity)}/records/${encodeURIComponent(id.trim())}/merge-history`)
        .then(setData)
        .catch((err: unknown) => setError(errorText(err)))
        .finally(() => setBusy(false));
    },
    [entity],
  );

  useEffect(() => {
    if (initial !== null) load(initial);
  }, [initial, load]);

  return (
    <section className="b360-history" data-testid="b360-history-m">
      <div className="toolbar">
        <label>
          Business ID{" "}
          <Input
            type="text"
            aria-label="Merge history master business ID"
            data-testid="b360-history-m-bid"
            value={bid}
            onValueChange={(v: string) => setBid(v)}
            onKeyDown={(e: React.KeyboardEvent<HTMLInputElement>) => {
              if (e.key === "Enter") load(bid);
            }}
          />
        </label>
        <Button aria-label="Load merge history (M)" data-testid="b360-history-m-load" disabled={busy} onClick={() => load(bid)}>
          Load
        </Button>
      </div>
      {error !== "" && <p className="warn-text" data-testid="b360-history-m-error">{error}</p>}
      {busy && <p className="muted">Loading...</p>}
      {data !== null && (
        <>
          <p className="muted small" data-testid="b360-history-m-note">{data.note}</p>
          <h4>Each field now: winning value and where it came from</h4>
          <div className="records-scroll">
            <table className="monitor" aria-label="Merge history master fields" data-testid="b360-history-m-fields">
              <thead>
                <tr>
                  <th>Field</th>
                  <th>Value</th>
                  <th>Source system</th>
                  <th>Source pkey</th>
                  <th>Trust rule</th>
                  <th>Trust score</th>
                  <th>Manual override</th>
                  <th>Last updated</th>
                  <th>Trust entry</th>
                </tr>
              </thead>
              <tbody>
                {data.fields.map((f) => (
                  <tr key={f.field}>
                    <td>{f.field}</td>
                    <td>{show(f.value)}</td>
                    <td>{f.winner?.source_system ?? "-"}</td>
                    <td>{f.winner?.source_pkey ?? "-"}</td>
                    <td>{f.winner?.trust_rule ?? "-"}</td>
                    <td>{score(f.winner)}</td>
                    <td>{override(f.winner)}</td>
                    <td>{when(f.winner?.last_updated)}</td>
                    <td>{f.winner === null || f.winner === undefined ? "none" : f.winner.field_ref === "/" ? "record-wide (/)" : "own"}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <h4>Contributing source records (oldest first)</h4>
          <table className="monitor" aria-label="Merge history contributors" data-testid="b360-history-m-contributors">
            <thead>
              <tr>
                <th>Source system</th>
                <th>Source pkey</th>
                <th>Created</th>
                <th>Last updated</th>
                <th>Source last updated</th>
                <th>Updated by</th>
              </tr>
            </thead>
            <tbody>
              {data.contributors.map((c) => (
                <tr key={`${c.source_system}/${c.source_pkey}`}>
                  <td>{c.source_system}</td>
                  <td>{c.source_pkey}</td>
                  <td>{when(c.created)}</td>
                  <td>{when(c.last_updated)}</td>
                  <td>{when(c.source_last_updated)}</td>
                  <td>{c.read_ok === false ? "not read" : (c.updated_by ?? "-")}</td>
                </tr>
              ))}
            </tbody>
          </table>
          <AppEvents events={data.app_events} testId="b360-history-m-app" />
        </>
      )}
    </section>
  );
}

export function SourceHistoryView({ entity }: { entity: string }): React.JSX.Element {
  const [system, setSystem] = useState<string>("zlv_ttf");
  const [pkey, setPkey] = useState<string>("");
  const [data, setData] = useState<SourceMergeHistory | null>(null);
  const [error, setError] = useState<string>("");
  const [busy, setBusy] = useState<boolean>(false);

  const load = (): void => {
    if (system.trim() === "" || pkey.trim() === "") return;
    setBusy(true);
    setError("");
    getJson<SourceMergeHistory>(
      `${base(entity)}/sources/${encodeURIComponent(system.trim())}/${encodeURIComponent(pkey.trim())}/merge-history`,
    )
      .then(setData)
      .catch((err: unknown) => setError(errorText(err)))
      .finally(() => setBusy(false));
  };

  return (
    <section className="b360-history" data-testid="b360-history-s">
      <div className="toolbar">
        <label>
          Source system{" "}
          <Input type="text" aria-label="Merge history source system" data-testid="b360-history-s-system" value={system} onValueChange={(v: string) => setSystem(v)} />
        </label>
        <label>
          sourcePKey{" "}
          <Input
            type="text"
            aria-label="Merge history sourcePKey"
            data-testid="b360-history-s-pkey"
            value={pkey}
            onValueChange={(v: string) => setPkey(v)}
            onKeyDown={(e: React.KeyboardEvent<HTMLInputElement>) => {
              if (e.key === "Enter") load();
            }}
          />
        </label>
        <Button aria-label="Load merge history (S)" data-testid="b360-history-s-load" disabled={busy} onClick={load}>
          Load
        </Button>
      </div>
      {error !== "" && <p className="warn-text" data-testid="b360-history-s-error">{error}</p>}
      {busy && <p className="muted">Loading...</p>}
      {data !== null && (
        <>
          <p className="muted small" data-testid="b360-history-s-note">{data.note}</p>
          <p data-testid="b360-history-s-master">
            Belongs to master <code>{data.business_id}</code>.
          </p>
          <h4>Its own trust (content meta)</h4>
          <table className="monitor" aria-label="Merge history source trust" data-testid="b360-history-s-trust">
            <thead>
              <tr>
                <th>Field ref</th>
                <th>Trust rule</th>
                <th>Trust score</th>
                <th>Manual override</th>
                <th>Last updated</th>
              </tr>
            </thead>
            <tbody>
              {data.trust.map((t) => (
                <tr key={t.field_ref}>
                  <td>{t.field_ref === "/" ? "/ (all fields)" : t.field_ref}</td>
                  <td>{t.trust_rule ?? "-"}</td>
                  <td>{score(t)}</td>
                  <td>{override(t)}</td>
                  <td>{when(t.last_updated)}</td>
                </tr>
              ))}
            </tbody>
          </table>
          <h4>Did its values win in the master?</h4>
          <table className="monitor" aria-label="Merge history source fields" data-testid="b360-history-s-fields">
            <thead>
              <tr>
                <th>Field</th>
                <th>This source</th>
                <th>Master now</th>
                <th>Won</th>
                <th>Master value came from</th>
              </tr>
            </thead>
            <tbody>
              {data.fields.map((f) => (
                <tr key={f.field}>
                  <td>{f.field}</td>
                  <td>{show(f.source_value)}</td>
                  <td>{show(f.master_value)}</td>
                  <td>{f.won ? "yes" : "no"}</td>
                  <td>
                    {f.master_winner === null || f.master_winner === undefined
                      ? "-"
                      : `${f.master_winner.source_system ?? "?"}/${f.master_winner.source_pkey ?? "?"}`}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
          <AppEvents events={data.app_events} testId="b360-history-s-app" />
        </>
      )}
    </section>
  );
}
