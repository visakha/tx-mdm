// B360 Data notebook (Vamsi 2026-11-23 00:44-00:49 CST). Read-only.
//   1. Business entities, one per line, full width - derived by the backend from the B360
//      metadata APIs only (nothing hardcoded).
//   2. Click an entity: its first 10 records below, columns = the entity's top-level fields
//      from its metadata.
//   3. Click a record: detail underneath - top-level fields first, then each field group
//      STACKED as its own titled block with a small table of its rows. No tabs.
// No polling; Refresh reloads. A 429 is shown and nothing is retried.

import { useCallback, useEffect, useState } from "react";
import { Button } from "@ui-sdk/react/button";
import { ApiError, errorText } from "../shared/api";
import type { Route } from "../shared/routes";
import type { BusinessEntitySummary, FieldGroup } from "./api-types";
import {
  b360Api,
  B360_LIMIT,
  cellText,
  groupRows,
  recordColumns,
  type EntityRecord,
  type RecordPage,
} from "./b360Api";

function errorMessage(err: unknown): string {
  if (err instanceof ApiError && err.status === 429) {
    return `IDMC rate limit (429): stopped, nothing retried. ${err.message}`;
  }
  return errorText(err);
}

type Selected = { entity: string | null; record: string | null };

// Agent bridge: openB360Record(businessId) selects a record row of the open entity.
const recordListeners = new Set<(id: string) => void>();
export function openB360Record(businessId: string): void {
  if (recordListeners.size === 0) throw new Error("Open the B360 Data notebook and an entity first.");
  for (const listener of recordListeners) listener(businessId);
}

