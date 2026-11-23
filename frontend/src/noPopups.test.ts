// Guard (0.9.10): no pop-ups anywhere in the app, by owner decision 2026-11-23 01:53 CST
// ("Take it out."). Fails on ANY window.confirm / alert / prompt call in frontend/src, no exceptions.
// Results and errors show inline on the page instead.

import { readdirSync, readFileSync, statSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";

const SRC = join(__dirname);
const SELF = "noPopups.test.ts";
const POPUP = /\b(?:window\.)?(?:confirm|alert|prompt)\s*\(/;

function sourceFiles(dir: string): string[] {
  return readdirSync(dir).flatMap((name) => {
    const path = join(dir, name);
    if (statSync(path).isDirectory()) return sourceFiles(path);
    return /\.(ts|tsx)$/.test(name) && name !== SELF ? [path] : [];
  });
}

describe("no pop-ups", () => {
  it("has no window.confirm / alert / prompt call in frontend/src", () => {
    const hits = sourceFiles(SRC).flatMap((file) =>
      readFileSync(file, "utf8")
        .split("\n")
        .map((line, i) => ({ line, at: `${file.slice(SRC.length + 1)}:${i + 1}` }))
        .filter(({ line }) => POPUP.test(line) && !line.trimStart().startsWith("//"))
        .map(({ at, line }) => `${at}: ${line.trim()}`),
    );
    expect(hits).toEqual([]);
  });
});
