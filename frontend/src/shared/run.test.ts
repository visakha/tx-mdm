import { describe, expect, it } from "vitest";
import { isTerminal, statusTone } from "./run";

describe("run status helpers", () => {
  it("treats only final states as terminal", () => {
    expect(isTerminal("SUCCESS")).toBe(true);
    expect(isTerminal("FAILED")).toBe(true);
    expect(isTerminal("WARNING")).toBe(true);
    expect(isTerminal("RUNNING")).toBe(false);
    expect(isTerminal("QUEUED")).toBe(false);
  });

  it("maps statuses to a tone", () => {
    expect(statusTone("SUCCESS")).toBe("ok");
    expect(statusTone("FAILED")).toBe("bad");
    expect(statusTone("RUNNING")).toBe("busy");
    expect(statusTone("WARNING")).toBe("warn");
  });
});
