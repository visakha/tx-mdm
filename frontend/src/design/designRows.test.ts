import { describe, expect, it } from "vitest";
import type { AssetDetail, AssetSummary } from "../b360/api-types";
import { labelledText, payloadText } from "../shared/rowCopy";
import { designCopy, isRowKey, moveHighlight } from "./designApi";

const IDS = ["A", "B", "C"];

describe("0.9.17 Design list keyboard rows", () => {
  it("Up / Down move one row and stop at the ends; Home / End jump", () => {
    expect(moveHighlight(IDS, null, "ArrowDown")).toBe("A");
    expect(moveHighlight(IDS, null, "ArrowUp")).toBe("C");
    expect(moveHighlight(IDS, "A", "ArrowDown")).toBe("B");
    expect(moveHighlight(IDS, "C", "ArrowDown")).toBe("C");
    expect(moveHighlight(IDS, "A", "ArrowUp")).toBe("A");
    expect(moveHighlight(IDS, "B", "Home")).toBe("A");
    expect(moveHighlight(IDS, "B", "End")).toBe("C");
    expect(moveHighlight([], null, "ArrowDown")).toBeNull();
  });

  it("only the four row keys are handled", () => {
    expect(["ArrowUp", "ArrowDown", "Home", "End"].every(isRowKey)).toBe(true);
    expect(isRowKey("c")).toBe(false);
    expect(isRowKey("Enter")).toBe(false);
  });
});

const ASSET: AssetSummary = {
  id: "FED5",
  name: "mt_m_MDM_ZLV_TTF_Guest_Basic_EGR",
  path: "ZL_Vamsi/ZLV_CDI/mt_m_MDM_ZLV_TTF_Guest_Basic_EGR",
  type: "MTT",
  description: "Guest egress",
  updated_at: null,
  updated_by: "VVamsi-idmcdev",
  portal_url: "https://example.invalid/mct/FED5/read",
};

describe("0.9.17 Design Ctrl+C copy", () => {
  it("list row only: labelled lines, says the detail is not loaded", () => {
    const text = labelledText(designCopy("Mapping task", ASSET, null));
    expect(text).toContain("Name: mt_m_MDM_ZLV_TTF_Guest_Basic_EGR\n");
    expect(text).toContain("Type: Mapping task (MTT)\n");
    expect(text).toContain("Path: ZL_Vamsi/ZLV_CDI/mt_m_MDM_ZLV_TTF_Guest_Basic_EGR\n");
    expect(text).toContain("Updated by: VVamsi-idmcdev\n");
    expect(text).toContain("IDMC portal: https://example.invalid/mct/FED5/read\n");
    expect(text).toContain("Detail: not loaded");
  });

  it("with its detail: created, runtime environment, mapping, uses", () => {
    const detail: AssetDetail = {
      type: "MTT",
      label: "Mapping task",
      as_of: "2026-11-23T14:00:00Z",
      id: "FED5",
      v2_id: "0100000Z0001",
      name: ASSET.name,
      path: ASSET.path,
      created_by: "VVamsi-idmcdev",
      runtime_environment: { id: "01000025000000000003", name: "laptop" },
      mapping: { id: "MAP5", name: "m_MDM_ZLV_TTF_Guest_Basic_EGR" },
      uses: [
        { id: "MAP5", name: "m_MDM_ZLV_TTF_Guest_Basic_EGR", path: "x", type: "DTEMPLATE" },
        { id: "C1", name: "ora_mdm_stg", path: "y", type: "Connection" },
      ],
    };
    const text = payloadText(designCopy("Mapping task", ASSET, detail));
    expect(text).toContain("v2 id: 0100000Z0001\n");
    expect(text).toContain("Created by: VVamsi-idmcdev\n");
    expect(text).toContain("Runtime environment: laptop (01000025000000000003)\n");
    expect(text).toContain("Mapping: m_MDM_ZLV_TTF_Guest_Basic_EGR\n");
    expect(text).toContain("Uses: m_MDM_ZLV_TTF_Guest_Basic_EGR (DTEMPLATE), ora_mdm_stg (Connection)\n");
    expect(text).not.toContain("not loaded");
  });

  it("a detail of another asset is ignored", () => {
    const other = { type: "MTT", label: "Mapping task", as_of: "x", id: "FED1", name: "n", path: "p" } as AssetDetail;
    expect(labelledText(designCopy("Mapping task", ASSET, other))).toContain("Detail: not loaded");
  });

  it("ASCII only, no tabs or line breaks inside a value", () => {
    const text = labelledText({ lines: [["Name", "a\tb\nc\u00e9"]] });
    expect(text).toBe("Name: a b c?\n");
  });
});
