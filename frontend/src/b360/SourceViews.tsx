// 0.9.10 Source (xref) views of a B360 entity. Every control sits on a typed backend endpoint
// grounded in a documented B360 call (Vamsi 01:40 CST: "Everything is supported by the backend
// API first"):
//   Records (S): master-driven. Pick a master row above; its sources come from
//     GET /records/{businessId}/sources = Read Source Records by Master Record (p. 70) + Read Source
//     Record per member (p. 80). Or look one up by sourceSystem + sourcePKey (Read Source Record).
//     There is NO "list all source records" view: the reference says source records aren't
//     searchable (p. 82), so the app does not fake one.
//   Edit records (S): Read Source Record -> typed form -> "Show changes" (dry run, the old -> new
//     diff shows inline on the page) -> Save = ONE Update Source Record Field PATCH (pp. 88-90).
//     No pop-up (owner decision 2026-11-23 01:53 CST). No master-record edit anywhere.
// System (_meta) values are magenta with origin SYSTEM; configured fields stay normal colour.

import { useCallback, useEffect, useState } from "react";
import { Button } from "@ui-sdk/react/button";
import { Input } from "@ui-sdk/react/input";
import { Listbox, ListboxItem } from "@ui-sdk/react/listbox";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@ui-sdk/react/select";
import { errorText } from "../shared/api";
import type { BusinessEntity, EntityField, FormSchema, NewGroupRow, NewRecord, SourceRecord } from "./api-types";
import {
  b360Api,
  cellText,
  cleanGroups,
  cleanValues,
  systemValue,
  systemValueText,
  type CellValue,
  type SourceRecordList,
  type UpdateSourceResponse,
} from "./b360Api";
import { FieldInput, GroupRowsEditor } from "./GroupRowsEditor";

export interface SourceKeyPick {
  sourceSystem: string;
  sourcePKey: string;
}

