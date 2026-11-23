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
      // 0.9.12.2: length bound from the backend (config / metadata / Reference 360).
      maxLength={kind === "text" && field.length ? field.length.max : undefined}
      max={field.input === "INTEGER" && field.length ? 10 ** field.length.max - 1 : undefined}
      min={field.input === "INTEGER" && field.length ? (field.length.exact ? 10 ** (field.length.max - 1) : 0) : undefined}
      placeholder={pickNote}
      title={pickNote}
      onValueChange={(v: string) => onChange(parseInput(v, field.input))}
    />
  );
}

/** A read-only line in the form grid (system / _meta values, magenta label). */
export interface ReadOnlyLine {
  name: string;
  text: string;
}

/**
 * 0.9.13.1 (Vamsi 02:56 CST: "the text boxes they are like up and down, they're not aligned"):
 * ONE form grid for Add records (S) Type it and Edit records (S). Two columns: fixed-width label
 * column (left-aligned), inputs all the same width, height and left edge; checkboxes sit in the
 * input column; system values in the same grid with a magenta label.
 */
export function FieldGrid({
  fields,
  values,
  onChange,
  testIdPrefix,
  labelPrefix,
  ariaLabel,
  extra,
  readOnly,
}: {
  fields: readonly FormField[];
  values: Record<string, CellValue>;
  onChange: (name: string, v: CellValue) => void;
  testIdPrefix: string;
  labelPrefix: string;
  ariaLabel: string;
  /** Extra label / input pairs (e.g. sourcePKey), already wrapped in FormLine. */
  extra?: React.ReactNode;
  readOnly?: readonly ReadOnlyLine[];
}): React.JSX.Element {
  return (
    <div className="form-grid" role="group" aria-label={ariaLabel} data-testid={`${testIdPrefix}grid`}>
      {fields.map((f) => (
        <FormLine key={f.name} label={f.label} required={f.required} name={f.name}>
          <FieldInput
            field={f}
            value={values[f.name] ?? null}
            testId={`${testIdPrefix}${f.name}`}
            label={`${labelPrefix} ${f.label}`}
            onChange={(v) => onChange(f.name, v)}
          />
        </FormLine>
      ))}
      {extra}
      {(readOnly ?? []).map((r) => (
        <div className="form-line system-line" key={r.name} data-origin="SYSTEM">
          <span className="form-label system-text">
            <code>{r.name}</code>
          </span>
          <span className="form-input form-readonly system-text">{r.text}</span>
        </div>
      ))}
    </div>
  );
}

export function FormLine({
  label,
  required,
  name,
  children,
}: {
  label: string;
  required?: boolean;
  name?: string;
  children: React.ReactNode;
}): React.JSX.Element {
  return (
    <div className="form-line">
      <span className="form-label">
        {label}
        {required === true ? " *" : ""}
        {name !== undefined && name !== label && <code className="muted small"> {name}</code>}
      </span>
      <span className="form-input">{children}</span>
    </div>
  );
}

/** Field group rows as a mini table: one row per group row, one column per field. */
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
      {rows.length === 0 ? (
        <p className="muted small">No rows.</p>
      ) : (
        <div className="table-wrap">
          <table className="monitor group-grid" aria-label={`${scope} ${group.label} rows`}>
            <thead>
              <tr>
                <th className="group-grid-n">#</th>
                {group.fields.map((f) => (
                  <th key={f.name} title={f.name}>
                    {f.label}
                    {f.required ? " *" : ""}
                    {f.name !== f.label && <code className="muted small"> {f.name}</code>}
                  </th>
                ))}
                <th>Row</th>
              </tr>
            </thead>
            <tbody>
              {rows.map((row, i) => (
                <tr key={row.row_id ?? `new-${i}`} className="group-row" data-testid={`${testId}-row-${i}`}>
                  <td className="group-grid-n">{i + 1}</td>
                  {group.fields.map((f) => (
                    <td key={f.name} className="form-input">
                      <FieldInput
                        field={f}
                        value={row.values[f.name] ?? null}
                        testId={`${testId}-${i}-${f.name}`}
                        label={`${scope} ${group.label} row ${String(i + 1)} ${f.label}`}
                        onChange={(v) => setCell(i, f.name, v)}
                      />
                    </td>
                  ))}
                  <td className="nowrap">
                    <span className="muted small">{row.row_id ? `_id ${row.row_id}` : "new"}</span>{" "}
                    <Button aria-label={`${scope} remove ${group.label} row ${String(i + 1)}`} data-testid={`${testId}-remove-${i}`} onClick={() => onChange(rows.filter((_, j) => j !== i))}>
                      Remove
                    </Button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
      {canAdd && (
        <Button aria-label={`${scope} add ${group.label} row`} data-testid={`${testId}-add`} onClick={() => onChange([...rows, { row_id: null, values: {} }])}>
          Add {group.label} row
        </Button>
      )}
    </section>
  );
}
