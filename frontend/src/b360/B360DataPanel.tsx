// B360 Data notebook. Read-only.
// 0.9.5 (Vamsi 2026-11-23 00:44-00:49 CST): entities derived from the B360 metadata APIs.
// 0.9.7 (01:00-01:04 CST): the left pane lists the entities of backend/b360_entities.toml
// (zlv_guest today) as their own sections. For an entity the page is MASTER-DETAIL, stacked,
// both full width (same pattern as the Taskflows Run tab):
//   Records tab:  MASTER = the entity root - first 10 records, root fields as columns.
//                 DETAIL = the picked record below: root fields, then each field group STACKED
//                 as its own titled block (no tabs). "This entity has no field groups" if none.
//   Metadata tab: the entity's fields (type, mandatory, searchable) and field groups.
//   Add records tab (0.9.8): type a record or generate Faker rows, then Save / Send to B360.
// /b360 with no entity = "Show all entities": every entity grouped by category.
// No polling; Refresh reloads. A 429 is shown and nothing is retried.

import { useCallback, useEffect, useState } from "react";
import { Button } from "@ui-sdk/react/button";
import { ApiError, errorText } from "../shared/api";
import type { Route } from "../shared/routes";
import { useRibbonTab } from "../shell/sections";
import { AddRecordsView } from "./AddRecordsView";
import type { BusinessEntity, BusinessEntitySummary, FieldGroup } from "./api-types";
import {
  b360Api,
  B360_LIMIT,
  CATEGORY_LABEL,
  groupByCategory,
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
      <h3>Detail: record {record.business_id}</h3>
      <section className="b360-group" data-testid="b360-group-fields">
        <h4>Root fields</h4>
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
      {page.entity.field_groups.length === 0 ? (
        <p className="muted" data-testid="b360-no-groups">This entity has no field groups.</p>
      ) : (
        page.entity.field_groups.map((g) => <GroupBlock key={g.name} group={g} record={record} />)
      )}
    </div>
  );
}

