# Design notebook (0.9.15)

Vamsi, voice 2026-11-23 03:22-03:24 CST: "given a task flow you can interrogate the mapping tasks
that are behind the scene and for each of the mapping task ... get information like when it was
created, when it was updated, who updated it and what runtime it is." / "put it in ... the page
called design ... you just have asset types and when you click on an asset type, it should
refresh ... and then when you click it should give you those metadata."

READ-ONLY. Every route is GET; nothing here writes to IDMC. All calls are rows in
`backend/app/common/idmc_registry.py` (area "CDI design"), so they show in `/docs-idmc` and in
Copy IDMC curl. Doc status of each call: `internal-notes/api-facts.md` (Design section).

## Layout
- Left pane: notebook **Design**, section **Asset types** (`nav-design`, route `/design`). CODE
- Top pane (ribbon) = asset types, in this order: Mapping task (MTT), Taskflow (TASKFLOW),
  Mapping (DTEMPLATE), Synchronization task (DSS), Linear taskflow (WORKFLOW), Connection,
  Runtime environment. Tab id = the type. Backend: `GET /api/design/types`. CODE
- Clicking a type refreshes the list of all assets of that type: name, path, updated time,
  updated by. `GET /api/design/assets/{type}`. CODE
- Clicking an asset shows its metadata: created time / by, updated time / by, runtime environment
  NAME (resolved from its id), id, v2 id, path, description. `GET /api/design/assets/{type}/{id}`. CODE
- A taskflow's detail lists what it uses (v3 references, refType=Uses); each mapping task among
  them carries ITS created / updated / by / runtime environment and opens on click (switches the
  top pane to Mapping task). Taskflows have no runtime environment of their own (said on screen). CODE
- A mapping task's detail adds its mapping (mtTask.mappingId -> v2 mapping) and what it uses
  (mapping, connections), each clickable. A mapping shows "Used by" too. CODE
- Refresh button (explicit; no polling) re-reads IDMC (`?refresh=true`), skipping tx-mdm caches. CODE
- Copy IDMC curl on the list view and on the detail view (each matches its own path exactly). CODE

## Rules
- Created time / by: MTT from v2 mttask, Mapping from v2 mapping (matched by NAME - two
  mappings with one name in different folders cannot be told apart; the page says so),
  Connection / Runtime environment from v2. Taskflow, DSS, WORKFLOW: not available (v3 objects
  give update time / by only; no documented v2 resource) - the page says so. CODE
- Connections: only safe fields are modelled (`ConnectionWire`); user names, passwords and tokens
  IDMC returns are dropped on parse and can never reach the API, UI or logs. Tested with a fake
  connection that carries fake secrets. CODE
- Runtime environment names are cached 300 s; lists of v3 types are cached 300 s. A cached answer
  makes no IDMC call, so Copy IDMC curl keeps the previous call for that view. CODE
- 429 from IDMC = hard stop (429, never retried); other IDMC errors = 502 with IDMC's words;
  unknown id = 404 "No <type> with id <id> in IDMC." CODE
- Agent: `txmdm.listDesignAssets(type)`, `txmdm.getDesignAsset(type, id)`. CODE
- Taskflow history (CDI Taskflows Run tab): child mapping tasks now come from the v3 references
  call (`child_names_source = "references"`); the tf_ -> mt_m_ name guess remains only as the
  fallback when that call fails or lists none (labelled). CODE

## IDMC portal links (0.9.15 Addendum A, Vamsi 03:36 CST)
- Every B360 job instance id (MDM Runs list, Result view, Currently running, Recently finished,
  job instance lookup) is a link to `{mdm_host}/ui-config-app/main/jobDetails/{instance_id}`,
  new tab, aria-label "Open job <id> in IDMC portal". Built ONLY in the backend
  (`app/common/portal.py`, fields `portal_url` on `MdmJobInstanceView` and `RunView`). CODE;
  URL pattern UNVERIFIED-DOC (from his browser, not a documented API).
