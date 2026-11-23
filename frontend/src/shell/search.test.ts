import { describe, expect, it } from "vitest";
import type { CdiTask } from "../cdi/cdiApi";
import type { MdmJob } from "../mdm/mdmApi";
import { searchItems } from "./search";

const task = (id: string, name: string, type: CdiTask["type"], folder = "ZL_Vamsi/ZLV_CDI", domain: CdiTask["domain"] = "cdi"): CdiTask => ({
  id, name, type, path: `${folder}/${name}`, description: "", updated_at: null, domain,
});
const job = (id: string, name: string, kind: MdmJob["kind"]): MdmJob => ({
  asset_id: id, name, path: `ZL_Vamsi/ZLV_MDM/${name}`, description: "", updated_at: null,
  job_definition_id: null, job_type: null, kind, runnable: true, note: "",
});

const TASKS = [
  task("t1", "mt_m_MDM_ZLV_TTF_Guest_Basic", "MTT", "ZL_Vamsi/ZLV_CDI", "mdm"),
  task("t2", "tf_MDM_ZLV_TTF_Guest_Basic", "TASKFLOW", "ZL_Vamsi/ZLV_CDI", "mdm"),
  task("t4", "tf_Stg_MDM_CDI_TTF", "TASKFLOW", "MDM_TTF/CDI_STG"),
  task("t3", "mt_m_Ldg_MDM_CDI_TTF_CLIENTS", "MTT", "MDM_TTF/CDI_LDG"),
];
const JOBS = [job("j1", "Egress ZLV Guest basic Src_TTF", "Egress"), job("j2", "zlv_ingr_guest-basic", "Ingress")];

describe("left-pane item search", () => {
  it("finds tasks, taskflows and jobs by name, any case", () => {
    const hits = searchItems("guest", TASKS, JOBS);
    expect(hits.map((h) => h.kind).sort()).toEqual(["egress", "ingress", "mdm-mapping-task", "mdm-taskflow"]);
  });

  it("needs every typed word; sends MDM taskflows to the Business 360 Taskflows section", () => {
    const [hit] = searchItems("tf_mdm guest", TASKS, JOBS);
    expect(hit?.kind).toBe("mdm-taskflow");
    expect(hit?.taskflowName).toBe("tf_MDM_ZLV_TTF_Guest_Basic");
    expect(hit?.route).toEqual({ screen: "taskflows", service: "mdm", runId: null });
  });

  it("0.9.6: sends MDM child mapping tasks to the Business 360 Taskflows section, read only", () => {
    const [hit] = searchItems("mt_m_mdm", TASKS, JOBS);
    expect(hit?.kind).toBe("mdm-mapping-task");
    expect(hit?.route).toEqual({ screen: "taskflows", service: "mdm", runId: null });
  });

  it("sends CDI taskflows (tf_Stg_*) to the CDI Taskflows section", () => {
    const [hit] = searchItems("tf_stg", TASKS, JOBS);
    expect(hit?.kind).toBe("taskflow");
    expect(hit?.route).toEqual({ screen: "taskflows", service: "cdi", runId: null });
  });

  it("opens a CDI task or MDM job on its own detail route", () => {
    expect(searchItems("clients", TASKS, JOBS)[0]?.route).toEqual({ screen: "job", service: "cdi", jobId: "t3" });
    expect(searchItems("ingr", TASKS, JOBS)[0]?.route).toEqual({ screen: "job", service: "mdm", jobId: "j2" });
  });

  it("returns nothing for empty text and ranks name matches before folder matches", () => {
    expect(searchItems("  ", TASKS, JOBS)).toEqual([]);
    const hits = searchItems("cdi", TASKS, JOBS);
    expect(hits[0]?.name).toBe("mt_m_Ldg_MDM_CDI_TTF_CLIENTS");
  });
});
