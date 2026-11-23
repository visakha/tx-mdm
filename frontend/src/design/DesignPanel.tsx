// Design notebook (0.9.15, Vamsi 03:22-03:24 CST): "you just have asset types and when you
// click on an asset type, it should refresh ... it should show all the things and then when you
// click it should give you those metadata."
//   top pane (ribbon)  = asset types (Mapping task, Taskflow, Mapping, ...)
//   left of the page   = all assets of the selected type (name, path, updated time / by)
//   right of the page  = the selected asset's metadata; a taskflow lists the mapping tasks it
//                        uses with THEIR created / updated / by / runtime environment, clickable.
// Read-only (GET only). Explicit Refresh button, no polling. No pop-ups, no colour coding.

import { useCallback, useEffect, useState } from "react";
import { Button } from "@ui-sdk/react/button";
import type { AssetDetail, AssetList, DesignAssetType, UsedAsset } from "../b360/api-types";
import { errorText } from "../shared/api";
import { CopyIdmcCurl } from "../shared/CopyIdmcCurl";
import { DesignAssetLink } from "../shared/PortalLink";
import { useRibbonTab } from "../shell/sections";
import {
  asAssetType,
  byText,
  designApi,
  detailUrl,
  listUrl,
  openDesignAsset,
  selectAsset,
  useSelectedAsset,
  whenText,
} from "./designApi";

function runtimeText(d: { runtime_environment?: { id: string; name: string | null } | null }): string {
  const re = d.runtime_environment;
  if (re === null || re === undefined) return "-";
  return re.name === null ? `${re.id} (name not found)` : re.name;
}

