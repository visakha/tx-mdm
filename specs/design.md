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
- CDI runs / taskflows: typed slot `CDI_RUN_PATH = None`; `portal_url` stays null until he gives
  a sample URL. Not invented.

## NOT LIVE
Nothing on this page has run against his org yet: all shapes come from the IICS REST API
Reference (Nov 2025) and the fake IDMC.
