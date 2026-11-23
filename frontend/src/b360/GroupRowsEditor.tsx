// 0.9.10 shared form pieces for Add records (S) and Edit records (S).
// FieldInput: one typed input per field (text / number / checkbox / date / datetime / picklist).
//   Picklists offer ONLY real Codes (FormField.options): from the Reference 360 list the metadata
//   points to (0.9.12), else from real records; when none are known the box is free text.
// GroupRowsEditor: any field group from the metadata as a repeatable block (MANY) or one row (ONE),
//   rows stacked, each editable and removable. Not hardcoded to x_phone.

// 0.9.10 (Vamsi 01:50 CST): UI SDK components (Input, Checkbox, Select, Button), each with a unique
// aria-label so window.agent can find it by name.

import { Button } from "@ui-sdk/react/button";
import { Checkbox, CheckboxIndicator } from "@ui-sdk/react/checkbox";
import { Input } from "@ui-sdk/react/input";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@ui-sdk/react/select";
import type { FormField, FormGroup, NewGroupRow } from "./api-types";
import { parseInput, type CellValue } from "./b360Api";

const NONE = "(none)";

export function FieldInput({
  field,
  value,
  onChange,
  testId,
  label,
}: {
  field: FormField;
  value: CellValue;
  onChange: (v: CellValue) => void;
  testId: string;
  /** Unique aria-label (the agent's handle). */
  label: string;
}): React.JSX.Element {
  if (field.input === "CHECKBOX") {
    return (
      <Checkbox aria-label={label} data-testid={testId} checked={value === true} onCheckedChange={(c) => onChange(c === true)}>
        <CheckboxIndicator aria-hidden="true">x</CheckboxIndicator>
      </Checkbox>
    );
  }
  const options = field.options ?? [];
  if (options.length > 0) {
    const current = value === null || value === undefined ? "" : String(value);
    const known = options.some((o) => o.code === current);
    const items = [
      { value: NONE, label: NONE },
      ...(!known && current !== "" ? [{ value: current, label: `${current} (current)` }] : []),
      ...options.map((o) => ({ value: o.code, label: o.code === o.name ? o.code : `${o.code} - ${o.name}` })),
    ];
    return (
      <Select
        items={items}
        value={current === "" ? NONE : current}
        onValueChange={(v: string | null) => onChange(v === null || v === NONE ? null : v)}
      >
        <SelectTrigger aria-label={label} data-testid={testId}>
          <SelectValue />
        </SelectTrigger>
        <SelectContent>
          {items.map((it) => (
            <SelectItem key={it.value} value={it.value}>
              {it.label}
            </SelectItem>
          ))}
        </SelectContent>
      </Select>
    );
  }
  const kind =
    field.input === "DATE" ? "date" : field.input === "DATETIME" ? "datetime-local" : field.input === "TEXT" ? "text" : "number";
  const pickNote = field.options_source === "NONE" ? "Code (no known values)" : undefined;
  return (
    <Input
      type={kind}
      aria-label={label}
      data-testid={testId}
      value={value === null || value === undefined ? "" : String(value)}
      step={field.input === "DECIMAL" ? "any" : undefined}
      placeholder={pickNote}
      title={pickNote}
      onValueChange={(v: string) => onChange(parseInput(v, field.input))}
    />
  );
}

export function GroupRowsEditor({
  group,
  rows,
  onChange,
  testId,
  scope,
}: {
  group: FormGroup;
  rows: readonly NewGroupRow[];
  onChange: (rows: NewGroupRow[]) => void;
  testId: string;
  /** Prefix that keeps aria-labels unique per screen (e.g. "Add form", "Edit"). */
  scope: string;
}): React.JSX.Element {
  const canAdd = group.cardinality === "MANY" || rows.length === 0;
  const setCell = (i: number, name: string, v: CellValue): void =>
    onChange(rows.map((r, j) => (j === i ? { ...r, values: { ...r.values, [name]: v } } : r)));
  return (
    <section className="b360-group b360-group-editor" data-testid={testId} data-group={group.name}>
      <h4>
        {group.label} <span className="muted small">({group.name}, {group.cardinality})</span>
      </h4>
      {rows.length === 0 && <p className="muted small">No rows.</p>}
      {rows.map((row, i) => (
        <div key={row.row_id ?? `new-${i}`} className="group-row" data-testid={`${testId}-row-${i}`}>
          <table className="monitor kv">
            <tbody>
              {group.fields.map((f) => (
                <tr key={f.name}>
                  <th>
                    {f.label}
                    {f.required ? " *" : ""} <code className="muted small">{f.name}</code>
                  </th>
                  <td>
                    <FieldInput
                      field={f}
                      value={row.values[f.name] ?? null}
                      testId={`${testId}-${i}-${f.name}`}
                      label={`${scope} ${group.label} row ${String(i + 1)} ${f.label}`}
                      onChange={(v) => setCell(i, f.name, v)}
                    />
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
          <div className="toolbar">
            <span className="muted small">{row.row_id ? `_id ${row.row_id}` : "new row"}</span>
            <Button aria-label={`${scope} remove ${group.label} row ${String(i + 1)}`} data-testid={`${testId}-remove-${i}`} onClick={() => onChange(rows.filter((_, j) => j !== i))}>
              Remove row
            </Button>
          </div>
        </div>
      ))}
      {canAdd && (
        <Button aria-label={`${scope} add ${group.label} row`} data-testid={`${testId}-add`} onClick={() => onChange([...rows, { row_id: null, values: {} }])}>
          Add {group.label} row
        </Button>
      )}
    </section>
  );
}
