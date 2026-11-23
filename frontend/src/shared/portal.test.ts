// 0.9.15 Addendum A: portal URLs are built ONLY in the backend (app/common/portal.py).
// Guard: no frontend source spells the portal path, so nobody concatenates one here.
import { readdirSync, readFileSync, statSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";

const SRC = join(__dirname, "..");
const SELF = "portal.test.ts";

function files(dir: string): string[] {
  return readdirSync(dir).flatMap((name) => {
    const path = join(dir, name);
    if (statSync(path).isDirectory()) return files(path);
    return (name.endsWith(".ts") || name.endsWith(".tsx")) && name !== SELF && name !== "api-types.ts" ? [path] : [];
  });
}

describe("portal links", () => {
  it("no frontend file builds an IDMC portal URL itself", () => {
    const hits = files(SRC).filter((f) => {
      const text = readFileSync(f, "utf8");
      return ["jobDetails", "ui-config-app", "diUI", "processinstance", "%7B%7D"].some((w) => text.includes(w));
    });
    expect(hits).toEqual([]);
  });
});