- Taskflow child rows: no MDM job instance id is known for them today, so no link there.
- CDI taskflow runs (Addendum B, Vamsi 03:44 CST): "Go to IDMC" link directly beneath the run id
  on the Taskflows Summary (and Session log) header, and under each taskflow run id in the run
  history. New tab, aria-label "Open taskflow run <id> in IDMC portal". URL =
  `{cdi_pod_host}/diUI/products/integrationDesign/main/processinstance/{run_id}/{taskflow_name}-{run_id}%7B%7D`
  (last segment percent-encoded; "{}" -> %7B%7D), host from setting `idmc_cdi_portal_url`
  (default https://usw1.dm1-us.informaticacloud.com, his pod). Field `portal_url` on
  TaskflowRunStatus, TaskflowStartResult, HistoryRow (taskflow rows) and the CDI RunView.
  Test: exactly his sample `https://usw1.dm1-us.informaticacloud.com/diUI/products/integrationDesign/main/processinstance/1309453033490374656/tf_Ldg_MDM_CDI_TTF-1309453033490374656%7B%7D`. CODE; pattern UNVERIFIED-DOC.
- CDI plain mapping-task (MTT) runs: NO pattern given - typed slot `MTT_RUN_PATH = None`, no link.
  OPEN GAP.

## Design asset portal links (0.9.16, Vamsi 03:57 CST: "applicable to the design notebook page only")
- Design detail heading: the asset name is a link to its IDMC portal page, with "Go to IDMC"
  beneath it; list rows and the Uses / Used by rows get "Go to IDMC" under the name (the name
  button still opens the detail in tx-mdm). New tab, rel noopener, aria-label
  "Open <type> <name> in IDMC portal". Not added to any other page (vitest guard).
- URL = `{cdi_pod_host}/diUI/products/integrationDesign/main/{segment}/{v3_object_id}/read`;
  segment from the declarative table `DESIGN_ASSET_SEGMENTS` in `app/common/portal.py`:
  DTEMPLATE -> mapping, MTT -> mct, TASKFLOW -> taskflow. Any other type -> null, no link.
  Typed `portal_url` on AssetSummary, AssetDetail and UsedAsset. Tests: exactly his three samples.
  CODE; pattern UNVERIFIED-DOC.

## Only his own assets + keyboard rows + Ctrl+C (0.9.17, Vamsi voice 08:49-08:50 CST)
His words: "I want keyboard navigable up and down and when a row highlights, when I do control C,
all the relevant information should be copied to the clipboard." / "they are both a mix of what I
have written and what came with the product. What I have written usually starts with ... small
m underscore. Only keep those." Then for the other types: "Do the same" - mapping tasks "mt_",
taskflows "tf_" (confirmed 08:50 CST).
- Own-name rule, per asset type, declarative table `OWN_NAME_RULES` in `app/design/models.py`
  (a typed `NameRule` PREFIX, exact case): Mapping (DTEMPLATE) "m_", Mapping task (MTT) "mt_",
  Taskflow (TASKFLOW) "tf_". Connection, Runtime environment, DSS, Linear taskflow: NO rule
  (no naming convention given) - nothing hidden. Applied in the backend after the (cached) IDMC
  list; `?include_all=true` returns every asset (no UI control; for checks and agents). CODE
- AssetList carries `name_filter` (the rule, or null), `shown_count`, `hidden_count`; the page
  says "N product assets hidden (names not starting with m_)". CODE
- Live counts before the rule (his org, read 2026-11-23 08:5x CST through his backend): Mapping
  48 (14 m_ shown, 34 hidden: dsst__*, B2B_Gateway_*, infacore_*, PreviewMapping_*), Mapping task
  11 (0 hidden), Taskflow 4 (0 hidden). LIVE-READ, filter itself not yet run on his laptop.
- Every Design asset list (all types): the table is one keyboard stop. Up / Down move the
  highlighted row, Home / End jump to first / last, Enter opens the highlighted asset (same as a
  click). A click highlights and opens. The highlighted row has aria-selected / data-highlighted
  and a visible outline. CODE
- Ctrl+C (Cmd+C) on the list copies the highlighted asset as labelled lines ("Name: ...", one
  per line, ASCII only): name, type, id, path, description, updated / by, IDMC portal URL; when
  that asset's detail is loaded also v2 id, created / by, runtime environment, mapping,
  connection type, shared, Uses / Used by names. A real text selection wins (normal copy); keys
  typed in an input never reach the list. One line beneath the table says it was copied. CODE
- Agent: `txmdm.designAssetCopyText(type, id)` returns the same text. CODE

## NOT LIVE
Nothing on this page has run against his org yet: all shapes come from the IICS REST API
Reference (Nov 2025) and the fake IDMC.
