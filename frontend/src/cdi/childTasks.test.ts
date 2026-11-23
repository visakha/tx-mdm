import { describe, expect, it } from "vitest";
import type { CdiTask } from "./cdiApi";
import { parentTaskflowOf } from "./TaskflowsPanel";

const tf = (name: string): CdiTask => ({
  id: name, name, type: "TASKFLOW", path: `ZL_Vamsi/ZLV_CDI/${name}`, description: "", updated_at: null, domain: "mdm",
});

describe("0.9.6 child mapping task -> its taskflow (tf_X -> mt_m_X)", () => {
  const flows = [tf("tf_MDM_ZLV_TTF_Guest_Basic"), tf("tf_MDM_ZLV_TTF_Guest_Basic_EGR")];
  it("matches by name, any case", () => {
    expect(parentTaskflowOf("mt_m_MDM_ZLV_TTF_Guest_Basic", flows)).toBe("tf_MDM_ZLV_TTF_Guest_Basic");
    expect(parentTaskflowOf("mt_m_mdm_zlv_ttf_guest_basic_egr", flows)).toBe("tf_MDM_ZLV_TTF_Guest_Basic_EGR");
  });
  it("returns null when no listed taskflow matches", () => {
    expect(parentTaskflowOf("mt_m_MDM_other", flows)).toBeNull();
  });
});
