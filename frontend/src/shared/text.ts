// 0.9.13 (Vamsi 02:35 CST: "no parsing by strings ... regex ... It has to be typed"): the few
// places that read text a PERSON typed or the browser URL go through these character-set helpers
// (no regular expressions, no string splitting). Everything else passes typed objects.

export const WHITESPACE: ReadonlySet<string> = new Set([" ", "\t", "\n", "\r"]);
export const ID_LIST_SEPARATORS: ReadonlySet<string> = new Set([...WHITESPACE, ",", ";"]);
export const QUOTES: ReadonlySet<string> = new Set(['"', "'"]);
export const SLASH: ReadonlySet<string> = new Set(["/"]);
const DIGITS: ReadonlySet<string> = new Set(["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]);

/** Non-empty runs of characters between separators. */
export function tokens(text: string, separators: ReadonlySet<string>): string[] {
  const out: string[] = [];
  let current = "";
  for (const ch of text) {
    if (separators.has(ch)) {
      if (current !== "") out.push(current);
      current = "";
    } else {
      current += ch;
    }
  }
  if (current !== "") out.push(current);
  return out;
}

/** Drop the given characters from both ends. */
export function trimChars(text: string, chars: ReadonlySet<string>): string {
  const all = [...text];
  let start = 0;
  let end = all.length;
  while (start < end && chars.has(all[start] ?? "")) start += 1;
  while (end > start && chars.has(all[end - 1] ?? "")) end -= 1;
  return all.slice(start, end).join("");
}

/** 1..max decimal digits, nothing else. */
export function isDigits(text: string, max: number): boolean {
  const all = [...text];
  return all.length >= 1 && all.length <= max && all.every((ch) => DIGITS.has(ch));
}
