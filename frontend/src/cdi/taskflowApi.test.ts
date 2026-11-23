import { describe, expect, it } from "vitest";
import { cleanRunId, paramsOf, statusLabel, type TaskflowRunStatus } from "./taskflowApi";

describe("taskflow helpers", () => {
  it("accepts a pasted IDMC run id and rejects anything else", () => {
    expect(cleanRunId("  1309380263289049088 ")).toBe("1309380263289049088");
    expect(cleanRunId("abc")).toBeNull();
    expect(cleanRunId("")).toBeNull();
  });

  it("shows IDMC's own word when it differs from our status", () => {
    const base = { status: "STOPPED", state_text: "SUSPENDED" } as TaskflowRunStatus;
    expect(statusLabel(base)).toBe("STOPPED (SUSPENDED)");
    expect(statusLabel({ ...base, status: "SUCCESS", state_text: "SUCCESS" })).toBe("SUCCESS");
  });

  it("turns parameter rows into the taskflow JSON body, exact key case", () => {
    expect(
      paramsOf([
        { key: "jobInstanceId", value: "ABC123" },
        { key: " ", value: "ignored" },
      ]),
    ).toEqual({ jobInstanceId: "ABC123" });
  });
});
