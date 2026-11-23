import { describe, expect, it } from "vitest";
import { DESIGNASSETTYPE_VALUES } from "../b360/api-types";
import { RIBBON, ribbonTab } from "../shell/sections";
import { asAssetType, byText, detailUrl, listUrl, openDesignAsset, selectedAsset, whenText } from "./designApi";

describe("Design notebook", () => {
  it("ribbon tabs are exactly the backend asset types, Mapping task first", () => {
    expect(RIBBON.design.map((t) => t.id)).toEqual([...DESIGNASSETTYPE_VALUES]);
    expect(RIBBON.design[0]?.label).toBe("Mapping task");
  });

  it("builds typed urls, encodes ids", () => {
    expect(listUrl("MTT")).toBe("/api/design/assets/MTT");
    expect(detailUrl("CONNECTION", "a b")).toBe("/api/design/assets/CONNECTION/a%20b");
  });

  it("tab id maps to an asset type", () => {
    expect(asAssetType("TASKFLOW")).toBe("TASKFLOW");
    expect(asAssetType("nope")).toBe("MTT");
  });

  it("opening a child switches the type tab and selects it", () => {
    openDesignAsset("MTT", "FED5");
    expect(ribbonTab("design")).toBe("MTT");
    openDesignAsset("DTEMPLATE", "MAP5");
    expect(ribbonTab("design")).toBe("DTEMPLATE");
    expect(selectedAsset("DTEMPLATE")).toBe("MAP5");
    expect(selectedAsset("MTT")).toBe("FED5");
  });

  it("shows '-' for missing values", () => {
    expect(whenText(null)).toBe("-");
    expect(byText("")).toBe("-");
    expect(whenText("2026-11-22T21:30:00Z")).not.toBe("-");
  });
});
