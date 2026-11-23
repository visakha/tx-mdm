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
// 0.9.10 tabs: Records (M) | Metadata (M) | Records (S) | Metadata (S) | Add records (S) |
//   Edit records (S). Records (S) reuses the master list: pick a master row, its sources show
//   below (SourceViews.tsx). Master and source tables sit in their own scroll box (both
//   directions, about 10 rows high, sticky header). System (_meta) columns are magenta.
//   UI SDK Input / Button / Select with unique aria-labels; tables stay own markup, labelled.
// /b360 with no entity = "Show all entities": every entity grouped by category.
// No polling; Refresh reloads. A 429 is shown and nothing is retried.

import { useCallback, useEffect, useState } from "react";
import { Button } from "@ui-sdk/react/button";
import { Input } from "@ui-sdk/react/input";
import { ApiError, errorText } from "../shared/api";
import type { Route } from "../shared/routes";
import { selectRibbonTab, useRibbonTab } from "../shell/sections";
import { AddRecordsView } from "./AddRecordsView";
import { MergeView } from "./MergeView";
import { EditSourceView, SourceRecordsView, type SourceKeyPick } from "./SourceViews";
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
  isShown,
  isSystemColumnShown,
  systemValue,
  systemValueText,
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
            {page.entity.fields.filter((f) => isShown(page.visibility, f.name)).map((f) => (
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
        page.entity.field_groups
          .filter((g) => isShown(page.visibility, g.name))
          .map((g) => (
            <GroupBlock
              key={g.name}
              group={{ ...g, fields: g.fields.filter((f) => isShown(page.visibility, `${g.name}.${f.name}`)) }}
              record={record}
            />
          ))
      )}
      {(record.system_values ?? []).length > 0 && (
        <section className="b360-group system-group" data-testid="b360-detail-system" data-origin="SYSTEM">
          <h4>
            System fields (_meta) <SystemTag />
          </h4>
          <table className="monitor kv" aria-label={`Record ${record.business_id} system fields`}>
            <tbody>
              {(record.system_values ?? []).filter((v) => isSystemColumnShown(page.visibility, v.name)).map((v) => (
                <tr key={v.name} className="system-row" data-origin="SYSTEM">
                  <th>
                    <code>{v.name}</code>
                  </th>
                  <td>{systemValueText(v.name, v.value)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </section>
      )}
    </div>
  );
}

function SystemTag(): React.JSX.Element {
  return <span className="system-tag">system</span>;
}

function FieldTable({ fields, testId, title }: { fields: BusinessEntity["fields"]; testId: string; title: string }): React.JSX.Element {
  return (
    <div className="table-wrap">
      <table className="monitor" data-testid={testId} aria-label={`${title} fields`}>
        <thead>
          <tr>
            <th>Field</th>
            <th>Label</th>
            <th>Type</th>
            <th>Mandatory</th>
            <th>Searchable</th>
            <th>Length</th>
            <th>Lookup list (Reference 360)</th>
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
              <td data-testid={`b360-meta-length-${f.name}`}>{lengthText(f.length)}</td>
              <td data-testid={`b360-meta-lookup-${f.name}`}>{lookupText(f.lookup)}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

// 0.9.12.2: length bound and where it came from.
function lengthText(length: BusinessEntity["fields"][number]["length"]): string {
  if (length === undefined || length === null) return "-";
  const how = length.exact ? `exactly ${length.max}` : `max ${length.max}`;
  const meta = length.metadata_max !== null && length.metadata_max !== undefined && length.origin !== "METADATA" ? `, metadata ${length.metadata_max}` : "";
  return `${how} (${length.origin}${meta})`;
}

// 0.9.12: where a picklist's allowed values come from, as the metadata states it.
function lookupText(lookup: BusinessEntity["fields"][number]["lookup"]): string {
  if (lookup === undefined || lookup === null) return "-";
  const list = lookup.code_list ?? "";
  const rdm = lookup.rdm_entity ?? "";
  const keys = (lookup.raw_keys ?? []).join(", ");
  switch (lookup.status) {
    case "DECLARED":
      return `${rdm || list} (metadata attribute ${lookup.found_in ?? "?"})`;
    case "LABEL_MATCH":
      return `${rdm} (code list "${list}" from ${lookup.found_in ?? "?"})`;
    case "GUESSED":
      return `${rdm} (GUESS: metadata names no list; matched by field name. Raw keys: ${keys})`;
    default:
      return `not found (UNVERIFIED; values fall back to records. Raw keys: ${keys})`;
  }
}

function MetadataView({ entity, source = false }: { entity: BusinessEntity; source?: boolean }): React.JSX.Element {
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
        {g.name === "_meta" ? "Record system metadata (_meta)" : g.label}{" "}
        <span className="muted small">({g.name}, {g.cardinality})</span>
        {g.origin === "SYSTEM" && <SystemTag />}
        {g.origin_source === "DOCUMENTED" && <span className="small"> documented in the B360 REST API Reference</span>}
      </h4>
      {g.origin === "SYSTEM" && (
        <p className="muted small" data-testid={`b360-meta-group-note-${g.name}`}>
          Purely system-owned, no user control: ids, entity, created / updated by and dates, and similar.
        </p>
      )}
      <FieldTable fields={g.fields} testId={`b360-meta-group-fields-${g.name}`} title={`${source ? "Source " : ""}${g.name === "_meta" ? "Record system metadata (_meta)" : g.label}`} />
    </section>
  );
  return (
    <div className="b360-meta" data-testid={source ? "b360-source-metadata" : "b360-metadata"}>
      {source && (
        <p className="muted small" data-testid="b360-source-metadata-note">
          Source (xref) records carry the same configured fields and field groups as the master (same entity
          metadata). The system fields below are the xref _meta fields: those the org metadata lists, plus the ones
          the B360 REST API Reference documents for Read Source Record (pp. 80-84), marked documented. Derived, not
          read from a separate source-metadata call (none is documented).
        </p>
      )}
      <p className="muted small">
        Configured fields are in normal text. <span className="system-text">System fields and field groups are in magenta</span>{" "}
        with a system label: added by Business 360 itself. &quot;documented&quot; means the org metadata reply did not list it and it
        comes from the B360 REST API Reference.
      </p>
      {(entity.length_warnings ?? []).map((w) => (
        <p key={w} className="small visibility-warn" data-testid="b360-length-warning">
          Warning: {w}
        </p>
      ))}
      <section className="b360-group">
        <h4>
          Root fields <span className="count">{entity.fields.length}</span>
        </h4>
        <FieldTable fields={entity.fields} testId="b360-meta-fields" title={source ? "Source root" : "Root"} />
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
          <p className="muted small" data-testid="b360-meta-system-fields-note">
            Business-facing system fields the data can influence: validation, active / inactive record state, index validation.
          </p>
          <FieldTable fields={systemFields} testId="b360-meta-system-fields-table" title={source ? "Source system fields" : "System fields"} />
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
  // 0.9.10: Metadata (S) and the source record picked for Edit records (S).
  const [sourceMeta, setSourceMeta] = useState<BusinessEntity | null>(null);
  const [editPick, setEditPick] = useState<SourceKeyPick | null>(null);
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
    setSourceMeta(null);
    setEditPick(null);
    loadRecords(entityName);
  }, [active, entityName, selected.entity, loadRecords]);

  useEffect(() => {
    const listener = (id: string): void => setSelected((s) => ({ ...s, record: id }));
    recordListeners.add(listener);
    return () => {
      recordListeners.delete(listener);
    };
  }, []);

  useEffect(() => {
    if (!active || entityName === null || tab !== "source-metadata" || sourceMeta?.name === entityName) return;
    let live = true;
    b360Api
      .sourceMetadata(entityName)
      .then((m) => live && setSourceMeta(m))
      .catch((err: unknown) => live && setError(errorMessage(err)));
    return () => {
      live = false;
    };
  }, [active, entityName, tab, sourceMeta]);

  const openEdit = (pick: SourceKeyPick): void => {
    setEditPick(pick);
    selectRibbonTab("b360-data", "edit");
  };

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
          <Button aria-label="Refresh all entities" data-testid="b360-refresh" onClick={refresh} disabled={loading}>
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
        <Button aria-label={`Refresh ${entityName}`} data-testid="b360-refresh" onClick={refresh} disabled={loading}>
          Refresh
        </Button>
        {loading && <span className="muted">Loading...</span>}
      </div>
      {error !== "" && <p className="warn-text" data-testid="b360-error">{error}</p>}

      {page !== null && tab === "metadata" && <MetadataView entity={page.entity} />}

      {tab === "source-metadata" &&
        (sourceMeta !== null && sourceMeta.name === entityName ? (
          <MetadataView entity={sourceMeta} source />
        ) : (
          <p className="muted">Loading the source metadata...</p>
        ))}

      {page !== null && tab === "edit" && <EditSourceView entity={page.entity.name} initial={editPick} />}

      {page !== null && tab === "merge" && (
        <MergeView entity={page.entity.name} initialIds={selected.record ?? ""} onMerged={() => loadRecords(page.entity.name, { page: 1, sort: "NEWEST_FIRST" })} />
      )}

      {page !== null && tab === "add" && (
        <AddRecordsView entity={page.entity.name} onSaved={() => loadRecords(page.entity.name, { page: 1, sort: "NEWEST_FIRST" })} />
      )}

      {page !== null && (tab === "records" || tab === "sources" || !["metadata", "add", "source-metadata", "edit", "merge"].includes(tab)) && (
        <div className="b360-records master-detail" data-testid="b360-records" data-entity={page.entity.name}>
          <section className="b360-master" data-testid="b360-master">
            <h3>
              {tab === "sources" ? "Pick a master record: " : "Master: "}
              {page.entity.label} root
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
                  <Input
                    type="text"
                    aria-label={`Filter ${label}`}
                    data-testid={testId}
                    value={draft[key]}
                    placeholder={key === "businessId" ? "exact" : "starts with"}
                    onValueChange={(v: string) => setDraft((d) => ({ ...d, [key]: v }))}
                    onKeyDown={(e: React.KeyboardEvent<HTMLInputElement>) => {
                      if (e.key === "Enter") applyFilters();
                    }}
                  />
                </label>
              ))}
              <Button aria-label="Apply filters" data-testid="b360-filter-apply" onClick={applyFilters} disabled={loading}>
                Apply
              </Button>
              <Button aria-label="Clear filters" data-testid="b360-filter-clear" onClick={clearFilters} disabled={loading}>
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
              <Button aria-label="Previous page" data-testid="b360-page-prev" onClick={() => goPage((page.page ?? 1) - 1)} disabled={loading || (page.page ?? 1) <= 1}>
                Prev
              </Button>
              <span data-testid="b360-page-info">
                Page {page.page ?? 1} of {page.total_pages ?? 1} ({(page.hits ?? page.records.length).toLocaleString()} records)
              </span>
              <Button
                aria-label="Next page"
                data-testid="b360-page-next"
                onClick={() => goPage((page.page ?? 1) + 1)}
                disabled={loading || (page.page ?? 1) >= (page.total_pages ?? 1)}
              >
                Next
              </Button>
            </div>
            {(page.visibility?.hidden ?? []).length > 0 && (
              <p className="muted small" data-testid="b360-hidden-fields">
                Hidden by b360_entities.toml: {(page.visibility?.hidden ?? []).join(", ")} (Metadata tab shows all).
              </p>
            )}
            {(page.visibility?.warnings ?? []).map((w) => (
              <p key={w} className="small visibility-warn" data-testid="b360-visibility-warning">
                Warning: {w}
              </p>
            ))}
            {page.unknown_keys.length > 0 && (
              <p className="muted small" data-testid="b360-unknown-keys">
                Not in the metadata (not shown): {page.unknown_keys.join(", ")}
              </p>
            )}
            {page.records.length === 0 ? (
              <p className="muted">No records.</p>
            ) : (
              <>
              <div className="records-scroll" data-testid="b360-records-scroll">
                <table className="monitor" data-testid="b360-records-table" aria-label="Master records">
                  <thead>
                    <tr>
                      <th>Business id</th>
                      <th>
                        <Button
                          className="sort-head"
                          aria-label="Sort by Last updated"
                          data-testid="b360-sort-updated"
                          data-sort={query.sort ?? "NEWEST_FIRST"}
                          title="Sort all records by last update (any channel): click to flip"
                          onClick={toggleSort}
                          disabled={loading || page.mode === "BUSINESS_ID"}
                        >
                          Last updated {query.sort === "OLDEST_FIRST" ? "(oldest first) ^" : "(newest first) v"}
                        </Button>
                      </th>
                      {recordColumns(page.entity).filter((f) => isShown(page.visibility, f.name)).map((f) => (
                        <th key={f.name} title={`${f.name} (${f.data_type})`}>{f.label}</th>
                      ))}
                      {(page.system_columns ?? []).filter((c) => isSystemColumnShown(page.visibility, c.name)).map((c) => (
                        <th key={c.name} className="system-col" data-origin="SYSTEM" title={`${c.name} (system)`}>
                          {c.name}
                        </th>
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
                        <td>
                          {/* 0.9.12.1: the row is the picker (no box above the table); this labelled
                              button is the agent's handle. */}
                          <Button
                            className="row-open"
                            aria-label={`Open master record ${r.business_id}`}
                            data-testid={`b360-open-${r.business_id}`}
                            onClick={() => setSelected((s) => ({ ...s, record: r.business_id }))}
                          >
                            <code>{r.business_id}</code>
                          </Button>
                        </td>
                        <td data-testid={`b360-updated-${r.business_id}`} title={r.updated_by ? `by ${r.updated_by}` : undefined}>
                          {lastUpdatedText(r.last_updated)}
                        </td>
                        {recordColumns(page.entity).filter((f) => isShown(page.visibility, f.name)).map((f) => (
                          <td key={f.name}>{cellText(r.values[f.name], f.data_type)}</td>
                        ))}
                        {(page.system_columns ?? []).filter((c) => isSystemColumnShown(page.visibility, c.name)).map((c) => (
                          <td key={c.name} className="system-col" data-origin="SYSTEM">
                            {systemValueText(c.name, systemValue(r.system_values, c.name))}
                          </td>
                        ))}
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
              </>
            )}
          </section>
          {tab !== "sources" && record !== null && <RecordDetail page={page} record={record} />}
          {tab === "sources" && <SourceRecordsView entity={page.entity} businessId={selected.record} onEdit={openEdit} />}
        </div>
      )}
    </div>
  );
}
