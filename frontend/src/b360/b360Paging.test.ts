// 0.9.9: Records query string (paging, filters, sort) and the Last updated cell.
import { describe, expect, it } from "vitest";
import { lastUpdatedText, recordsQuery } from "./b360Api";

describe("recordsQuery", () => {
  it("defaults to page 1, newest first, no filters", () => {
    expect(recordsQuery(10)).toBe("limit=10&page=1&sort=NEWEST_FIRST");
  });
  it("adds trimmed non-empty filters only", () => {
    const q = new URLSearchParams(recordsQuery(10, { page: 3, firstName: " ann ", lastName: "", sort: "OLDEST_FIRST" }));
    expect(q.get("page")).toBe("3");
    expect(q.get("first_name")).toBe("ann");
    expect(q.has("last_name")).toBe(false);
    expect(q.get("sort")).toBe("OLDEST_FIRST");
  });
  it("passes the business id", () => {
    expect(new URLSearchParams(recordsQuery(10, { businessId: "300000000000000000000000005" })).get("business_id")).toBe(
      "300000000000000000000000005",
    );
  });
});

describe("lastUpdatedText", () => {
  it("shows a dash when absent", () => {
    expect(lastUpdatedText(null)).toBe("-");
    expect(lastUpdatedText(undefined)).toBe("-");
  });
  it("uses toLocaleString for a timestamp", () => {
    const iso = "2026-11-01T12:00:00Z";
    expect(lastUpdatedText(iso)).toBe(new Date(iso).toLocaleString());
  });
});
