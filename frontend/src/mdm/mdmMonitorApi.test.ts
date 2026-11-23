import { describe, expect, it } from "vitest";
import { cleanInstanceId, minutes } from "./mdmMonitorApi";
import { POLL_MS, POLL_SECONDS } from "../shared/poll";

describe("Business 360 Currently running helpers", () => {
  it("cleans a pasted instance id without shortening it", () => {
    expect(cleanInstanceId('  "1309395637279657984". ')).toBe("1309395637279657984");
  });
  it("formats minutes", () => {
    expect(minutes(null)).toBe("-");
    expect(minutes(9)).toBe("9.0 min");
  });
  it("every status poll is 15 s", () => {
    expect(POLL_SECONDS).toBe(15);
    expect(POLL_MS).toBe(15000);
  });
});
