import { describe, expect, it } from "vitest";
import { cleanRunId, groupHistory, paramsOf, statusLabel, type HistoryRow, type TaskflowRunStatus } from "./taskflowApi";

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

describe("aborted taskflow runs", () => {
  it("labels a run a person terminated as ABORTED, keeping IDMC's own word", () => {
    // Seen live 2026-11-22 23:21 CST: IDMC reports FAILED + code processManuallyTerminated.
    expect(statusLabel({ status: "FAILED", state_text: "FAILED", aborted: true })).toBe("ABORTED (IDMC: FAILED)");
    expect(statusLabel({ status: "FAILED", state_text: "FAILED", aborted: false })).toBe("FAILED");
  });
});

describe("grouped run history (0.9.2)", () => {
  const row = (over: Partial<HistoryRow>): HistoryRow =>
    ({
      run_id: null, level: "child", task_name: "mt_m_X", task_type: "MTT", source: "monitor",
      trackable: false, status: "SUCCESS", state_text: "SUCCESS", is_running: false,
      started_at: null, ended_at: null, elapsed_minutes: null, rows_ok: null, rows_failed: null,
      error: "", started_by: "", ...over,
    }) as HistoryRow;

  it("puts each child mapping task under the taskflow run whose window holds its start", () => {
    const parent = row({ run_id: "1309401111111112288", level: "taskflow", task_name: "tf_X", trackable: true,
      is_running: true, status: "RUNNING", started_at: "2026-11-23T06:35:00Z" });
    const old = row({ run_id: "1309400000000000001", level: "taskflow", task_name: "tf_X", trackable: true,
      started_at: "2026-11-23T06:00:00Z", ended_at: "2026-11-23T06:05:00Z" });
    const child = row({ run_id: "10", is_running: true, started_at: "2026-11-23T06:35:09Z" });
    const oldChild = row({ run_id: "9", started_at: "2026-11-23T06:00:10Z" });
    const stray = row({ run_id: "3", started_at: "2026-11-22T01:00:00Z" });
    const groups = groupHistory([old, oldChild, stray, child, parent], Date.parse("2026-11-23T06:40:00Z"));
    expect(groups[0]?.parent?.run_id).toBe("1309401111111112288");
    expect(groups[0]?.children.map((c) => c.run_id)).toEqual(["10"]);
    expect(groups[1]?.children.map((c) => c.run_id)).toEqual(["9"]);
    expect(groups[2]?.parent).toBeNull();
    expect(groups[2]?.children[0]?.run_id).toBe("3");
  });
});
