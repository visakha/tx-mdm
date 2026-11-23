// 0.9.13.1 (Vamsi 03:11 CST): copy straight to the clipboard and say so in one small line; never
// render the copied text on the page. navigator.clipboard first, hidden textarea fallback.

export type CopyResult = { ok: true } | { ok: false; reason: string };

function fallbackCopy(text: string): CopyResult {
  const area = document.createElement("textarea");
  area.value = text;
  area.setAttribute("readonly", "");
  area.setAttribute("aria-hidden", "true");
  area.style.position = "fixed";
  area.style.top = "-1000px";
  area.style.opacity = "0";
  document.body.appendChild(area);
  area.select();
  try {
    // execCommand is deprecated but is the documented fallback where the async API is blocked.
    const ok = document.execCommand("copy");
    return ok ? { ok: true } : { ok: false, reason: "the browser refused the copy" };
  } catch (err: unknown) {
    return { ok: false, reason: String(err) };
  } finally {
    document.body.removeChild(area);
  }
}

export async function copyText(text: string): Promise<CopyResult> {
  if (navigator.clipboard !== undefined) {
    try {
      await navigator.clipboard.writeText(text);
      return { ok: true };
    } catch {
      // fall through to the textarea path
    }
  }
  return fallbackCopy(text);
}

export function copyMessage(result: CopyResult, what = "Text"): string {
  return result.ok ? `${what} copied to the clipboard.` : `Could not copy to the clipboard: ${result.reason}`;
}
