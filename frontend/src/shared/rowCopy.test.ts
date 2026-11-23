import { describe, expect, it } from "vitest";
import { copyMessage } from "./clipboard";
import { rowToTsv, tsvCell } from "./rowCopy";

describe("0.9.13.1 row copy (Ctrl+C) as TSV", () => {
  it("header line + value line, tab separated, nested rows as compact JSON", () => {
    const tsv = rowToTsv({
      headers: ["Business id", "First name", "Active", "x_phone"],
      cells: ["100000000000141", "Charles", true, [{ cntry_cd: 1, ph_num: 5125550100, ph_typ: "Cell" }]],
    });
    expect(tsv).toBe(
      'Business id\tFirst name\tActive\tx_phone\n100000000000141\tCharles\ttrue\t[{"cntry_cd":1,"ph_num":5125550100,"ph_typ":"Cell"}]\n',
    );
  });
  it("no tabs / line breaks inside a cell; null is empty; ASCII only", () => {
    expect(tsvCell("a\tb\nc")).toBe("a b c");
    expect(tsvCell(null)).toBe("");
    expect(tsvCell(undefined)).toBe("");
    expect(tsvCell("caf\u00e9")).toBe("caf?");
  });
  it("clipboard messages", () => {
    expect(copyMessage({ ok: true })).toBe("Text copied to the clipboard.");
    expect(copyMessage({ ok: true }, "Row")).toBe("Row copied to the clipboard.");
    expect(copyMessage({ ok: false, reason: "denied" })).toBe("Could not copy to the clipboard: denied");
  });
});