function FieldTable({ fields, testId }: { fields: BusinessEntity["fields"]; testId: string }): React.JSX.Element {
  return (
    <div className="table-wrap">
      <table className="monitor" data-testid={testId}>
        <thead>
          <tr>
            <th>Field</th>
            <th>Label</th>
            <th>Type</th>
            <th>Mandatory</th>
            <th>Searchable</th>
          </tr>
        </thead>
        <tbody>
          {fields.map((f) => (
            <tr key={f.name}>
              <td><code>{f.name}</code></td>
              <td>{f.label}</td>
              <td title={f.raw_type}>{f.data_type}</td>
              <td>{f.mandatory ? "yes" : "-"}</td>
              <td>{f.searchable ? "yes" : "-"}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

function MetadataView({ entity }: { entity: BusinessEntity }): React.JSX.Element {
  return (
    <div className="b360-meta" data-testid="b360-metadata">
      <section className="b360-group">
        <h4>
          Root fields <span className="count">{entity.fields.length}</span>
        </h4>
        <FieldTable fields={entity.fields} testId="b360-meta-fields" />
      </section>
      {entity.field_groups.length === 0 ? (
        <p className="muted">This entity has no field groups.</p>
      ) : (
        entity.field_groups.map((g) => (
          <section key={g.name} className="b360-group" data-testid={`b360-meta-group-${g.name}`}>
            <h4>
              {g.label} <span className="muted small">({g.name}, {g.cardinality})</span>
            </h4>
            <FieldTable fields={g.fields} testId={`b360-meta-group-fields-${g.name}`} />
          </section>
        ))
      )}
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
  const tab = useRibbonTab("b360-data");
  const [all, setAll] = useState<readonly BusinessEntitySummary[] | null>(null);
  const [total, setTotal] = useState<number | null>(null);
  const [source, setSource] = useState<string>("");
  const [page, setPage] = useState<RecordPage | null>(null);
  const [selected, setSelected] = useState<Selected>({ entity: null, record: null });
  const [error, setError] = useState<string>("");
  const [loading, setLoading] = useState<boolean>(false);

  const loadAll = useCallback((): void => {
    setError("");
    setLoading(true);
    b360Api
      .entities("all")
      .then((list) => {
        setAll(list.entities);
        setTotal(list.total);
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
      .then((p) => {
        setPage(p);
        // Detail shows straight away: the first record is picked unless one already is.
        setSelected((s) => (s.record !== null && p.records.some((r) => r.business_id === s.record) ? s : { ...s, record: p.records[0]?.business_id ?? null }));
      })
      .catch((err: unknown) => setError(errorMessage(err)))
      .finally(() => setLoading(false));
  }, []);

  useEffect(() => {
    if (active && entityName === null && all === null) loadAll();
  }, [active, entityName, all, loadAll]);

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
    if (entityName === null) loadAll();
    else loadRecords(entityName);
  };

  const entityButton = (e: BusinessEntitySummary): React.JSX.Element => (
    <li key={e.name}>
      <button
        type="button"
        className="b360-entity"
        data-testid={`b360-entity-${e.name}`}
        onClick={() => go({ screen: "b360", service: "mdm", entity: e.name })}
      >
        <span className="item-name">{e.label}</span> <code>{e.name}</code>
        {e.focus && <span className="muted small"> (in b360_entities.toml)</span>}
      </button>
    </li>
  );

  const record = page?.records.find((r) => r.business_id === selected.record) ?? null;

  if (entityName === null) {
    return (
      <div className="b360-data" data-testid="b360-data">
        <div className="toolbar">
          <h2>All business entities</h2>
          <Button data-testid="b360-refresh" onClick={refresh} disabled={loading}>
            Refresh
          </Button>
          {loading && <span className="muted">Loading...</span>}
        </div>
        {error !== "" && <p className="warn-text" data-testid="b360-error">{error}</p>}
        <p className="muted small" data-testid="b360-scope">
          {total === null ? "" : `${String(total)} business entities in the metadata. `}
          The left pane lists only the ones in backend/b360_entities.toml (edit it, then restart the backend).
          {source !== "" && ` From ${source}.`}
        </p>
        {all !== null && all.length === 0 && (
          <p className="muted" data-testid="b360-entities-empty">The metadata APIs listed no business entities.</p>
        )}
        {all !== null && all.length > 0 && (
          <div data-testid="b360-entities">
            {groupByCategory(all).map((g) => (
              <section key={g.category} className="b360-category" data-testid={`b360-category-${g.category}`}>
                <h3>
                  {CATEGORY_LABEL[g.category]} <span className="count">{g.entities.length}</span>
                </h3>
                <ul className="b360-entities">{g.entities.map(entityButton)}</ul>
              </section>
            ))}
          </div>
        )}
      </div>
    );
  }

  return (
    <div className="b360-data" data-testid="b360-data" data-entity={entityName}>
      <div className="toolbar">
        <h2>{page?.entity.label ?? entityName}</h2>
        <code>{entityName}</code>
        <Button data-testid="b360-refresh" onClick={refresh} disabled={loading}>
          Refresh
        </Button>
        {loading && <span className="muted">Loading...</span>}
      </div>
      {error !== "" && <p className="warn-text" data-testid="b360-error">{error}</p>}

      {page !== null && tab === "metadata" && <MetadataView entity={page.entity} />}

      {page !== null && tab === "add" && (
        <AddRecordsView entity={page.entity.name} onSaved={() => loadRecords(page.entity.name)} />
      )}

      {page !== null && tab !== "metadata" && tab !== "add" && (
        <div className="b360-records master-detail" data-testid="b360-records" data-entity={page.entity.name}>
          <section className="b360-master" data-testid="b360-master">
            <h3>
              Master: {page.entity.label} root, first {page.records.length}
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
                        aria-selected={r.business_id === selected.record}
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
          </section>
          {record !== null && <RecordDetail page={page} record={record} />}
        </div>
      )}
    </div>
  );
}