function SourceLookup({
  label,
  testId,
  initial,
  onOpen,
  busy,
}: {
  label: string;
  testId: string;
  initial: SourceKeyPick | null;
  onOpen: (pick: SourceKeyPick) => void;
  busy: boolean;
}): React.JSX.Element {
  const [allowed, setAllowed] = useState<readonly string[]>([]);
  const [system, setSystem] = useState<string>(initial?.sourceSystem ?? "");
  const [pkey, setPkey] = useState<string>(initial?.sourcePKey ?? "");
  useEffect(() => {
    let live = true;
    b360Api
      .sourceSystems()
      .then((s) => {
        if (!live) return;
        setAllowed(s.allowed);
        setSystem((old) => (old !== "" ? old : (s.default ?? s.allowed[0] ?? "")));
      })
      .catch(() => undefined);
    return () => {
      live = false;
    };
  }, []);
  useEffect(() => {
    if (initial !== null) {
      setSystem(initial.sourceSystem);
      setPkey(initial.sourcePKey);
    }
  }, [initial]);
  const items = allowed.includes(system) || system === "" ? allowed : [system, ...allowed];
  const open = (): void => {
    if (system !== "" && pkey.trim() !== "") onOpen({ sourceSystem: system, sourcePKey: pkey.trim() });
  };
  return (
    <div className="toolbar" data-testid={testId}>
      <label>
        Source system{" "}
        <Select items={[...items]} value={system} onValueChange={(v: string | null) => setSystem(v ?? "")}>
          <SelectTrigger aria-label={`${label} source system`} data-testid={`${testId}-system`}>
            <SelectValue />
          </SelectTrigger>
          <SelectContent>
            {items.map((s) => (
              <SelectItem key={s} value={s}>
                {s}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>
      </label>
      <label>
        sourcePKey{" "}
        <Input
          type="text"
          aria-label={`${label} sourcePKey`}
          data-testid={`${testId}-pkey`}
          value={pkey}
          onValueChange={(v: string) => setPkey(v)}
          onKeyDown={(e: React.KeyboardEvent<HTMLInputElement>) => {
            if (e.key === "Enter") open();
          }}
        />
      </label>
      <Button aria-label={`${label} open`} data-testid={`${testId}-open`} onClick={open} disabled={busy || system === "" || pkey.trim() === ""}>
        Open
      </Button>
    </div>
  );
}

function SystemTag(): React.JSX.Element {
  return <span className="system-tag">system</span>;
}

/** Root fields, field groups (stacked) and system values of one source record. */
function SourceDetail({
  entity,
  record,
  onEdit,
}: {
  entity: BusinessEntity;
  record: SourceRecord;
  onEdit: (pick: SourceKeyPick) => void;
}): React.JSX.Element {
  const key = `${record.source_system}/${record.source_pkey}`;
  return (
    <div className="b360-detail" data-testid="b360-source-detail" data-source={key}>
      <div className="toolbar">
        <h3>
          Source record {key} <span className="muted small">(master {record.business_id || "-"})</span>
        </h3>
        <Button
          aria-label={`Edit source record ${key}`}
          data-testid="b360-source-edit"
          onClick={() => onEdit({ sourceSystem: record.source_system, sourcePKey: record.source_pkey })}
        >
          Edit this source record
        </Button>
      </div>
      <section className="b360-group">
        <h4>Root fields</h4>
        <table className="monitor kv" aria-label={`Source ${key} root fields`}>
          <tbody>
            {entity.fields.map((f) => (
              <tr key={f.name}>
                <th title={`${f.name} (${f.data_type})`}>{f.label}</th>
                <td>{cellText(record.values[f.name], f.data_type)}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </section>
      {entity.field_groups.map((g) => {
        const rows = record.groups.find((b) => b.group === g.name)?.rows ?? [];
        return (
          <section key={g.name} className="b360-group" data-testid={`b360-source-group-${g.name}`}>
            <h4>
              {g.label} <span className="count">{rows.length}</span>
            </h4>
            {rows.length === 0 ? (
              <p className="muted">No {g.label} rows.</p>
            ) : (
              <div className="table-wrap">
                <table className="monitor" aria-label={`Source ${key} ${g.label} rows`}>
                  <thead>
                    <tr>
                      <th className="system-col">_id</th>
                      {g.fields.map((f) => (
                        <th key={f.name}>{f.label}</th>
                      ))}
                    </tr>
                  </thead>
                  <tbody>
                    {rows.map((r, i) => (
                      <tr key={r.row_id ?? i}>
                        <td className="system-col">{r.row_id ?? "-"}</td>
                        {g.fields.map((f) => (
                          <td key={f.name}>{cellText(r.values[f.name], f.data_type)}</td>
                        ))}
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </section>
        );
      })}
      {(record.system_values ?? []).length > 0 && (
        <section className="b360-group system-group" data-testid="b360-source-system" data-origin="SYSTEM">
          <h4>
            System fields (_meta) <SystemTag />
          </h4>
          <table className="monitor kv" aria-label={`Source ${key} system fields`}>
            <tbody>
              {(record.system_values ?? []).map((v) => (
                <tr key={v.name} className="system-row" data-origin="SYSTEM">
                  <th>
                    <code>{v.name}</code>
                  </th>
                  <td>{systemValueText(v.name, v.value)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </section>
      )}
    </div>
  );
}

/** Records (S): the sources of the picked master record, plus a sourceSystem + sourcePKey lookup. */
export function SourceRecordsView({
  entity,
  businessId,
  onEdit,
}: {
  entity: BusinessEntity;
  businessId: string | null;
  onEdit: (pick: SourceKeyPick) => void;
}): React.JSX.Element {
  const [list, setList] = useState<SourceRecordList | null>(null);
  const [looked, setLooked] = useState<SourceRecord | null>(null);
  const [picked, setPicked] = useState<string | null>(null);
  const [error, setError] = useState<string>("");
  const [busy, setBusy] = useState<boolean>(false);

  useEffect(() => {
    if (businessId === null) return;
    let live = true;
    setBusy(true);
    setError("");
    setLooked(null);
    b360Api
      .masterSources(entity.name, businessId)
      .then((l) => {
        if (!live) return;
        setList(l);
        setPicked(l.records[0] ? `${l.records[0].source_system}/${l.records[0].source_pkey}` : null);
      })
      .catch((err: unknown) => live && setError(errorText(err)))
      .finally(() => live && setBusy(false));
    return () => {
      live = false;
    };
  }, [entity.name, businessId]);

  const lookup = useCallback(
    (pick: SourceKeyPick): void => {
      setBusy(true);
      setError("");
      b360Api
        .sourceRecord(entity.name, pick.sourceSystem, pick.sourcePKey)
        .then((r) => {
          setLooked(r);
          setPicked(`${r.source_system}/${r.source_pkey}`);
        })
        .catch((err: unknown) => setError(errorText(err)))
        .finally(() => setBusy(false));
    },
    [entity.name],
  );

  const records: readonly SourceRecord[] = looked !== null ? [looked] : (list?.records ?? []);
  const sysCols: readonly EntityField[] = list?.system_columns ?? [];
  const current = records.find((r) => `${r.source_system}/${r.source_pkey}` === picked) ?? null;

  return (
    <section className="b360-sources" data-testid="b360-sources">
      <h3>
        Sources {looked !== null ? `- lookup ${picked ?? ""}` : businessId !== null ? `of master ${businessId}` : ""}
      </h3>
      <SourceLookup label="Records (S) lookup" testId="b360-source-lookup" initial={null} onOpen={lookup} busy={busy} />
      <p className="muted small">
        Pick a master row above to see its source records (Read Source Records by Master Record, then Read Source
        Record each). B360 documents no way to list or search all source records, so there is no such list here.
      </p>
      {error !== "" && <p className="warn-text" data-testid="b360-sources-error">{error}</p>}
      {busy && <p className="muted">Loading...</p>}
      {list?.note !== undefined && list.note !== "" && looked === null && (
        <p className="muted small" data-testid="b360-sources-note">{list.note}</p>
      )}
      {records.length === 0 ? (
        !busy && <p className="muted">No source records.</p>
      ) : (
        <>
        <Listbox
          aria-label="Open source record"
          data-testid="b360-source-picker"
          className="record-picker"
          orientation="horizontal"
          value={picked}
          onValueChange={(value) => {
            if (typeof value === "string") setPicked(value);
          }}
        >
          {records.map((r) => {
            const k = `${r.source_system}/${r.source_pkey}`;
            return (
              <ListboxItem key={k} value={k}>
                {k}
              </ListboxItem>
            );
          })}
        </Listbox>
        <div className="records-scroll" data-testid="b360-sources-scroll">
          <table className="monitor" data-testid="b360-sources-table" aria-label="Source records">
            <thead>
              <tr>
                <th>Source system</th>
                <th>sourcePKey</th>
                {entity.fields.map((f) => (
                  <th key={f.name} title={`${f.name} (${f.data_type})`}>{f.label}</th>
                ))}
                {sysCols.map((c) => (
                  <th key={c.name} className="system-col" data-origin="SYSTEM" title={`${c.name} (system)`}>
                    {c.name}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {records.map((r) => {
                const k = `${r.source_system}/${r.source_pkey}`;
                return (
                  <tr
                    key={k}
                    className={`clickable${k === picked ? " selected" : ""}`}
                    data-testid={`b360-source-${k}`}
                    aria-selected={k === picked}
                    onClick={() => setPicked(k)}
                  >
                    <td>{r.source_system}</td>
                    <td>
                      <code>{r.source_pkey}</code>
                    </td>
                    {entity.fields.map((f) => (
                      <td key={f.name}>{cellText(r.values[f.name], f.data_type)}</td>
                    ))}
                    {sysCols.map((c) => (
                      <td key={c.name} className="system-col" data-origin="SYSTEM">
                        {systemValueText(c.name, systemValue(r.system_values, c.name))}
                      </td>
                    ))}
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
        </>
      )}
      {current !== null && <SourceDetail entity={entity} record={current} onEdit={onEdit} />}
    </section>
  );
}

type GroupState = Record<string, NewGroupRow[]>;

function groupsOf(record: SourceRecord): GroupState {
  const out: GroupState = {};
  for (const g of record.groups) out[g.group] = g.rows.map((r) => ({ row_id: r.row_id ?? null, values: { ...r.values } }));
  return out;
}

function opText(v: CellValue | undefined): string {
  return v === null || v === undefined || v === "" ? "-" : String(v);
}

/** Edit records (S): load, edit, see the diff inline, Save sends one PATCH. */
export function EditSourceView({ entity, initial }: { entity: string; initial: SourceKeyPick | null }): React.JSX.Element {
  const [schema, setSchema] = useState<FormSchema | null>(null);
  const [loaded, setLoaded] = useState<SourceRecord | null>(null);
  const [values, setValues] = useState<Record<string, CellValue>>({});
  const [groups, setGroups] = useState<GroupState>({});
  const [diff, setDiff] = useState<UpdateSourceResponse | null>(null);
  const [saved, setSaved] = useState<UpdateSourceResponse | null>(null);
  const [error, setError] = useState<string>("");
  const [busy, setBusy] = useState<boolean>(false);

  useEffect(() => {
    let live = true;
    b360Api
      .formSchema(entity)
      .then((s) => live && setSchema(s))
      .catch((err: unknown) => live && setError(errorText(err)));
    return () => {
      live = false;
    };
  }, [entity]);

  const load = useCallback(
    (pick: SourceKeyPick): void => {
      setBusy(true);
      setError("");
      setDiff(null);
      setSaved(null);
      b360Api
        .sourceRecord(entity, pick.sourceSystem, pick.sourcePKey)
        .then((r) => {
          setLoaded(r);
          setValues({ ...r.values });
          setGroups(groupsOf(r));
        })
        .catch((err: unknown) => {
          setLoaded(null);
          setError(errorText(err));
        })
        .finally(() => setBusy(false));
    },
    [entity],
  );

  useEffect(() => {
    if (initial !== null) load(initial);
  }, [initial, load]);

  const request = (dryRun: boolean): { original: NewRecord; updated: NewRecord; dry_run: boolean } | null => {
    if (loaded === null || schema === null) return null;
    const names = (schema.groups ?? []).map((g) => g.name);
    return {
      original: { source_pkey: loaded.source_pkey, values: loaded.values, groups: loaded.groups },
      updated: {
        source_pkey: loaded.source_pkey,
        values: cleanValues(values),
        groups: cleanGroups(names.map((n) => ({ group: n, rows: groups[n] ?? [] }))),
      },
      dry_run: dryRun,
    };
  };

  const run = (dryRun: boolean): void => {
    const body = request(dryRun);
    if (body === null || loaded === null) return;
    setBusy(true);
    setError("");
    b360Api
      .updateSource(entity, loaded.source_system, loaded.source_pkey, body)
      .then((r) => {
        if (dryRun) {
          setDiff(r);
          setSaved(null);
        } else {
          setSaved(r);
          setDiff(r);
        }
      })
      .catch((err: unknown) => setError(errorText(err)))
      .finally(() => setBusy(false));
  };

  const edited = (): void => {
    setDiff(null);
    setSaved(null);
  };

  return (
    <div className="b360-edit" data-testid="b360-edit">
      <section className="b360-group">
        <h3>Edit a source record</h3>
        <p className="muted small">
          Source records only (Read Source Record, then Update Source Record Field PATCH with only what changed). There is no
          master-record edit. Source systems come from [sources] allowed in backend/b360_entities.toml.
        </p>
        <SourceLookup label="Edit" testId="b360-edit-lookup" initial={initial} onOpen={load} busy={busy} />
      </section>
      {error !== "" && <p className="warn-text" data-testid="b360-edit-error">{error}</p>}
      {busy && <p className="muted">Working...</p>}
      {loaded !== null && schema !== null && (
        <section className="b360-group" data-testid="b360-edit-form" data-source={`${loaded.source_system}/${loaded.source_pkey}`}>
          <h3>
            {loaded.source_system}/{loaded.source_pkey} <span className="muted small">(master {loaded.business_id || "-"})</span>
          </h3>
          <table className="monitor kv" aria-label="Edit root fields">
            <tbody>
              {schema.fields.map((f) => (
                <tr key={f.name}>
                  <th>
                    {f.label}
                    {f.required ? " *" : ""} <code className="muted small">{f.name}</code>
                  </th>
                  <td>
                    <FieldInput
                      field={f}
                      value={values[f.name] ?? null}
                      testId={`b360-edit-field-${f.name}`}
                      label={`Edit ${f.label}`}
                      onChange={(v) => {
                        setValues((old) => ({ ...old, [f.name]: v }));
                        edited();
                      }}
                    />
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
          {(schema.groups ?? []).map((g) => (
            <GroupRowsEditor
              key={g.name}
              group={g}
              rows={groups[g.name] ?? []}
              testId={`b360-edit-group-${g.name}`}
              scope="Edit"
              onChange={(next) => {
                setGroups((old) => ({ ...old, [g.name]: next }));
                edited();
              }}
            />
          ))}
          {schema.picklist_note !== undefined && schema.picklist_note !== "" && (
            <p className="muted small">{schema.picklist_note}</p>
          )}
          <div className="toolbar">
            <Button aria-label="Edit show changes" data-testid="b360-edit-preview" onClick={() => run(true)} disabled={busy}>
              Show changes
            </Button>
            <Button
              aria-label="Edit Save"
              data-testid="b360-edit-save"
              data-agent-confirm={`Updates source record ${loaded.source_system}/${loaded.source_pkey} of ${entity} on the live B360 org`}
              onClick={() => run(false)}
              disabled={busy || diff === null || diff.ops.length === 0 || saved !== null}
              title={diff === null ? "Press Show changes first: Save sends exactly the changes shown." : undefined}
            >
              {busy ? "Saving..." : "Save"}
            </Button>
            <Button
              aria-label="Edit reset form"
              data-testid="b360-edit-reset"
              onClick={() => {
                setValues({ ...loaded.values });
                setGroups(groupsOf(loaded));
                edited();
              }}
              disabled={busy}
            >
              Reset
            </Button>
          </div>
          {diff !== null && (
            <section className="b360-group" data-testid="b360-edit-diff">
              <h4>
                Changes (old {"->"} new) <span className="count">{diff.ops.length}</span>
              </h4>
              {diff.ops.length === 0 ? (
                <p className="muted">Nothing changed.</p>
              ) : (
                <div className="table-wrap">
                  <table className="monitor" aria-label="Edit changes old to new">
                    <thead>
                      <tr>
                        <th>Operation</th>
                        <th>Path</th>
                        <th>Old</th>
                        <th>New</th>
                        <th>Path shape</th>
                      </tr>
                    </thead>
                    <tbody>
                      {diff.ops.map((o, i) => (
                        <tr key={`${o.path}-${String(i)}`} data-testid={`b360-edit-op-${String(i)}`}>
                          <td>{o.op}</td>
                          <td>
                            <code>{o.path}</code>
                          </td>
                          <td>{opText(o.old)}</td>
                          <td>{opText(o.new)}</td>
                          <td>{o.verified ? "documented" : "UNVERIFIED"}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              )}
              <p className="muted small" data-testid="b360-edit-note">
                {saved !== null
                  ? `${saved.note}${saved.approval_required === true ? " IDMC says approval is required." : ""}`
                  : diff.note}
              </p>
            </section>
          )}
        </section>
      )}
    </div>
  );
}
