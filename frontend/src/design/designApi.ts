// Design notebook (0.9.15): typed reads of /api/design/* (types generated from the backend
// OpenAPI schema) plus a tiny store for the selected asset per type, shared by UI and agent.
// Read-only: nothing here writes.

import { useSyncExternalStore } from "react";
import type { AssetDetail, AssetList, AssetSummary, AssetTypeList, DesignAssetType, UsedAsset } from "../b360/api-types";
import type { CopyValue, LabelledCopy } from "../shared/rowCopy";
import { DESIGNASSETTYPE_VALUES } from "../b360/api-types";
import { getJson } from "../shared/api";
import { ribbonTab, selectRibbonTab } from "../shell/sections";

export const TYPES_URL = "/api/design/types";

export function listUrl(type: DesignAssetType): string {
  return `/api/design/assets/${type}`;
}

export function detailUrl(type: DesignAssetType, id: string): string {
  return `${listUrl(type)}/${encodeURIComponent(id)}`;
}

function withRefresh(url: string, refresh: boolean): string {
  return refresh ? `${url}?refresh=true` : url;
}

export const designApi = {
  types: (): Promise<AssetTypeList> => getJson<AssetTypeList>(TYPES_URL),
  list: (type: DesignAssetType, refresh = false): Promise<AssetList> =>
    getJson<AssetList>(withRefresh(listUrl(type), refresh)),
  detail: (type: DesignAssetType, id: string, refresh = false): Promise<AssetDetail> =>
    getJson<AssetDetail>(withRefresh(detailUrl(type, id), refresh)),
};

/** The ribbon tab id of the Design section IS the asset type; unknown ids fall back to MTT. */
export function asAssetType(tab: string): DesignAssetType {
  return DESIGNASSETTYPE_VALUES.find((t) => t === tab) ?? "MTT";
}

/** Local date/time like the rest of the app; "-" when IDMC gave none. */
export function whenText(value: string | null | undefined): string {
  if (value === null || value === undefined || value === "") return "-";
  const d = new Date(value);
  return Number.isNaN(d.getTime()) ? value : d.toLocaleString();
}

export function byText(value: string | null | undefined): string {
  return value === null || value === undefined || value === "" ? "-" : value;
}

// ---- selected asset per type (store) ----

type Listener = () => void;
const listeners = new Set<Listener>();
let selected: Partial<Record<DesignAssetType, string>> = {};

export function selectedAsset(type: DesignAssetType): string | null {
  return selected[type] ?? null;
}

export function selectAsset(type: DesignAssetType, id: string | null): void {
  const next = { ...selected };
  if (id === null) delete next[type];
  else next[type] = id;
  selected = next;
  for (const l of listeners) l();
}

/** Open an asset of any type: switches the Design ribbon tab to its type, then selects it. */
export function openDesignAsset(type: DesignAssetType, id: string): void {
  selectAsset(type, id);
  if (ribbonTab("design") !== type) selectRibbonTab("design", type);
}

function subscribe(listener: Listener): () => void {
  listeners.add(listener);
  return () => listeners.delete(listener);
}

export function useSelectedAsset(type: DesignAssetType): string | null {
  return useSyncExternalStore(subscribe, () => selectedAsset(type));
}

// ---- 0.9.17: keyboard rows + Ctrl+C (Vamsi 08:49 CST: "keyboard navigable up and down and when a
// row highlights, when I do control C, all the relevant information should be copied") ----

/** Keys the asset list handles; anything else is left alone. */
export type RowKey = "ArrowUp" | "ArrowDown" | "Home" | "End";
const ROW_KEYS: ReadonlySet<string> = new Set<RowKey>(["ArrowUp", "ArrowDown", "Home", "End"]);

export function isRowKey(key: string): key is RowKey {
  return ROW_KEYS.has(key);
}

/** Next highlighted id. No highlight yet: Down/Home -> first, Up/End -> last. Stops at the ends. */
export function moveHighlight(ids: readonly string[], current: string | null, key: RowKey): string | null {
  if (ids.length === 0) return null;
  const at = current === null ? -1 : ids.indexOf(current);
  const last = ids.length - 1;
  const next = ((): number => {
    switch (key) {
      case "Home":
        return 0;
      case "End":
        return last;
      case "ArrowDown":
        return at < 0 ? 0 : Math.min(at + 1, last);
      case "ArrowUp":
        return at < 0 ? last : Math.max(at - 1, 0);
    }
  })();
  return ids[next] ?? null;
}

function runtimeCopy(re: { id: string; name: string | null } | null | undefined): CopyValue {
  if (re === null || re === undefined) return null;
  return re.name === null ? `${re.id} (name not found)` : `${re.name} (${re.id})`;
}

function usedCopy(rows: readonly UsedAsset[] | undefined): CopyValue {
  return rows === undefined || rows.length === 0 ? null : rows.map((u) => `${u.name} (${u.type})`).join(", ");
}

/**
 * Everything tx-mdm knows about one asset, as labelled lines. The list row always; the detail too
 * when it is loaded for this same asset (created / by, runtime environment, uses ...).
 */
export function designCopy(label: string, asset: AssetSummary, detail: AssetDetail | null): LabelledCopy {
  const d = detail !== null && detail.id === asset.id && detail.type === asset.type ? detail : null;
  const lines: (readonly [string, CopyValue])[] = [
    ["Name", asset.name],
    ["Type", `${label} (${asset.type})`],
    ["Id", asset.id],
    ["Path", asset.path],
    ["Description", byText(d?.description ?? asset.description)],
    ["Updated", whenText(d?.updated_at ?? asset.updated_at)],
    ["Updated by", byText(d?.updated_by ?? asset.updated_by)],
    ["IDMC portal", asset.portal_url ?? "-"],
  ];
  if (d === null) {
    lines.push(["Detail", "not loaded (open the asset to add created / runtime / uses)"]);
    return { lines };
  }
  lines.push(["v2 id", byText(d.v2_id)]);
  lines.push(["Created", whenText(d.created_at)]);
  lines.push(["Created by", byText(d.created_by)]);
  const re = runtimeCopy(d.runtime_environment);
  if (re !== null) lines.push(["Runtime environment", re]);
  if (d.mapping !== null && d.mapping !== undefined) lines.push(["Mapping", d.mapping.name ?? d.mapping.id]);
  if (d.connection_type !== null && d.connection_type !== undefined) lines.push(["Connection type", d.connection_type]);
  if (d.is_shared !== null && d.is_shared !== undefined) lines.push(["Shared", d.is_shared ? "yes" : "no"]);
  const uses = usedCopy(d.uses);
  if (uses !== null) lines.push(["Uses", uses]);
  const usedBy = usedCopy(d.used_by);
  if (usedBy !== null) lines.push(["Used by", usedBy]);
  return { lines };
}
