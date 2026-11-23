// 0.9.13.1 (Vamsi 03:01 CST): "when I highlight any data point I would like to do a control C and
// it should copy just that row to the clipboard." Typed row -> TSV (header line + value line, pastes
// into Excel). Nested values (field-group rows) go into their cell as compact JSON. ASCII only.

import { useCallback, useRef, useState } from "react";
import { copyMessage, copyText } from "./clipboard";

export type CopyValue = string | number | boolean | null | undefined | readonly unknown[] | { readonly [k: string]: unknown };

export interface CopyRow {
  headers: readonly string[];
  cells: readonly CopyValue[];
}

const BREAKS: ReadonlySet<string> = new Set(["\t", "\n", "\r"]);

/** One TSV cell: no tabs / line breaks (they would split the row), ASCII only ("?" otherwise). */
export function tsvCell(value: CopyValue): string {
  const text =
    value === null || value === undefined
      ? ""
      : typeof value === "object"
        ? JSON.stringify(value)
        : String(value);
  let out = "";
  for (const ch of text) {
    const code = ch.codePointAt(0) ?? 0;
    out += BREAKS.has(ch) ? " " : code > 126 ? "?" : ch;
  }
  return out;
}

export function rowToTsv(row: CopyRow): string {
  return `${row.headers.map(tsvCell).join("\t")}\n${row.cells.map(tsvCell).join("\t")}\n`;
}

function hasTextSelection(): boolean {
  const sel = window.getSelection();
  return sel !== null && !sel.isCollapsed && sel.toString() !== "";
}

/**
 * Ctrl+C / Cmd+C on a table wrapper copies the highlighted row. A real text selection wins (normal
 * browser copy). Primary path: the copy event's clipboardData; fallback: navigator.clipboard.
 */
export function useRowCopy(current: () => CopyRow | null): {
  onKeyDown: (e: React.KeyboardEvent) => void;
  onCopy: (e: React.ClipboardEvent) => void;
  note: string;
} {
  const [note, setNote] = useState<string>("");
  const pending = useRef<boolean>(false);
  const done = useCallback((): void => {
    setNote("Row copied to the clipboard.");
    window.setTimeout(() => setNote(""), 2500);
  }, []);
  const onCopy = useCallback(
    (e: React.ClipboardEvent): void => {
      pending.current = false;
      if (hasTextSelection()) return;
      const row = current();
      if (row === null) return;
      const text = rowToTsv(row);
      e.preventDefault();
      e.clipboardData.setData("text/plain", text);
      done();
    },
    [current, done],
  );
  const onKeyDown = useCallback(
    (e: React.KeyboardEvent): void => {
      const isCopy = (e.ctrlKey || e.metaKey) && (e.key === "c" || e.key === "C");
      if (!isCopy || hasTextSelection()) return;
      const row = current();
      if (row === null) return;
      pending.current = true;
      window.setTimeout(() => {
        if (!pending.current) return; // the copy event handled it
        pending.current = false;
        const text = rowToTsv(row);
        void copyText(text).then((r) => (r.ok ? done() : setNote(copyMessage(r, "Row"))));
      }, 0);
    },
    [current, done],
  );
  return { onKeyDown, onCopy, note };
}
