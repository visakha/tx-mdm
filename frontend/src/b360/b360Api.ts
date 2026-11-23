// B360 Data notebook (0.9.5): read-only backend calls. Types come from api-types.ts, which is
// GENERATED from the backend Pydantic models (npm run gen:types) - never hand-edit them here.

import { getJson } from "../shared/api";
import type {
  BusinessEntity,
  BusinessEntityList,
  BusinessEntitySummary,
  EntityCategory,
  EntityField,
  EntityRecord,
  EntityScope,
  FieldDataType,
  RecordPage,
} from "./api-types";

export type { BusinessEntity, BusinessEntityList, EntityField, EntityRecord, RecordPage };

/** One cell value, as the backend types it from the field's declared data type. */
export type CellValue = string | number | boolean | null;

export const B360_LIMIT = 10;

const base = (name: string): string => `/api/b360/entities/${encodeURIComponent(name)}`;

export const b360Api = {
  /** focus (default) = only the backend's focus list (zlv_guest); all = every entity. */
  entities: (scope: EntityScope = "focus"): Promise<BusinessEntityList> =>
    getJson<BusinessEntityList>(`/api/b360/entities?scope=${scope}`),
  metadata: (name: string): Promise<BusinessEntity> => getJson<BusinessEntity>(`${base(name)}/metadata`),
  records: (name: string, limit = B360_LIMIT): Promise<RecordPage> =>
    getJson<RecordPage>(`${base(name)}/records?limit=${limit}`),
};

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