function UsedTable({ title, rows, slug }: { title: string; rows: readonly UsedAsset[]; slug: string }): React.JSX.Element {
  return (
    <section className="design-uses" data-testid={`design-${slug}`} aria-label={title}>
      <h4>
        {title} <span className="count">{rows.length}</span>
      </h4>
      {rows.length === 0 ? (
        <p className="muted">None listed by IDMC.</p>
      ) : (
        <div className="table-wrap">
          <table className="monitor" aria-label={`${title} table`}>
            <thead>
              <tr>
                <th>Name</th>
                <th>Type</th>
                <th>Created</th>
                <th>Created by</th>
                <th>Updated</th>
                <th>Updated by</th>
                <th>Runtime environment</th>
              </tr>
            </thead>
            <tbody>
              {rows.map((u) => (
                <tr key={`${u.type}-${u.id}`} data-testid={`design-${slug}-${u.id}`}>
                  <td title={u.path}>
                    {u.open_type !== null && u.open_type !== undefined && u.open_id !== null && u.open_id !== undefined ? (
                      <Button
                        className="row-open"
                        aria-label={`Open ${u.type} ${u.name}`}
                        data-testid={`design-open-${slug}-${u.id}`}
                        onClick={() => openDesignAsset(u.open_type as DesignAssetType, u.open_id as string)}
                      >
                        {u.name}
                      </Button>
                    ) : (
                      u.name
                    )}
                    <div className="small">
                      <DesignAssetLink name={u.name} typeLabel={u.type} url={u.portal_url} slug={`${slug}-${u.id}`} goTo />
                    </div>
                    {u.detail_note !== undefined && u.detail_note !== "" && <p className="muted small">{u.detail_note}</p>}
                  </td>
                  <td>{u.type}</td>
                  <td>{whenText(u.created_at)}</td>
                  <td>{byText(u.created_by)}</td>
                  <td>{whenText(u.updated_at)}</td>
                  <td>{byText(u.updated_by)}</td>
                  <td>{runtimeText(u)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </section>
  );
}

function Detail({ detail }: { detail: AssetDetail }): React.JSX.Element {
  const rows: [string, string][] = [
    ["Name", detail.name],
    ["Path", detail.path],
    ["Type", `${detail.label} (${detail.type})`],
    ["Id", detail.id],
    ["v2 id", byText(detail.v2_id)],
    ["Description", byText(detail.description)],
    ["Created", whenText(detail.created_at)],
    ["Created by", byText(detail.created_by)],
    ["Updated", whenText(detail.updated_at)],
    ["Updated by", byText(detail.updated_by)],
    ["Runtime environment", runtimeText(detail)],
  ];
  if (detail.mapping !== null && detail.mapping !== undefined) {
    rows.push(["Mapping", byText(detail.mapping.name ?? detail.mapping.id)]);
  }
  if (detail.connection_type !== null && detail.connection_type !== undefined) {
    rows.push(["Connection type", detail.connection_type]);
  }
  if (detail.is_shared !== null && detail.is_shared !== undefined) {
    rows.push(["Shared", detail.is_shared ? "yes" : "no"]);
  }
  return (
    <div className="design-detail" data-testid="design-detail" data-asset={detail.id}>
      <h3>
        Detail: <DesignAssetLink name={detail.name} typeLabel={detail.label} url={detail.portal_url} slug={`detail-${detail.id}`} />
      </h3>
      <div className="small">
        <DesignAssetLink name={detail.name} typeLabel={detail.label} url={detail.portal_url} slug={`detail-${detail.id}`} goTo />
      </div>
      <table className="monitor kv" aria-label={`Metadata of ${detail.name}`}>
        <tbody>
          {rows.map(([k, v]) => (
            <tr key={k}>
              <th>{k}</th>
              <td data-testid={`design-field-${k}`}>{v}</td>
            </tr>
          ))}
        </tbody>
      </table>
      {detail.runtime_note !== undefined && detail.runtime_note !== "" && (
        <p className="muted small" data-testid="design-runtime-note">{detail.runtime_note}</p>
      )}
      {(detail.uses?.length ?? 0) > 0 || detail.type !== "RUNTIME_ENVIRONMENT" ? (
        <UsedTable title={detail.type === "TASKFLOW" ? "Uses (mapping tasks and more)" : "Uses"} rows={detail.uses ?? []} slug="uses" />
      ) : null}
      {(detail.used_by?.length ?? 0) > 0 && <UsedTable title="Used by" rows={detail.used_by ?? []} slug="used-by" />}
      {(detail.notes ?? []).map((n) => (
        <p key={n} className="muted small">
          {n}
        </p>
      ))}
    </div>
  );
}

export function DesignPanel({ active }: { active: boolean }): React.JSX.Element {
  const type = asAssetType(useRibbonTab("design"));
  const selectedId = useSelectedAsset(type);
  const [list, setList] = useState<AssetList | null>(null);
  const [detail, setDetail] = useState<AssetDetail | null>(null);
  const [listError, setListError] = useState<string>("");
  const [detailError, setDetailError] = useState<string>("");
  const [loading, setLoading] = useState<boolean>(false);

  const loadList = useCallback((refresh: boolean): void => {
    setLoading(true);
    setListError("");
    designApi
      .list(type, refresh)
      .then((l) => setList(l))
      .catch((err: unknown) => {
        setList(null);
        setListError(`Could not list ${type}: ${errorText(err)}`);
      })
      .finally(() => setLoading(false));
  }, [type]);

  const loadDetail = useCallback((id: string, refresh: boolean): void => {
    setDetailError("");
    designApi
      .detail(type, id, refresh)
      .then((d) => setDetail(d))
      .catch((err: unknown) => {
        setDetail(null);
        setDetailError(`Could not read ${type} ${id}: ${errorText(err)}`);
      });
  }, [type]);

  // Clicking an asset type (ribbon tab) refreshes the list of that type.
  useEffect(() => {
    if (!active) return;
    setList(null);
    loadList(false);
  }, [active, loadList]);

  useEffect(() => {
    if (!active) return;
    setDetail(null);
    if (selectedId !== null) loadDetail(selectedId, false);
  }, [active, selectedId, loadDetail]);

  const refresh = (): void => {
    loadList(true);
    if (selectedId !== null) loadDetail(selectedId, true);
  };

  const label = list?.label ?? type;
  return (
    <div className="design-panel" data-testid="design-panel" data-type={type}>
      <div className="design-toolbar">
        <Button aria-label={`Refresh ${label} list and detail`} data-testid="design-refresh" onClick={refresh} disabled={loading}>
          Refresh
        </Button>
        {list !== null && (
          <span className="muted small" data-testid="design-as-of">
            {" "}
            {list.assets.length} {label} assets, as of {whenText(list.as_of)}
            {list.from_cache ? " (from tx-mdm cache; Refresh re-reads IDMC)" : ""}
          </span>
        )}
      </div>
      <div className="design-columns">
        <section className="design-list" aria-label={`${label} assets`} data-testid="design-list">
          <h3>{label} assets</h3>
          <CopyIdmcCurl prefix={listUrl(type)} exact view={`${label} list`} slug="design-list" />
          {loading && list === null && <p className="muted">Loading...</p>}
          {listError !== "" && <p className="warn-text" data-testid="design-list-error">{listError}</p>}
          {list !== null && list.assets.length === 0 && <p className="muted">No assets of this type.</p>}
          {list !== null && list.assets.length > 0 && (
            <div className="table-wrap">
              <table className="monitor" aria-label={`${label} assets table`}>
                <thead>
                  <tr>
                    <th>Name</th>
                    <th>Path</th>
                    <th>Updated</th>
                    <th>Updated by</th>
                  </tr>
                </thead>
                <tbody>
                  {list.assets.map((a) => (
                    <tr
                      key={a.id}
                      className={`clickable${a.id === selectedId ? " selected" : ""}`}
                      aria-selected={a.id === selectedId}
                      data-testid={`design-asset-${a.id}`}
                      onClick={() => selectAsset(type, a.id)}
                    >
                      <td>
                        <Button
                          className="row-open"
                          aria-label={`Open ${label} ${a.name}`}
                          data-testid={`design-open-${a.id}`}
                          onClick={() => selectAsset(type, a.id)}
                        >
                          {a.name}
                        </Button>
                        <div className="small">
                          <DesignAssetLink name={a.name} typeLabel={label} url={a.portal_url} slug={`row-${a.id}`} goTo />
                        </div>
                      </td>
                      <td>{a.path}</td>
                      <td>{whenText(a.updated_at)}</td>
                      <td>{byText(a.updated_by)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
          {(list?.notes ?? []).map((n) => (
            <p key={n} className="muted small">
              {n}
            </p>
          ))}
        </section>
        <section className="design-detail-pane" aria-label={`${label} detail`} data-testid="design-detail-pane">
          {selectedId === null ? (
            <p className="muted">Click an asset to see when it was created and updated, by whom, and its runtime environment.</p>
          ) : (
            <>
              <CopyIdmcCurl prefix={detailUrl(type, selectedId)} exact view={`${label} detail`} slug="design-detail" />
              {detailError !== "" && <p className="warn-text" data-testid="design-detail-error">{detailError}</p>}
              {detail === null && detailError === "" && <p className="muted">Loading...</p>}
              {detail !== null && <Detail detail={detail} />}
            </>
          )}
        </section>
      </div>
    </div>
  );
}
