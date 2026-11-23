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
  lastUpdatedText,
  recordColumns,
  type EntityRecord,
  type RecordPage,
  type RecordQuery,
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

function SystemTag(): React.JSX.Element {
  return <span className="system-tag">system</span>;
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
            <tr key={f.name} className={f.origin === "SYSTEM" ? "system-row" : undefined} data-origin={f.origin ?? "CONFIGURED"}>
              <td>
                <code>{f.name}</code> {f.origin === "SYSTEM" && <SystemTag />}
              </td>
              <td>
                {f.label}
                {f.origin_source === "DOCUMENTED" && <span className="small"> (documented)</span>}
              </td>
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
  const systemFields = entity.system_fields ?? [];
  const systemGroups = entity.system_field_groups ?? [];
  const groupBlock = (g: BusinessEntity["field_groups"][number]): React.JSX.Element => (
    <section
      key={g.name}
      className={`b360-group${g.origin === "SYSTEM" ? " system-group" : ""}`}
      data-testid={`b360-meta-group-${g.name}`}
      data-origin={g.origin ?? "CONFIGURED"}
    >
      <h4>
        {g.label} <span className="muted small">({g.name}, {g.cardinality})</span>
        {g.origin === "SYSTEM" && <SystemTag />}
        {g.origin_source === "DOCUMENTED" && <span className="small"> documented in the B360 REST API Reference</span>}
      </h4>
      <FieldTable fields={g.fields} testId={`b360-meta-group-fields-${g.name}`} />
    </section>
  );
  return (
    <div className="b360-meta" data-testid="b360-metadata">
      <p className="muted small">
        Configured fields are in normal text. <span className="system-text">System fields and field groups are in magenta</span>{" "}
        with a system label: added by Business 360 itself. &quot;documented&quot; means the org metadata reply did not list it and it
        comes from the B360 REST API Reference.
      </p>
      <section className="b360-group">
        <h4>
          Root fields <span className="count">{entity.fields.length}</span>
        </h4>
        <FieldTable fields={entity.fields} testId="b360-meta-fields" />
      </section>
      {entity.field_groups.length === 0 ? (
        <p className="muted">This entity has no configured field groups.</p>
      ) : (
        entity.field_groups.map(groupBlock)
      )}
      {systemFields.length > 0 && (
        <section className="b360-group system-group" data-testid="b360-meta-system-fields" data-origin="SYSTEM">
          <h4>
            System fields <span className="count">{systemFields.length}</span> <SystemTag />
          </h4>
          <FieldTable fields={systemFields} testId="b360-meta-system-fields-table" />
        </section>
      )}
      {systemGroups.map(groupBlock)}
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
  // 0.9.9: paging, filters (first / last name STARTS_WITH, exact Business ID), Last updated sort.
  const [query, setQuery] = useState<RecordQuery>({ page: 1, sort: "NEWEST_FIRST" });
  const [draft, setDraft] = useState<{ firstName: string; lastName: string; businessId: string }>({
    firstName: "",
    lastName: "",
    businessId: "",
  });

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

  const loadRecords = useCallback((name: string, q: RecordQuery = { page: 1, sort: "NEWEST_FIRST" }): void => {
    setError("");
    setLoading(true);
    setQuery(q);
    b360Api
      .records(name, q, B360_LIMIT)
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
    setPage(null);
    setDraft({ firstName: "", lastName: "", businessId: "" });
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
    else loadRecords(entityName, query);
  };
  const applyFilters = (): void => {
    if (entityName !== null) loadRecords(entityName, { ...draft, page: 1, sort: query.sort });
  };
  const clearFilters = (): void => {
    setDraft({ firstName: "", lastName: "", businessId: "" });
    if (entityName !== null) loadRecords(entityName, { page: 1, sort: query.sort });
  };
  const goPage = (n: number): void => {
    if (entityName !== null) loadRecords(entityName, { ...query, page: n });
  };
  const toggleSort = (): void => {
    if (entityName === null) return;
    const sort = query.sort === "OLDEST_FIRST" ? "NEWEST_FIRST" : "OLDEST_FIRST";
    loadRecords(entityName, { ...query, page: 1, sort });
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
        <AddRecordsView entity={page.entity.name} onSaved={() => loadRecords(page.entity.name, { page: 1, sort: "NEWEST_FIRST" })} />
      )}

      {page !== null && tab !== "metadata" && tab !== "add" && (
        <div className="b360-records master-detail" data-testid="b360-records" data-entity={page.entity.name}>
          <section className="b360-master" data-testid="b360-master">
            <h3>
              Master: {page.entity.label} root
              {page.mode === "BUSINESS_ID" ? ` - business ID ${page.business_id ?? ""}` : ""}
            </h3>
            <div className="toolbar b360-filters" data-testid="b360-filters">
              {(
                [
                  ["firstName", "First name", "b360-filter-first"],
                  ["lastName", "Last name", "b360-filter-last"],
                  ["businessId", "Business ID", "b360-filter-bid"],
                ] as const
              ).map(([key, label, testId]) => (
                <label key={key}>
                  {label}{" "}
                  <input
                    type="text"
                    data-testid={testId}
                    value={draft[key]}
                    placeholder={key === "businessId" ? "exact" : "starts with"}
                    onChange={(e) => setDraft((d) => ({ ...d, [key]: e.target.value }))}
                    onKeyDown={(e) => {
                      if (e.key === "Enter") applyFilters();
                    }}
                  />
                </label>
              ))}
              <Button data-testid="b360-filter-apply" onClick={applyFilters} disabled={loading}>
                Apply
              </Button>
              <Button data-testid="b360-filter-clear" onClick={clearFilters} disabled={loading}>
                Clear
              </Button>
            </div>
            {page.note !== "" && page.note !== undefined && (
              <p className="muted small" data-testid="b360-records-note">{page.note}</p>
            )}
            {page.filters !== undefined && page.filters.length > 0 && (
              <p className="muted small" data-testid="b360-filters-applied">
                Filtered: {page.filters.map((f) => `${f.label} ${f.comparator.toLowerCase().replace("_", " ")} "${f.value}"`).join(", ")}
              </p>
            )}
            <div className="toolbar b360-pager" data-testid="b360-pager">
              <Button data-testid="b360-page-prev" onClick={() => goPage((page.page ?? 1) - 1)} disabled={loading || (page.page ?? 1) <= 1}>
                Prev
              </Button>
              <span data-testid="b360-page-info">
                Page {page.page ?? 1} of {page.total_pages ?? 1} ({(page.hits ?? page.records.length).toLocaleString()} records)
              </span>
              <Button
                data-testid="b360-page-next"
                onClick={() => goPage((page.page ?? 1) + 1)}
                disabled={loading || (page.page ?? 1) >= (page.total_pages ?? 1)}
              >
                Next
              </Button>
            </div>
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
                      <th>
                        <button
                          type="button"
                          className="sort-head"
                          data-testid="b360-sort-updated"
                          data-sort={query.sort ?? "NEWEST_FIRST"}
                          title="Sort all records by last update (any channel): click to flip"
                          onClick={toggleSort}
                          disabled={loading || page.mode === "BUSINESS_ID"}
                        >
                          Last updated {query.sort === "OLDEST_FIRST" ? "(oldest first) ^" : "(newest first) v"}
                        </button>
                      </th>
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
                        <td data-testid={`b360-updated-${r.business_id}`} title={r.updated_by ? `by ${r.updated_by}` : undefined}>
                          {lastUpdatedText(r.last_updated)}
                        </td>
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
