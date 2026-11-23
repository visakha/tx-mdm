// Design notebook (0.9.15): typed reads of /api/design/* (types generated from the backend
// OpenAPI schema) plus a tiny store for the selected asset per type, shared by UI and agent.
// Read-only: nothing here writes.

import { useSyncExternalStore } from "react";
import type { AssetDetail, AssetList, AssetTypeList, DesignAssetType } from "../b360/api-types";
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
