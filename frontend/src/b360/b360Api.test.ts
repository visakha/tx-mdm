import { describe, expect, it } from "vitest";
import type { BusinessEntity, EntityRecord, FieldDataType } from "./api-types";
import { FIELDDATATYPE_VALUES } from "./api-types";
import type { FormField, FormGroup } from "./api-types";
import { addSaveBlockers, clampCount, cleanValues, pendingChanges, isFieldShown, isGroupFieldShown, isGroupShown, isMetaShown, missingRequired, parseBusinessIds, parseInput, winnersToSend } from "./b360Api";
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

describe("Add records helpers (0.9.8)", () => {
  it("clamps the Number of records box to 1..100", () => {
    expect([clampCount("0"), clampCount("5"), clampCount("250"), clampCount("x")]).toEqual([1, 5, 100, 5]);
  });
  it("parses form text by input kind", () => {
    expect(parseInput("", "TEXT")).toBeNull();
    expect(parseInput(" 42 ", "INTEGER")).toBe(42);
    expect(parseInput("true", "CHECKBOX")).toBe(true);
    expect(parseInput("Ann", "TEXT")).toBe("Ann");
  });
  it("lists empty required fields and drops empties", () => {
    const fields = [
      { name: "first_name", label: "First Name", data_type: "STRING" as const, input: "TEXT" as const, required: true },
      { name: "last_name", label: "Last Name", data_type: "STRING" as const, input: "TEXT" as const, required: false },
    ];
    expect(missingRequired(fields, { last_name: "X" })).toEqual(["First Name"]);
    expect(cleanValues({ first_name: "A", last_name: "", x: null })).toEqual({ first_name: "A" });
  });
});


describe("0.10 field visibility (b360_entities.toml fields list)", () => {
  it("0.9.13: typed FieldPath visibility; no list shows all", () => {
    const vis = {
      hidden: [
        { kind: "FIELD" as const, field: "first_name" },
        { kind: "GROUP_FIELD" as const, group: "x_phone", field: "ph_num" },
      ],
      meta_hidden: false,
      hidden_meta_keys: ["lastUpdateDate"],
    };
    expect(isFieldShown(vis, "first_name")).toBe(false);
    expect(isFieldShown(vis, "last_name")).toBe(true);
    expect(isGroupFieldShown(vis, "x_phone", "ph_num")).toBe(false);
    expect(isGroupFieldShown(vis, "x_phone", "ph_typ")).toBe(true);
    expect(isGroupShown(vis, "x_phone")).toBe(true);
    expect(isFieldShown(undefined, "first_name")).toBe(true);
    expect(isMetaShown(vis, ["lastUpdateDate"])).toBe(false);
    expect(isMetaShown(vis, ["states", "base"])).toBe(true);
    expect(isMetaShown({ ...vis, meta_hidden: true }, ["createdBy"])).toBe(false);
  });
});

describe("Merge helpers (0.9.12)", () => {
  it("parses pasted business ids, dropping quotes and repeats", () => {
    expect(parseBusinessIds(' 100000000000141, "100000000000150"\t100000000000141 ')).toEqual(["100000000000141", "100000000000150"]);
  });
  it("sends only picked winners and never clns_ followers", () => {
    const picks = { first_name: "141", last_name: "150", clns_first_name: "141", do_not_contact_ind: "" };
    expect(winnersToSend(picks, new Set(["clns_first_name"]))).toEqual({ first_name: "141", last_name: "150" });
  });
});

describe("0.9.13.1 Edit records (S): pending changes computed locally", () => {
  const fields = [
    { name: "first_name", label: "First name", required: true, input: "TEXT" },
    { name: "last_name", label: "Last name", required: false, input: "TEXT" },
  ] as unknown as FormField[];
  const groupsDef = [
    { name: "x_phone", label: "Phone", cardinality: "MANY", fields: [{ name: "ph_num", label: "ph_num", required: false, input: "INTEGER" }] },
  ] as unknown as FormGroup[];
  const loaded = {
    values: { first_name: "Charles", last_name: "Montoya" },
    groups: [{ group: "x_phone", rows: [{ row_id: "r1", values: { ph_num: 5125550100 } }] }],
  };
  it("no edit -> no changes (Save stays disabled)", () => {
    expect(pendingChanges(fields, groupsDef, loaded, { ...loaded.values }, { x_phone: loaded.groups[0]?.rows ?? [] })).toEqual([]);
  });
  it("one root edit -> one CHANGED; empty string counts as null", () => {
    const c = pendingChanges(fields, groupsDef, loaded, { first_name: "Charles", last_name: "Harrison" }, { x_phone: loaded.groups[0]?.rows ?? [] });
    expect(c).toEqual([{ kind: "CHANGED", group: null, row: null, field: "last_name", old: "Montoya", new: "Harrison" }]);
    expect(pendingChanges(fields, [], { values: { last_name: null }, groups: [] }, { last_name: "" }, {})).toEqual([]);
  });
  it("group rows: changed cell, added row, removed row", () => {
    const changed = pendingChanges(fields, groupsDef, loaded, { ...loaded.values }, { x_phone: [{ row_id: "r1", values: { ph_num: 5125550199 } }] });
    expect(changed[0]).toMatchObject({ kind: "CHANGED", group: "x_phone", row: 1, field: "ph_num" });
    const added = pendingChanges(fields, groupsDef, loaded, { ...loaded.values }, {
      x_phone: [...(loaded.groups[0]?.rows ?? []), { row_id: null, values: { ph_num: 5125550111 } }],
    });
    expect(added).toEqual([{ kind: "ROW_ADDED", group: "x_phone", row: 2, field: "ph_num", old: null, new: 5125550111 }]);
    const removed = pendingChanges(fields, groupsDef, loaded, { ...loaded.values }, { x_phone: [] });
    expect(removed).toEqual([{ kind: "ROW_REMOVED", group: "x_phone", row: null, field: null, old: "r1", new: null }]);
  });
  it("Add records Type it: why Save is disabled, in words", () => {
    expect(addSaveBlockers("", fields, {})).toEqual(["pick a source system", "first_name is required"]);
    expect(addSaveBlockers("zlv_ttf", fields, { first_name: "Ann" })).toEqual([]);
  });
});
