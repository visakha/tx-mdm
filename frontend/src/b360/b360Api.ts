// B360 Data notebook (0.9.5): read-only backend calls. Types come from api-types.ts, which is
// GENERATED from the backend Pydantic models (npm run gen:types) - never hand-edit them here.

import { getJson, postJson } from "../shared/api";
import type {
  BusinessEntity,
  BusinessEntityList,
  BusinessEntitySummary,
  EntityCategory,
  EntityField,
  EntityRecord,
  EntityScope,
  CreateRequest,
  CreateResponse,
  FieldDataType,
  FormField,
  FormInput,
  FormSchema,
  GeneratedRows,
  MergePreview,
  MergeRequest,
  MergeResponse,
  NewRecord,
  NewGroupRows,
  RecordPage,
  SortOrder,
  SourceRecord,
  SourceMetadata,
  SourceRecordList,
  SourceRecordPage,
  SourceSystemList,
  SystemValue,
  UnmergeRequest,
  UnmergeResponse,
  UpdateSourceRequest,
  UpdateSourceResponse,
} from "./api-types";

export type { BusinessEntity, BusinessEntityList, EntityField, EntityRecord, RecordPage, SortOrder };

/** 0.9.9 Records query: page (1-based), name filters (STARTS_WITH), exact Business ID, sort. */
export interface RecordQuery {
  page?: number;
  firstName?: string;
  lastName?: string;
  businessId?: string;
  sort?: SortOrder;
}

/** Query string for GET /records. Empty filters are left out; only Last updated sorts. */
export function recordsQuery(limit: number, q: RecordQuery = {}): string {
  const params = new URLSearchParams({ limit: String(limit), page: String(q.page ?? 1) });
  if (q.firstName?.trim()) params.set("first_name", q.firstName.trim());
  if (q.lastName?.trim()) params.set("last_name", q.lastName.trim());
  if (q.businessId?.trim()) params.set("business_id", q.businessId.trim());
  params.set("sort", q.sort ?? "NEWEST_FIRST");
  return params.toString();
}

/** One cell value, as the backend types it from the field's declared data type. */
export type CellValue = string | number | boolean | null;

export const B360_LIMIT = 10;

function systemsQuery(systems: readonly string[], page: number | null): string {
  const q = new URLSearchParams();
  for (const sys of systems) q.append("source_systems", sys);
  if (page !== null) q.set("page", String(page));
  return q.toString();
}

const base = (name: string): string => `/api/b360/entities/${encodeURIComponent(name)}`;

export const b360Api = {
  /** focus (default) = only the backend's focus list (zlv_guest); all = every entity. */
  entities: (scope: EntityScope = "focus"): Promise<BusinessEntityList> =>
    getJson<BusinessEntityList>(`/api/b360/entities?scope=${scope}`),
  metadata: (name: string): Promise<BusinessEntity> => getJson<BusinessEntity>(`${base(name)}/metadata`),
  records: (name: string, q: RecordQuery = {}, limit = B360_LIMIT): Promise<RecordPage> =>
    getJson<RecordPage>(`${base(name)}/records?${recordsQuery(limit, q)}`),
  // 0.9.8 Add records. Only create() writes to IDMC, and only on a person's Save / Send.
  sourceSystems: (): Promise<SourceSystemList> => getJson<SourceSystemList>("/api/b360/source-systems"),
  formSchema: (name: string): Promise<FormSchema> => getJson<FormSchema>(`${base(name)}/form-schema`),
  generate: (name: string, count: number, seed: number | null = null): Promise<GeneratedRows> =>
    postJson<GeneratedRows>(`${base(name)}/records/generate`, { count, seed }),
  create: (name: string, request: CreateRequest): Promise<CreateResponse> =>
    postJson<CreateResponse>(`${base(name)}/records`, request),
  // 0.9.10 source (xref) records. Only updateSource(dry_run=false) writes, on a person's Save.
  sourceMetadata: (name: string): Promise<BusinessEntity> => getJson<BusinessEntity>(`${base(name)}/source-metadata`),
  // 0.9.12.3 source-specific Records (S) / Metadata (S): repeated source_systems parameter.
  sourceRecordsBySystem: (name: string, systems: readonly string[], page = 1): Promise<SourceRecordPage> =>
    getJson<SourceRecordPage>(`${base(name)}/source-records?${systemsQuery(systems, page)}`),
  sourceMetadataBySystem: (name: string, systems: readonly string[]): Promise<SourceMetadata> =>
    getJson<SourceMetadata>(`${base(name)}/source-metadata/by-system?${systemsQuery(systems, null)}`),
  masterSources: (name: string, businessId: string): Promise<SourceRecordList> =>
    getJson<SourceRecordList>(`${base(name)}/records/${encodeURIComponent(businessId)}/sources`),
  sourceRecord: (name: string, sourceSystem: string, sourcePKey: string): Promise<SourceRecord> =>
    getJson<SourceRecord>(sourceUrl(name, sourceSystem, sourcePKey)),
  updateSource: (name: string, sourceSystem: string, sourcePKey: string, request: UpdateSourceRequest): Promise<UpdateSourceResponse> =>
    postJson<UpdateSourceResponse>(`${sourceUrl(name, sourceSystem, sourcePKey)}/update`, request),
  // 0.9.12 Merge (M). mergePreview reads only; merge() and unmerge() write, on a person's button.
  mergePreview: (name: string, businessIds: string[]): Promise<MergePreview> =>
    postJson<MergePreview>(`${base(name)}/merge/preview`, { business_ids: businessIds }),
  merge: (name: string, request: MergeRequest): Promise<MergeResponse> => postJson<MergeResponse>(`${base(name)}/merge`, request),
  unmerge: (name: string, businessId: string, request: UnmergeRequest): Promise<UnmergeResponse> =>
    postJson<UnmergeResponse>(`${base(name)}/records/${encodeURIComponent(businessId)}/unmerge`, request),
};

