// B360 Data notebook (0.9.5): read-only backend calls. Types come from api-types.ts, which is
// GENERATED from the backend Pydantic models (npm run gen:types) - never hand-edit them here.

import { getJson } from "../shared/api";
import type {
  BusinessEntity,
  BusinessEntityList,
  EntityField,
  EntityRecord,
  FieldDataType,
  RecordPage,
} from "./api-types";

export type { BusinessEntity, BusinessEntityList, EntityField, EntityRecord, RecordPage };

/** One cell value, as the backend types it from the field's declared data type. */
export type CellValue = string | number | boolean | null;

export const B360_LIMIT = 10;

const base = (name: string): string => `/api/b360/entities/${encodeURIComponent(name)}`;

export const b360Api = {
  entities: (): Promise<BusinessEntityList> => getJson<BusinessEntityList>("/api/b360/entities"),
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