function GroupBlock({ group, record }: { group: FieldGroup; record: EntityRecord }): React.JSX.Element {
  const rows = groupRows(record, group.name);
  return (
    <section className="b360-group" data-testid={`b360-group-${group.name}`}>
      <h4>
        {group.label} <span className="count">{rows.length}</span>
      </h4>
      {rows.length === 0 ? (
        <p className="muted">No {group.label} rows.</p>
      ) : (
        <div className="table-wrap">
          <table className="monitor">
            <thead>
              <tr>
                {group.fields.map((f) => (
                  <th key={f.name} title={`${f.name} (${f.data_type})`}>{f.label}</th>
                ))}
              </tr>
            </thead>
            <tbody>
              {rows.map((row, i) => (
                <tr key={i}>
                  {group.fields.map((f) => (
                    <td key={f.name}>{cellText(row[f.name], f.data_type)}</td>
                  ))}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </section>
  );
}

function RecordDetail({ page, record }: { page: RecordPage; record: EntityRecord }): React.JSX.Element {
  return (
    <div className="b360-detail" data-testid="b360-detail" data-record={record.business_id}>
      <h3>Record {record.business_id}</h3>
      <section className="b360-group" data-testid="b360-group-fields">
        <h4>Fields</h4>
        <table className="monitor kv">
          <tbody>
            {page.entity.fields.map((f) => (
              <tr key={f.name}>
                <th title={`${f.name} (${f.data_type})`}>{f.label}</th>
                <td>{cellText(record.values[f.name], f.data_type)}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </section>
      {page.entity.field_groups.map((g) => (
        <GroupBlock key={g.name} group={g} record={record} />
      ))}
    </div>
  );
}

export function B360DataPanel({
  route,
  go,
  active,
}: {
  route: Route;
  go: (route: Route) => void;
  active: boolean;
}): React.JSX.Element {
  const entityName = route.screen === "b360" ? route.entity : null;
  const [entities, setEntities] = useState<readonly BusinessEntitySummary[] | null>(null);
  const [source, setSource] = useState<string>("");
  const [page, setPage] = useState<RecordPage | null>(null);
  const [selected, setSelected] = useState<Selected>({ entity: null, record: null });
  const [error, setError] = useState<string>("");
  const [loading, setLoading] = useState<boolean>(false);

  const loadEntities = useCallback((): void => {
    setError("");
    setLoading(true);
    b360Api
      .entities()
      .then((list) => {
        setEntities(list.entities);
        setSource(list.source);
      })
      .catch((err: unknown) => setError(errorMessage(err)))
      .finally(() => setLoading(false));
  }, []);

  const loadRecords = useCallback((name: string): void => {
    setError("");
    setPage(null);
    setLoading(true);
    b360Api
      .records(name, B360_LIMIT)
      .then(setPage)
      .catch((err: unknown) => setError(errorMessage(err)))
      .finally(() => setLoading(false));
  }, []);

  useEffect(() => {
    if (active && entities === null) loadEntities();
  }, [active, entities, loadEntities]);

  useEffect(() => {
    if (!active || entityName === null) return;
    if (selected.entity === entityName) return;
    setSelected({ entity: entityName, record: null });
    loadRecords(entityName);
  }, [active, entityName, selected.entity, loadRecords]);

  useEffect(() => {
    const listener = (id: string): void => setSelected((s) => ({ ...s, record: id }));
    recordListeners.add(listener);
    return () => {
      recordListeners.delete(listener);
    };
  }, []);

  const refresh = (): void => {
    loadEntities();
    if (entityName !== null) loadRecords(entityName);
  };

  const record = page?.records.find((r) => r.business_id === selected.record) ?? null;

  return (
    <div className="b360-data" data-testid="b360-data">
      <div className="toolbar">
        <h2>Business entities</h2>
        <Button data-testid="b360-refresh" onClick={refresh} disabled={loading}>
          Refresh
        </Button>
        {loading && <span className="muted">Loading...</span>}
      </div>
      {error !== "" && (
        <p className="warn-text" data-testid="b360-error">{error}</p>
      )}
      {source !== "" && <p className="muted small">From {source}</p>}
      {entities !== null && entities.length === 0 && (
        <p className="muted" data-testid="b360-entities-empty">The metadata APIs listed no business entities.</p>
      )}
      {entities !== null && entities.length > 0 && (
        <ul className="b360-entities" data-testid="b360-entities">
          {entities.map((e) => (
            <li key={e.name}>
              <button
                type="button"
                className={`b360-entity${e.name === entityName ? " selected" : ""}`}
                data-testid={`b360-entity-${e.name}`}
                aria-pressed={e.name === entityName}
                onClick={() => go({ screen: "b360", service: "mdm", entity: e.name })}
              >
                <span className="item-name">{e.label}</span> <code>{e.name}</code>
              </button>
            </li>
          ))}
        </ul>
      )}

      {page !== null && (
        <div className="b360-records" data-testid="b360-records" data-entity={page.entity.name}>
          <h3>
            {page.entity.label}: first {page.records.length}
            {page.hits !== null ? ` of ${page.hits.toLocaleString()}` : ""} records
          </h3>
          {page.unknown_keys.length > 0 && (
            <p className="muted small" data-testid="b360-unknown-keys">
              Not in the metadata (not shown): {page.unknown_keys.join(", ")}
            </p>
          )}
          {page.records.length === 0 ? (
            <p className="muted">No records.</p>
          ) : (
            <div className="table-wrap">
              <table className="monitor" data-testid="b360-records-table">
                <thead>
                  <tr>
                    <th>Business id</th>
                    {recordColumns(page.entity).map((f) => (
                      <th key={f.name} title={`${f.name} (${f.data_type})`}>{f.label}</th>
                    ))}
                  </tr>
                </thead>
                <tbody>
                  {page.records.map((r) => (
                    <tr
                      key={r.business_id}
                      className={`clickable${r.business_id === selected.record ? " selected" : ""}`}
                      data-testid={`b360-record-${r.business_id}`}
                      onClick={() => setSelected((s) => ({ ...s, record: r.business_id }))}
                    >
                      <td><code>{r.business_id}</code></td>
                      {recordColumns(page.entity).map((f) => (
                        <td key={f.name}>{cellText(r.values[f.name], f.data_type)}</td>
                      ))}
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
          {record !== null && <RecordDetail page={page} record={record} />}
        </div>
      )}
    </div>
  );
}
