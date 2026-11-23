// Tiny fetch helper for the FastAPI backend. Errors carry the backend's `detail` text.

export class ApiError extends Error {
  readonly status: number;

  constructor(status: number, message: string) {
    super(message);
    this.status = status;
  }
}

// ---- 0.9.12.4 Copy IDMC curl: remember which tx-mdm call made which IDMC calls ----

export interface EchoRef {
  readonly method: string;
  readonly apiPath: string;
  readonly echoId: string;
}

const ECHO_KEEP = 50;
const echoListeners = new Set<() => void>();
let echoes: readonly EchoRef[] = [];

function remember(method: string, response: Response): void {
  // Test doubles may carry no headers / url: no echo then.
  const echoId = typeof response.headers?.get === "function" ? response.headers.get("X-Idmc-Echo-Id") : null;
  if (echoId === null || echoId === "" || typeof response.url !== "string" || response.url === "") return;
  const apiPath = new URL(response.url, "http://local").pathname;
  echoes = [{ method, apiPath, echoId }, ...echoes].slice(0, ECHO_KEEP);
  for (const listener of echoListeners) listener();
}

/** Newest echo whose tx-mdm path starts with prefix (one screen = one prefix). exact (0.9.15):
 * the path must equal prefix, so a list view never picks up its detail calls. */
export function latestEcho(prefix: string, exact = false): EchoRef | null {
  return echoes.find((e) => (exact ? e.apiPath === prefix : e.apiPath.startsWith(prefix))) ?? null;
}

export function subscribeEchoes(listener: () => void): () => void {
  echoListeners.add(listener);
  return () => echoListeners.delete(listener);
}

export async function getJson<T>(path: string): Promise<T> {
  return handle<T>(await fetch(path, { headers: { Accept: "application/json" } }), "GET");
}

export async function postJson<T>(path: string, body: unknown): Promise<T> {
  return handle<T>(
    await fetch(path, {
      method: "POST",
      headers: { "Content-Type": "application/json", Accept: "application/json" },
      body: JSON.stringify(body),
    }),
    "POST",
  );
}

/** GET a plain-text body (e.g. a session log). Errors carry the backend's `detail` text. */
export async function getText(path: string): Promise<string> {
  const response = await fetch(path, { headers: { Accept: "text/plain" } });
  remember("GET", response);
  if (response.ok) return response.text();
  throw new ApiError(response.status, await detailOf(response));
}

async function handle<T>(response: Response, method: string): Promise<T> {
  remember(method, response);
  if (response.ok) {
    return (await response.json()) as T;
  }
  throw new ApiError(response.status, await detailOf(response));
}

async function detailOf(response: Response): Promise<string> {
  try {
    const body = (await response.json()) as { detail?: unknown };
    return typeof body.detail === "string" ? body.detail : JSON.stringify(body.detail);
  } catch {
    return `HTTP ${response.status}`;
  }
}

export function errorText(err: unknown): string {
  return err instanceof Error ? err.message : String(err);
}
