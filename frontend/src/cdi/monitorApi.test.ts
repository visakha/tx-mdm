import { describe, expect, it } from "vitest";
import { elapsedText, minutesText, summarize, type MonitorEntry } from "./monitorApi";

function entry(status: MonitorEntry["status"]): MonitorEntry {
  return {
    task_name: "t",
    task_type: "MTT",
    run_id: null,
    status,
    state_text: status,
    started_at: null,
    ended_at: null,
    elapsed_minutes: null,
    counts: { source_success: null, source_failed: null, target_success: null, target_failed: null },
    error: "",
    started_by: "",
    run_context: "",
    in_my_tasks: true,
    children: [],
  };
}

describe("monitor helpers", () => {
  it("formats elapsed time as minutes and seconds", () => {
    const start = "2026-11-22T12:00:00Z";
    expect(elapsedText(start, Date.parse("2026-11-22T12:12:05Z"))).toBe("12m 05s");
    expect(elapsedText(null, 1)).toBe("-");
  });

  it("formats minutes", () => {
    expect(minutesText(12.5)).toBe("12.5 min");
    expect(minutesText(null)).toBe("-");
  });

  it("summarizes statuses", () => {
    expect(summarize([entry("SUCCESS"), entry("FAILED"), entry("WARNING")])).toEqual({
      ok: 1,
      failed: 1,
      other: 1,
    });
  });
});
