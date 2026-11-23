import { describe, expect, it } from "vitest";
import { clockColour } from "./RunProgress";

describe("poll clock", () => {
  it("changes colour on every poll and cycles", () => {
    expect(clockColour(1)).not.toBe(clockColour(2));
    expect(clockColour(2)).not.toBe(clockColour(3));
    expect(clockColour(0)).toBe(clockColour(4));
  });
});
