import { describe, expect, it } from "vitest";
import type { BusinessEntity, EntityRecord, FieldDataType } from "./api-types";
import { FIELDDATATYPE_VALUES } from "./api-types";
import { cellText, focusNavItems, focusNavValue, groupByCategory, groupRows, recordColumns, SHOW_ALL_VALUE } from "./b360Api";

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

describe("0.9.7 entity scope", () => {
  const list = (names: [string, "CUSTOM" | "OUT_OF_THE_BOX" | "REFERENCE" | "TEMPLATE", boolean][]) => ({
    scope: "all" as const, total: names.length, source: "GET x", focus_file: "b360_entities.toml",
    focus: [
      { name: "zlv_guest", label: "ZLV Guest", found: true },
      { name: "not_in_org", label: "not_in_org", found: false },
    ],
    entities: names.map(([name, category, focus]) => ({ name, label: name, category, focus })),
  });
  it("left pane lists the TOML entities in order, marking ones not in the org", () => {
    const items = focusNavItems(list([]));
    expect(items.map((i) => [i.name, i.found])).toEqual([["zlv_guest", true], ["not_in_org", false]]);
    expect(focusNavItems(list([]), "guest").map((i) => i.name)).toEqual(["zlv_guest"]);
    expect(focusNavItems(list([]), "b360 data").length).toBe(2);
    expect(focusNavItems(null)).toEqual([]);
    expect(focusNavValue("zlv_guest")).toBe("entity:zlv_guest");
    expect(focusNavValue(null)).toBe(SHOW_ALL_VALUE);
  });
  it("groups Custom, Out of the box, Reference, Templates in that order", () => {
    const all = list([["rdm.country", "REFERENCE", false], ["c360.person", "OUT_OF_THE_BOX", false], ["zlv_guest", "CUSTOM", true], ["entity.t", "TEMPLATE", false]]);
    expect(groupByCategory(all.entities).map((g) => g.category)).toEqual(["CUSTOM", "OUT_OF_THE_BOX", "REFERENCE", "TEMPLATE"]);
  });
});