/** Business ids typed or pasted into the Merge box: split on spaces, commas, tabs, new lines. */
export function parseBusinessIds(text: string): string[] {
  const out: string[] = [];
  for (const part of text.split(/[\s,;]+/)) {
    const id = part.trim().replace(/^["']|["']$/g, "");
    if (id !== "" && !out.includes(id)) out.push(id);
  }
  return out;
}

/** Winners to send: only fields with a picked id ("" = let IDMC decide), never clns_ followers. */
export function winnersToSend(picks: Record<string, string>, followers: ReadonlySet<string>): Record<string, string> {
  const out: Record<string, string> = {};
  for (const [field, id] of Object.entries(picks)) if (id !== "" && !followers.has(field)) out[field] = id;
  return out;
}

function sourceUrl(name: string, sourceSystem: string, sourcePKey: string): string {
  return `${base(name)}/sources/${encodeURIComponent(sourceSystem)}/${encodeURIComponent(sourcePKey)}`;
}

export type {
  CreateResponse,
  MergePreview,
  MergeResponse,
  FormField,
  FormSchema,
  GeneratedRows,
  NewGroupRows,
  NewRecord,
  SourceRecord,
  SourceMetadata,
  SourceRecordList,
  SourceRecordPage,
  SourceSystemList,
  SystemValue,
  UpdateSourceResponse,
};

export const MAX_ADD = 100;

/** Clamp the "Number of records" box to 1..100 (default 5 for anything unreadable). */
export function clampCount(text: string): number {
  const n = Number.parseInt(text, 10);
  if (!Number.isFinite(n)) return 5;
  return Math.min(MAX_ADD, Math.max(1, n));
}

/** Form text -> typed value for the field's input kind. "" means not given (null). */
export function parseInput(text: string, input: FormInput): CellValue {
  const t = text.trim();
  if (input === "CHECKBOX") return t === "true";
  if (t === "") return null;
  if (input === "INTEGER" || input === "DECIMAL") {
    const n = Number(t);
    return Number.isFinite(n) ? n : t; // the backend's dynamic model reports a bad number
  }
  return t;
}

/** Required fields that are still empty, by label. */
export function missingRequired(fields: readonly FormField[], values: Record<string, CellValue>): string[] {
  return fields
    .filter((f) => f.required && (values[f.name] === null || values[f.name] === undefined || values[f.name] === ""))
    .map((f) => f.label);
}

/** Drop empty values so the backend sees "not given", not "". */
export function cleanValues(values: Record<string, CellValue>): Record<string, CellValue> {
  const out: Record<string, CellValue> = {};
  for (const [k, v] of Object.entries(values)) if (v !== null && v !== "") out[k] = v;
  return out;
}

/** Display text of one cell; dates/datetimes arrive as ISO strings. */
export function cellText(value: CellValue | undefined, type: FieldDataType): string {
  if (value === null || value === undefined || value === "") return "-";
  switch (type) {
    case "BOOLEAN":
      return value === true ? "Yes" : value === false ? "No" : String(value);
    case "INTEGER":
    case "DOUBLE":
    case "DECIMAL":
      return typeof value === "number" ? value.toLocaleString() : String(value);
    case "DATETIME":
      return typeof value === "string" && !Number.isNaN(Date.parse(value))
        ? new Date(value).toLocaleString()
        : String(value);
    case "STRING":
    case "PICKLIST":
    case "DEPENDENT_PICKLIST":
    case "DATE":
    case "UNKNOWN":
      return String(value);
  }
}

/** Rows of one field group of a record (empty when the record has none). */
export function groupRows(record: EntityRecord, group: string): Record<string, CellValue>[] {
  return record.groups.find((g) => g.group === group)?.rows ?? [];
}

/** Columns of the records table: every top-level field the metadata declares. */
export function recordColumns(entity: BusinessEntity): readonly EntityField[] {
  return entity.fields;
}

/** 0.9.7: group order and headings for "Show all entities". Category comes from the backend. */
export const CATEGORY_ORDER: readonly EntityCategory[] = ["CUSTOM", "OUT_OF_THE_BOX", "REFERENCE", "TEMPLATE"];
export const CATEGORY_LABEL: Record<EntityCategory, string> = {
  CUSTOM: "Custom",
  OUT_OF_THE_BOX: "Out of the box (c360.*)",
  REFERENCE: "Reference (rdm.*)",
  TEMPLATE: "Templates (entity.*)",
};

/** Entities split by category, in CATEGORY_ORDER; empty categories dropped. */
export function groupByCategory(
  entities: readonly BusinessEntitySummary[],
): { category: EntityCategory; entities: BusinessEntitySummary[] }[] {
  return CATEGORY_ORDER.map((category) => ({
    category,
    entities: entities.filter((e) => e.category === category),
  })).filter((g) => g.entities.length > 0);
}

/** One B360 Data left-pane entry, built from scope=focus (backend/b360_entities.toml). */
export interface FocusNavItem {
  /** Listbox value: "entity:<name>". */
  value: string;
  name: string;
  label: string;
  /** False = listed in the TOML but not in the org metadata ("not found in org"). */
  found: boolean;
}

export const SHOW_ALL_VALUE = "b360:all";

/** Left-pane entries in TOML order. Search text filters by label, name or "b360 data". */
export function focusNavItems(list: BusinessEntityList | null, search = ""): FocusNavItem[] {
  if (list === null) return [];
  const needle = search.trim().toLowerCase();
  return list.focus
    .filter((f) => needle === "" || `${f.label} ${f.name} b360 data`.toLowerCase().includes(needle))
    .map((f) => ({ value: `entity:${f.name}`, name: f.name, label: f.label, found: f.found }));
}

/** Which left-pane entry is lit for the open B360 route. */
export function focusNavValue(entity: string | null): string {
  return entity === null ? SHOW_ALL_VALUE : `entity:${entity}`;
}

// One shared copy of the focus list for the left pane, the crumb and the agent bridge.
let focusPromise: Promise<BusinessEntityList> | null = null;
export function readFocus(fresh = false): Promise<BusinessEntityList> {
  if (fresh || focusPromise === null) {
    const next = b360Api.entities("focus");
    focusPromise = next;
    next.catch(() => {
      if (focusPromise === next) focusPromise = null;
    });
  }
  return focusPromise;
}

/** Last updated cell: local date/time like the rest of the app (toLocaleString), "-" if absent. */
export function lastUpdatedText(value: string | null | undefined): string {
  if (value === null || value === undefined || value === "") return "-";
  const d = new Date(value);
  return Number.isNaN(d.getTime()) ? value : d.toLocaleString();
}

/** 0.9.10: drop empty values in every group row, and rows left with nothing (and no _id). */
export function cleanGroups(groups: readonly NewGroupRows[]): NewGroupRows[] {
  return groups.map((g) => ({
    group: g.group,
    rows: g.rows
      .map((r) => ({ row_id: r.row_id ?? null, values: cleanValues(r.values) }))
      .filter((r) => r.row_id !== null || Object.keys(r.values).length > 0),
  }));
}

/** One system value cell: a _meta date (ISO from the backend) as local time, else the text. */
export function systemValueText(name: string, value: CellValue | undefined): string {
  if (value === null || value === undefined || value === "") return "-";
  if (typeof value === "string" && name.toLowerCase().endsWith("date")) return lastUpdatedText(value);
  return String(value);
}

/** The value of one system column in a record (rows from the backend's system_values). */
export function systemValue(values: readonly SystemValue[] | undefined, name: string): CellValue {
  return values?.find((v) => v.name === name)?.value ?? null;
}

/** 0.10: hidden names from b360_entities.toml (fields = [...]); case-insensitive. */
export function isShown(vis: { hidden?: string[] } | undefined, name: string): boolean {
  const wanted = name.toLowerCase();
  return !(vis?.hidden ?? []).some((h) => h.toLowerCase() === wanted);
}

/** A record system column (a _meta key, maybe dotted) is shown unless _meta.<first part> is hidden. */
export function isSystemColumnShown(vis: { hidden?: string[] } | undefined, column: string): boolean {
  return isShown(vis, `_meta.${column.split(".")[0] ?? column}`) && isShown(vis, `_meta.${column}`);
}
