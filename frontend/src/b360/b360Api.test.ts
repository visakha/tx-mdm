import { describe, expect, it } from "vitest";
import type { BusinessEntity, EntityRecord, FieldDataType } from "./api-types";
import { FIELDDATATYPE_VALUES } from "./api-types";
import { cellText, groupRows, recordColumns } from "./b360Api";

const entity: BusinessEntity = {
  name: "c360.person",
  label: "Person",
  fields: [
    { name: "firstName", label: "First Name", data_type: "STRING", raw_type: "TextField", searchable: true, mandatory: false },
  ],
  field_groups: [{ name: "Phone", label: "Phone", cardinality: "MANY", fields: [] }],
};

const record: EntityRecord = {
  business_id: "1",
  values: { firstName: "Ann" },
  groups: [{ group: "Phone", rows: [{ phoneNumber: "512" }, { phoneNumber: "737" }] }],
};

describe("B360 Data helpers", () => {
  it("formats cells by declared data type", () => {
    expect(cellText(true, "BOOLEAN")).toBe("Yes");
    expect(cellText(null, "STRING")).toBe("-");
    expect(cellText(1200, "INTEGER")).toBe((1200).toLocaleString());
    expect(cellText("2023-04-20", "DATE")).toBe("2023-04-20");
  });
  it("every generated data type has a formatter branch", () => {
    for (const type of FIELDDATATYPE_VALUES as readonly FieldDataType[]) {
      expect(typeof cellText("x", type)).toBe("string");
    }
  });
  it("reads group rows and columns from the typed models", () => {
    expect(groupRows(record, "Phone")).toHaveLength(2);
    expect(groupRows(record, "Email")).toEqual([]);
    expect(recordColumns(entity).map((f) => f.name)).toEqual(["firstName"]);
  });
});
