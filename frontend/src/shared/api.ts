// Tiny fetch helper for the FastAPI backend. Errors carry the backend's `detail` text.

export class ApiError extends Error {
  readonly status: number;

  constructor(status: number, message: string) {
    super(message);
    this.status = status;
  }
}

export async function getJson<T>(path: string): Promise<T> {
  return handle<T>(await fetch(path, { headers: { Accept: "application/json" } }));
}

export async function postJson<T>(path: string, body: unknown): Promise<T> {
  return handle<T>(
    await fetch(path, {
      method: "POST",
      headers: { "Content-Type": "application/json", Accept: "application/json" },
      body: JSON.stringify(body),
    }),
  );
}

async function handle<T>(response: Response): Promise<T> {
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
