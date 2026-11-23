// 0.9.12.4 Copy IDMC curl: the newest X-Idmc-Echo-Id per screen prefix is remembered.
import { afterEach, describe, expect, it, vi } from "vitest";
import { getJson, latestEcho } from "./api";

function reply(url: string, echo: string | null): Response {
  const headers = new Headers({ "Content-Type": "application/json" });
  if (echo !== null) headers.set("X-Idmc-Echo-Id", echo);
  const r = new Response("{}", { status: 200, headers });
  Object.defineProperty(r, "url", { value: url });
  return r;
}

describe("echo store", () => {
  afterEach(() => vi.unstubAllGlobals());

  it("keeps the newest echo id per path prefix", async () => {
    const fetchMock = vi
      .fn()
      .mockResolvedValueOnce(reply("http://localhost:5173/api/b360/entities/zlv_guest/records?page=1", "e1"))
      .mockResolvedValueOnce(reply("http://localhost:5173/api/b360/entities/zlv_guest/source-records", "e2"))
      .mockResolvedValueOnce(reply("http://localhost:5173/api/cdi/taskflows", null));
    vi.stubGlobal("fetch", fetchMock);
    await getJson("/api/b360/entities/zlv_guest/records?page=1");
    await getJson("/api/b360/entities/zlv_guest/source-records");
    await getJson("/api/cdi/taskflows");
    expect(latestEcho("/api/b360/entities/zlv_guest")?.echoId).toBe("e2");
    expect(latestEcho("/api/b360/entities/zlv_guest/records")?.echoId).toBe("e1");
    expect(latestEcho("/api/cdi")).toBeNull();
  });
});
