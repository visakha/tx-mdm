# UI observations (agent notes - read first in any session touching the tx-mdm UI)

Standing rule (Vamsi, 2026-11-22 23:04 CST): keep these notes current whenever the app changes:
what each screen / element does, what to click for each workflow, intended vs actual behaviour.
Last updated: 2026-11-23 ~00:28 CST, v0.9.1 (see the v0.9.1 section, which overrides older Taskflows notes).
Older notes: 2026-11-22 ~23:55 CST, v0.8.0 redesign commit. Observed with Cypress (Electron) against the
fake IDMC (backend/dev/fake_idmc.py). Not yet observed against the live org - see the end.

## v0.9.1 CDI Taskflows (2026-11-23, Vamsi voice 00:15-00:19 CST) - overrides older Taskflows notes

NOT OBSERVED: at his request ("skip the test", 00:24 CST) 0.9.1 was pushed with only typecheck,
production build and the ASCII grep run. Nothing below has been seen in a browser yet.

Ribbon tabs are now Run / Summary / Session log. Each shows ONLY its own part.
The Track run id tab and its paste box were REMOVED at his request on 2026-11-23 ("Remove the
track run ID. I don't think we need it.").

- Run (stacked, both parts 100% width - he does not want it split side by side):
  - MASTER `tf-run-box`: taskflow list `tf-list` / `tf-item-<name>` (one line per name, roomy for
    20-30 names). Picking one shows its input fields (`tf-param-key-N` / `tf-param-value-N`,
    `tf-param-add`) and the Run button `tf-run` (data-agent-confirm). Before a pick: a short
    "Pick a taskflow" line. Start errors: `tf-start-error`.
  - DETAIL `tf-history` below it: every run of the picked taskflow, running first, then newest.
    Row columns: run id (full, one line), status, start, end, elapsed min, rows ok / failed,
    error, Open. Taskflow rows `tf-history-row-<runId>` (data-trackable="true",
    data-running) have two links: `tf-history-summary-<runId>` -> Summary tab,
    `tf-history-log-<runId>` -> Session log tab, both for that run id.
    Child task rows `tf-history-child-<i>` (data-trackable="false") have no links.
    `tf-history-refresh` = "Last refresh ... (every 15 s, N checks)"; `tf-history-note` = plain notes;
    `tf-history-error` on errors. Polls every 15 s (shared POLL_MS) only while Run is the open
    tab and a taskflow is picked; a 429 stops auto-refresh. Read-only, never retried.
  - After Run is accepted: stays on Run (no tab switch, no navigation); the new run is put on
    top of the history at once, marked running. The Run button stays usable for parallel starts.
- Summary (`tf-run-view`): what Track used to own for the selected run - `tf-run-id`, `tf-status`,
  progress bar `run-progress`, poll clock, `tf-times`, `tf-last-refresh`, Abort `tf-abort`
  (only while running, data-agent-confirm), `tf-error` / `tf-note`, then per child rows
  `tf-subtasks` / `tf-child-<name>` / `tf-totals` with "Open log" buttons `tf-sum-log-<name>`.
- Session log (`tf-log-pane`): child picker buttons `tf-log-<name>`, viewer `tf-log-viewer`.
- No run selected: Summary and Session log show `tf-no-run` pointing to the Run tab history.
- URL /taskflows/runs/:id (deep link) opens Summary for that id.
- Backend: POST /api/cdi/taskflows/{name}/run no longer answers 409 for a second start of the
  same taskflow - parallel starts go to IDMC, which decides. Whether IDMC accepts concurrent
  instances of one taskflow is UNVERIFIED. Other CDI/MDM starts keep the one-at-a-time 409.
- New read-only GET /api/cdi/taskflows/{name}/history?row_limit=1..1000 (default 100).
- Data shape (live read-only check 2026-11-23 ~00:20 CST): activityMonitor / activityLog list
  the taskflow's CHILD mapping tasks (MTT, e.g. mt_m_MDM_ZLV_TTF_Guest_Basic_EGR), never the
  taskflow itself. So history = taskflow runs started from this app (trackable, kept in backend
  memory - lost on a backend restart) + child task rows (mapping task run numbers, not taskflow
  run ids, not trackable). Child name comes from a tracked run's subtasks; otherwise it is a
  guess tf_X -> mt_m_X, and the pane says so.
- Agent bridge: trackTaskflowRun REMOVED. New openTaskflowSummary(runId),
  openTaskflowLog(runId), getTaskflowHistory(name, rowLimit). runTaskflowByName no longer
  navigates. selectRibbonTab accepts run / summary / log.

## Layout (OneNote style)

```
+---------------------------------------------------------------+
| title bar (purple): TX MDM Job Runner   <notebook> - <section>  |   data-testid=crumb
+--------------+------------------------------------------------+
| search box   | ribbon: contextual tabs of the section           |   ribbon-tabs, ribbon-tab-<id>
| CDI notebook | one-line hint for the selected tab               |   ribbon-hint
|  Tasks       +------------------------------------------------+
|  Taskflows   | page: the section content                        |
|  Monitor     |                                                  |
|  Runs        |                                                  |
| MDM notebook |                                                  |
|  All jobs    |                                                  |
|  Ingress     |                                                  |
|  Egress      |                                                  |
|  Runs        |                                                  |
+--------------+------------------------------------------------+
```

- Left pane items: test ids `tab-cdi` (Tasks), `tab-taskflows`, `tab-monitor`, `nav-cdi-runs`,
  `tab-mdm` (All jobs), `nav-mdm-ingress`, `nav-mdm-egress`, `nav-mdm-runs`. The old top-tab ids
  were kept on the matching left items so older scripts still work.
- Search box (`nav-search`) filters the left-pane sections by name or notebook ("egress",
  "cdi"). It does not search jobs; each job list has its own filter box.
- The section comes from the URL; the ribbon tab is in-memory per section (resets on reload).
- Ribbon tabs only show/hide parts of a page (CSS on `data-section` / `data-view` of the root
  `.onenote` element) - panels stay mounted, so lists and polling are not lost.

- Title bar right: backend version label `about-version` (e.g. "v0.7.0", from GET /api/about;
  empty if the backend is down). Agent: `txmdm.about()` -> version + three highlights.

## Sections, ribbon tabs, URLs

| Section | URL | Ribbon tabs (first = default) | Notes |
|---|---|---|---|
| CDI Tasks | /cdi/jobs, /cdi/jobs/:taskId | Tasks, Run | Run tab hides the list, detail full width |
| CDI Taskflows | /taskflows, /taskflows/runs/:runId | Run, Track run id, Summary, Session log | see workflow below |
| CDI Monitor | /monitor | Everything, Running now, History, Started here | auto-refresh 15 s, Pause / Refresh / scope buttons |
| CDI Runs | /cdi/runs, /cdi/runs/:runKey | Runs, Result | runs started from THIS backend since it started |
| MDM All jobs | /mdm/jobs, /mdm/jobs/:assetId | Jobs, Run | |
| MDM Ingress / Egress | /mdm/ingress, /mdm/egress | Jobs, Run | same list filtered by kind |
| MDM Runs | /mdm/runs, /mdm/runs/:runKey | Runs, Result | |

`/` redirects to `/mdm/jobs`. Opening a run result (`/cdi/runs/:runKey`) selects Runs > Result.

## Workflows - what to click

- **Run a taskflow by name with jobInstanceId:** Taskflows > Run tab > pick the taskflow in the
  list (`tf-item-<name>`) > check input fields (`tf-param-key-0` = jobInstanceId,
  `tf-param-value-0` = ABC123 prefilled; "Add field" adds rows) > Run (`tf-run`) > confirm
  dialog shows the fields. URL becomes /taskflows/runs/<runId>; the right side tracks it.
- **Track an existing run id:** Taskflows > Track run id tab > paste into `tf-runid-input` >
  Track (`tf-track`, disabled until the text is all digits).
- **Read the summary:** Summary tab: status badge (`tf-status`, e.g. "STOPPED (SUSPENDED)"),
  started / running-for (ticks every second while running) / ended, error line, child table
  (`tf-child-<name>`), totals row once final.
- **Abort a running taskflow:** while the tracked run is RUNNING an "Abort run" button
  (`tf-abort`) shows under the run id > confirm ("Terminate (abort) taskflow run <id>?") > note
  `tf-abort-note` "IDMC accepted the terminate (204)..." > next poll (<= 10 s) shows it final;
  the button disappears. Agent: `txmdm.terminateTaskflow(runId)` (asks a person first).
  Observed with the fake (run 900000000000000003 -> FAILED). Not yet observed live.
- **Session log:** Session log tab > "Session log" button on a child row (`tf-log-<name>`,
  disabled when no activity-log row matched) > text in `tf-log-viewer`.
- **Run a CDI task / MDM job:** Tasks (or All jobs / Ingress / Egress) > pick > Run. The app
  jumps to Runs > Result for that run.
- **See what is running in IDMC:** Monitor > Running now.

## Agent bridge (window.txmdm)

`layout()`, `openNavSection(sectionId)`, `selectRibbonTab(tabId)` (throws on unknown tab),
plus the job / monitor / taskflow actions (`runTaskflowByName`, `trackTaskflowRun`,
`getTaskflowRun`, `getTaskflowSessionLog`, ...). Side effects ask window.confirm first.
`window.agent` is the UI SDK bridge (asks a person before any press).

## Intended vs actual (known gaps)

- Ribbon tab choice is not in the URL: a reload returns to the section's first tab. Intended.
- Taskflow Run tab with a run tracked: list on the left, run on the right (both visible).
- Monitor table is wide; at 1280 px it scrolls horizontally (error column wraps at 280 px).
- Fake IDMC: tf_demo_advanced always answers the same run id, so a second Run in one fake
  session goes straight to SUCCESS (no RUNNING phase). Restart the fake for a clean demo.
- OBSERVED LIVE 2026-11-22 ~23:15 CST (read-only, Cypress via dev/forward_readonly.py, his
  backend on the 5e973a5 code): CDI task list (15), Taskflows list (4: tf_Ldg_MDM_CDI_TTF,
  tf_Stg_MDM_CDI_TTF, tf_MDM_ZLV_TTF_Guest_Basic, tf_MDM_ZLV_TTF_Guest_Basic_EGR), Monitor, and
  run 1309380263289049088: STOPPED (SUSPENDED), child mt_m_MDM_ZLV_TTF_Guest_Basic FAILED
  "[FATAL] Invalid/Default JobInstanceId ...", Session log button enabled, real log shown.
- Fixed after that live look (needs his next pull + restart): the run-level error showed as a
  raw JSON string and "ended -" with 25.2 min (SUSPENDED has no endTime); long names/paths
  overflowed the taskflow list. Now: reason only, ended = updateTime, names wrap.
- Not observed yet: a running taskflow ticking live, and a SUCCESS run with row counts.

## v0.8.0 changes (observed with Cypress vs the fake IDMC, 2026-11-22)

- Left-pane search (`nav-search`) now matches tasks, taskflows and MDM jobs BY NAME as you type,
  listed under "Matches" (`search-results`, `search-count`, `search-hit-<name>`, `data-kind`),
  max 25. Click: a taskflow opens /taskflows with it picked on the Run tab; a task or job opens
  its detail. Section filtering still applies. Agents: `agent.act` setValue on "Search results".
- Icons: inline SVG (shell/icons.tsx) on left-pane items and search hits. ASCII-only source.
- Taskflows (Vamsi 23:34-23:35 CST): "Run taskflow by name" (`tf-run-box`) spans 100% of the
  section; "Track a run id" (`tf-track-box`) is stacked BELOW it at 100%, run-id input full width
  with Track at the right. Long names (e.g. tf_MDM_ZLV_TTF_Guest_Basic_EGR + folder path) show on
  one line. Both boxes are visible on every Taskflows tab now (Track tab = same page, hint
  points below). Run view sits under both. Spec: cypress/e2e/taskflows_layout.cy.js.
- Results pane progress + poll clock (Vamsi 23:40 CST; primary target the Business 360 results
  pane, same shared component `shared/RunProgress.tsx` on CDI results and the taskflow run view):
  - `run-progress` (UI SDK Progress): indeterminate sweep while not final (IDMC gives no percent,
    so none is invented); counts shown as text (`run-progress-text`). Final: full, coloured by
    outcome, `data-tone` ok / warn / bad, `data-complete`.
  - `poll-clock`: small SVG clock; background colour cycles on every status poll (`data-polls`),
    grey and still when `data-final="true"`.
  - Poll interval: MDM and CDI results now every 15 s (was 5 s); taskflow run view stays 10 s.
  - Spec: cypress/e2e/mdm_progress.cy.js (RUNNING then SUCCESS).
- Aborted: a taskflow ending with code processManuallyTerminated shows "ABORTED (IDMC: FAILED)"
  in grey (`tf-status` data-aborted="true"); progress bar warn tone.
- UI SDK confirm marks: Run (`cdi-run`, `mdm-run`, `tf-run`) and Abort (`tf-abort`) carry
  data-agent-confirm; the bridge asks a person only for those. See ui-sdk-philosophy.md.
- Not yet observed live for 0.8.0: everything above was seen against the fake only.


## 2026-11-23 hotfix: run results pane (Vamsi, live call)
- Indeterminate progress sweep slowed 3x (1.4s -> 4.2s per pass).
- Poll clock enlarged (22px -> 30px circle, 14px -> 20px icon).
- Status text ("Running - no row counts reported yet") now sits on its own line UNDER the progress bar, not beside it.
- New "Last refresh" row in the times list, directly before "Ended" (data-testid run-last-refresh): local date/time of the last answered status check, same format as Requested / Started in IDMC; updates in place every 15 s while running, "-" before the first answer.

## v0.9.0: Business 360 Currently running (Vamsi 2026-11-22 23:55 CST) + one 15 s poll (23:56 CST)
Observed with Cypress vs the fake IDMC (spec `cypress/e2e/mdm_running.cy.js`).
- Left pane, Business 360 notebook: new section **Currently running** (data-nav `mdm-running`,
  data-testid `nav-mdm-running`), URL `/mdm/running`. Ribbon tabs: Everything / Running now /
  Recently finished / Look up id.
- What it shows: EVERY running B360 job in the org whose jobType starts with `b360.` or `c360.`,
  whoever started it - this app, the portal, another machine, another user. Not only runs this
  backend started (those stay under Runs). Columns: Instance id (FULL, one line, never wrapped),
  Job, Type, Status, Started, Elapsed (ticks every second while running), Started by, Rows in.
  Non-B360 types (e.g. `internal.c360.ingress.fileImportJob`) are counted under the recent table,
  not listed.
- Test ids: `b360-monitor`, `b360-running` (table), `b360-row-<instanceId>`, `b360-recent`,
  `b360-running-count`, `b360-refresh`, `b360-last-refresh`, `b360-error`, `b360-lookup-input`,
  `b360-lookup`, `b360-lookup-result`, `b360-lookup-error`; shared `run-progress` + `poll-clock`.
- Refresh: every 15 s (poll clock changes colour each answer) + Refresh now; "Last refresh:
  <time> (every 15 s)" under the bar. A 429 stops auto-refresh for good.
- Look up id: paste any full instance id (quotes / spaces / a trailing dot are trimmed), press
  Look up -> one row with status, started by, counts; errors listed under it.
- Agent bridge: `txmdm.openMdmMonitor()`, `txmdm.getMdmMonitor(rowLimit = 25)`,
  `txmdm.lookupMdmJob(instanceId)` (read-only, no confirm).
- 15 s everywhere: ONE constant `POLL_SECONDS` / `POLL_MS` in `frontend/src/shared/poll.ts`, used
  by MDM + CDI run results (useRunPolling), the taskflow run view (was 10 s, now 15 s), CDI
  Monitor and Currently running. The taskflow run view also shows "Last refresh: <time>"
  (data-testid `tf-last-refresh`). The run results "Last refresh" row is the 2026-11-23 hotfix one.
- Not yet seen live: his backend needs `git pull` + restart for `/api/mdm/monitor` to exist. Real
  case to check after pickup: 1309395637279657984 (b360.ingress.load, portal, 23:50:47 CST).

## v0.9.2 (2026-11-23) - grouped run history on the Taskflows Run tab

His request (00:36 CST): "taskflow on top, child indented, in the next row". Correction (00:37 CST):
"don't worry about the color. I don't want the color." So indentation only - no tint, no colour coding.

- The Run history table under the Run form is grouped: each taskflow run row (bold, `tr.tf-parent-row`,
  `data-level="taskflow"`) is followed directly by its child mapping-task rows (`tr.tf-child-row`,
  `data-indented="true"`), whose run id cell is indented about 32px with a thin neutral connector line
  in the border colour.
- Each row carries a small outlined label: "taskflow" or "mapping task" (`.tf-kind`).
- Matching (frontend `groupHistory` in `cdi/taskflowApi.ts`): child run ids are small mapping-task
  numbers (live example: taskflow run ...2288, child run id 10), never taskflow ids, so children are
  matched by TIME only - the child's start must fall inside the parent's start..end window (end = now
  while running, 60 s slack). The backend already restricts children to this taskflow's own child
  task names. Latest-starting matching parent wins.
- A child with no matching parent run stays as its own row (`tr.tf-loose-row`, not indented) with the
  text "not matched to a taskflow run".
- Groups: running first, then newest start first. Children inside a group: oldest start first.
- Unchanged: full width, full ids on one line, Summary / Session log links on taskflow rows only,
  15 s refresh with Last refresh, auto-refresh stops on 429, read-only.
- NOT yet checked in a browser or Cypress (he asked for speed). Seen live only by him on his screen.

## v0.9.3 (2026-11-23) - visible run links and Clear buttons

Why (his words, 00:38 CST): "I do not see how I can navigate to the summary from the run tab.
I don't see any of those hyperlinks."

Root cause, checked against his live 0.9.1 backend (read-only GET of
/api/cdi/taskflows/tf_MDM_ZLV_TTF_Guest_Basic_EGR/history): the data was right. His taskflow
run 1309406930795532288 came back as a trackable taskflow row, so its links rendered. But
they sat in the LAST column ("Open"), after the long nowrap name, the times and the error
text, inside a horizontally scrolling table, so they were off screen to the right. The row he
was looking at, child mapping task run 10 (RUNNING, sorted first in 0.9.1), had no links at
all, only a muted "see its taskflow run" text.

What changed:
- The Open column is now the SECOND column, right after Run id. The links are plain
  underlined text, "Summary | Session log", and never hidden behind hover.
- Taskflow rows link to themselves: data-testid tf-history-summary-<runId> and
  tf-history-log-<runId>.
- Child mapping-task rows matched to a parent link to the PARENT run. Summary opens the
  parent's Summary. Session log opens the parent's Session log with that child pre-selected,
  once the status shows the child with a log id. Test ids: tf-history-summary-child-<i> and
  tf-history-log-child-<i>.
- Unmatched children get no links. They show "no link: not matched to a taskflow run started
  from this app" (tf-history-nolink-<i>). Monitor-only children usually end up here after a
  backend restart, because app-started runs are held only in backend memory.
- Clear buttons are VIEW-ONLY. Nothing in IDMC or the backend is deleted or stopped.
  - Run history Clear (tf-history-clear) hides every row present now except still-running
    ones. Rows that start later still show. "Cleared at <time>. Show all"
    (tf-history-cleared / tf-history-show-all) undoes it. Changing the picked taskflow resets
    the Clear.
  - Summary Clear (tf-summary-clear) and Session log Clear (tf-log-clear) drop the selected
    run, so the route goes back to /taskflows and the pane shows its "No run selected yet"
    state.

Not tested in a browser. Cypress specs that may now be stale: taskflows_fake.cy.js,
taskflows_layout.cy.js and onenote.cy.js. The Open column moved and the Track wording was
removed.

## v0.9.4 (2026-11-23): MDM taskflows moved to the Business 360 notebook

His words (voice, 00:41-00:43 CST): the job instance id applies only to Business 360 / MDM
taskflows (tf_MDM_*, *_EGR, *_IGR). "In the CDI when I click on the task flows I see the task
flows associated with MDM also. They should not be there in the first place." CDI taskflows
are separate from the B360 ingress / egress jobs.

- Left pane, Business 360 (MDM) notebook: a new section "Taskflows (jobInstanceId)"
  (section id mdm-taskflows, route /mdm/taskflows, run deep link /mdm/taskflows/runs/:id) sits
  right after Ingress jobs / Egress jobs. It has the same Run / Summary / Session log tabs,
  history, Clear buttons and Abort as the CDI one (the same TaskflowsPanel with domain="mdm",
  panel test id mdm-taskflows-panel, data-domain=mdm).
- MDM Run tab: the input field row jobInstanceId is there and EMPTY (no ABC123 any more). Run
  stays disabled until it has a value, with the hint "Business 360 taskflow: type the
  jobInstanceId value to enable Run." (tf-jobid-hint).
- CDI notebook, Taskflows section (/taskflows, data-domain=cdi): only CDI taskflows (tf_Ldg_*,
  tf_Stg_*, ...). There are no input field rows by default, with the hint "CDI taskflow: no
  input fields needed" (tf-no-fields-hint). "Add field" still works for other fields.
- CDI Tasks picker (cdi-tasks): MDM taskflows are filtered out. No MDM taskflow appears
  anywhere in the CDI notebook.
- Left-pane search: an MDM taskflow shows as "MDM taskflow" and opens the Business 360
  Taskflows section with it picked. A CDI taskflow shows as "CDI taskflow".
- Agent bridge: runTaskflowByName defaults to no parameters (pass { jobInstanceId: "<id>" } for
  MDM ones). openTaskflowSummary / openTaskflowLog take (runId, domain = "cdi").
  openNavSection knows mdm-taskflows.
- Backend guard: a wrong field set gets a 400 with a plain message, and IDMC is never called.

Not tested in a browser. Cypress specs likely stale: taskflows_fake.cy.js,
taskflows_layout.cy.js and onenote.cy.js (they expect the MDM taskflow in the CDI list and an
ABC123 pre-fill). search_items.cy.js may be stale too.

## v0.9.5 (2026-11-23) - B360 Data notebook

Why (his words, 00:44-00:49 CST): "put one more notebook... called B360 data... it should show
the business entity, a list of business entity... when I click on a certain business entity it
should show the data, the first ten rows". Then: field groups STACKED, not tabbed; the entity
list DERIVED from the metadata APIs, not hardcoded; strongly typed end to end.

Where: left pane, third notebook "B360 Data" (data-testid notebook-B360), one section
"Business entities" (nav-b360-data, URL /b360 and /b360/<entity id>). Ribbon: one tab
"Entities" (ribbon-tab-entities).

What is on the page, top to bottom, all full width, no tabs:
- Refresh button (b360-refresh): reloads the entity list and the open entity's records. No
  polling. "From GET /metadata/api/v2/objects/tenantModel/datamodel" says where the list came from.
- Entity list (b360-entities), one per line: label + internal id, button
  b360-entity-<id> (e.g. b360-entity-c360.person). The open one is bold (aria-pressed).
- Records (b360-records, data-entity=<id>): "<label>: first 10 of <hits> records" and a table
  (b360-records-table); first column Business id, then one column per top-level field from the
  entity's metadata. Rows b360-record-<businessId>, click to open.
- Keys the metadata did not describe are listed in one muted line (b360-unknown-keys), never
  shown as columns.
- Record detail (b360-detail, data-record=<businessId>) under the table: "Fields" block
  (b360-group-fields, label/value table), then one block per field group in metadata order
  (b360-group-<GroupName>, heading + row count + small table, or "No <group> rows.").
- Errors in b360-error; a 429 says "IDMC rate limit (429): stopped, nothing retried."

Agent bridge (window.txmdm): listB360Entities() (also opens the notebook),
getB360Metadata(name), getB360Records(name) (opens the entity and returns its RecordPage),
openB360Record(businessId) (needs the entity open). Note: getB360Records fetches once for the
agent and the panel fetches once for the screen (two read-only searches).

Observed: only against the fake IDMC (unit tests + typecheck + build). Not yet run in a real
browser or Cypress; not yet seen against his org (the metadata shapes are UNVERIFIED, see
api-facts.md "B360 Data notebook").

## v0.9.6 (2026-11-23): MDM child mapping tasks moved to Business 360

Intended:
- CDI notebook > Tasks picker no longer lists mt_m_MDM_* / *_EGR / *_IGR mapping tasks (filter on
  `domain !== "mdm"`, unchanged code, the backend now tags them mdm).
- Business 360 notebook > Taskflows (jobInstanceId) > Run tab: under the run box, a read-only
  "Child mapping tasks" table (`mdm-child-tasks`, rows `mdm-child-task-<name>`): mapping task,
  "Runs via its taskflow" (link `mdm-child-task-parent-<name>` picks that taskflow in the list
  above; name guess tf_X -> mt_m_X; no match -> muted "runs via its taskflow"), folder.
  No Run button for them.
- Left-pane search: hit kind `mdm-mapping-task`, label "MDM mapping task (runs via its taskflow)",
  opens Business 360 Taskflows.
- CDI Monitor and taskflow history unchanged.
Observed: unit tests + typecheck + build only. Not run in a browser or Cypress.

## v0.9.7 (2026-11-23): B360 Data - TOML entities in the left pane, master-detail page

Intended (his words 01:00-01:04 CST): "ZLV guest as a business entity listed in the notebook";
"master detail pane where the master is the business entity root and the field groups will show
up as a stacked pane"; the list in a TOML file he edits.

- Left pane, notebook "B360 Data": one item per `[[entity]]` in `backend/b360_entities.toml`
  (label from the file, else metadata) - `data-testid="nav-b360-entity-<name>"`. Not in the org:
  disabled, struck through, "(not found in org)". Last item "Show all entities"
  (`nav-b360-all`) -> `/b360`, every entity grouped Custom / Out of the box / Reference / Templates.
- Click "ZLV Guest" -> `/b360/zlv_guest`, ribbon tabs **Records** | **Metadata**.
- Records tab, stacked, both full width: MASTER (`b360-master`) = first 10 records, root fields as
  columns (`b360-records-table`, rows `b360-record-<businessId>`); the first record is picked
  automatically. DETAIL (`b360-detail`) below = "Root fields" key/value table, then each field
  group as its own block (`b360-group-<name>`), stacked, no tabs; zlv_guest has none, so it shows
  "This entity has no field groups." (`b360-no-groups`).
- Metadata tab (`b360-metadata`): root fields table (field, label, type, mandatory, searchable),
  then one table per field group with its cardinality.
- Agent bridge unchanged: `listB360Entities(scope)`, `getB360Metadata`, `getB360Records`,
  `openB360Record`. `openNavSection("b360-data")` opens the all-entities page.
- Not yet observed in a browser (no Cypress for this version).


## v0.9.8 (2026-11-23): B360 Data - Add records tab

Asked by Vamsi (voice, 01:05-01:10 CST): type data in a form built from the metadata (Pydantic) and Save,
or generate N test rows with Faker, then save them through the REST API.

- Ribbon tab "Add records" (id `add`) on each B360 Data entity page, after Records and Metadata.
- Top: Source system dropdown `b360-add-source` (from `[sources]` in b360_entities.toml, default zlv_ttf),
  discovery note `b360-add-discovery`, hint `b360-add-not-allowed`. Mode buttons `b360-add-mode-type`,
  `b360-add-mode-generate`.
- Type it (`b360-add-form`): one input per root field `b360-add-field-<name>` (text / number / checkbox /
  date / datetime by data type), required starred; sourcePKey box `b360-add-pkey` (empty = generated);
  Save `b360-add-save` (disabled until required fields are filled; confirm dialog; data-agent-confirm);
  Clear form; collapsible Pydantic JSON schema `b360-add-json-schema`. Field groups are not in the form yet.
- Generate (`b360-add-generate`): Number of records `b360-add-count` (clamped 1..100), Generate
  `b360-add-generate-btn` (backend Faker, no IDMC call), rules line `b360-add-rules`, editable preview table
  `b360-add-preview` with cells `b360-add-cell-<i>-<field>` and Remove `b360-add-remove-<i>`; Send to B360
  `b360-add-send` (shows the count; confirm dialog); Clear preview.
- Result `b360-add-result`: per row sourcePKey, outcome (CREATED / FAILED / NOT_SENT / UNKNOWN), businessId,
  needs approval, error; `b360-add-stopped` when a 429 / 401 / 403 / no answer stopped it.
- After anything is created the Records view reloads (master list shows the new records).
- Agent bridge: `getB360SourceSystems()`, `generateB360Rows(name, count)` (read-only). Creating is only by
  a person's button.
- Not yet seen on a screen: built and unit-tested only; no Cypress, no screenshot, not run against his org.


## v0.9.9 (2026-11-23): B360 Data - Records paging, filters, Last updated sort, system metadata

Asked by Vamsi (voice, ~01:30 CST): 10 per page with Prev / Next, filter by first name, last name and
Business ID, a Last updated column sortable server side (only that one), and system fields in the Metadata tab.

- Records tab master list (`b360-master`): filter row `b360-filters` with First name `b360-filter-first`,
  Last name `b360-filter-last` (both "starts with"), Business ID `b360-filter-bid` (exact), Apply
  `b360-filter-apply` (also Enter in a box; always goes back to page 1), Clear `b360-filter-clear`.
- `b360-filters-applied` lists the filters the backend actually sent; `b360-records-note` explains a
  Business ID lookup (or "No active master record with business ID ...").
- Pager `b360-pager`: Prev `b360-page-prev`, `b360-page-info` "Page X of Y (N records)" (N = search hits),
  Next `b360-page-next`. Prev disabled on page 1, Next on the last page.
- Table: Business id, then **Last updated** (header button `b360-sort-updated`, data-sort NEWEST_FIRST /
  OLDEST_FIRST, default newest first; click flips and goes to page 1), then the root columns. Cell
  `b360-updated-<businessId>` shows `_meta.lastUpdateDate` with toLocaleString; tooltip "by <updatedBy>".
  Disabled while showing a Business ID result (one row). No other column sorts.
- Business ID lookup shows a one-row master list; clicking it opens the detail as before.
- Metadata tab: configured root fields and field groups as before (normal text), then "System fields"
  (`b360-meta-system-fields`) and system field groups (e.g. `b360-meta-group-_meta`) in magenta
  (`--system` CSS variable, lighter in dark mode) with a small "system" label; rows carry
  `data-origin="SYSTEM"`. "(documented)" marks items taken from the B360 REST API Reference because the
  org metadata reply did not list them. Colour is used ONLY here (taskflow history stays colourless).
- Agent bridge: `getB360Records(name, {page, firstName, lastName, businessId, sort})`.
- Not yet seen on a screen: built and unit-tested on the fake IDMC only; no Cypress, not run against his org.
- Backend-first (Vamsi 2026-11-23 01:40 CST: "make sure everything is all pragmatic. Everything is supported
  by the backend API first."): every 0.9.9 control sits on `GET /api/b360/entities/{name}/records`
  (typed `RecordPage`, in Swagger) or `GET /api/b360/entities/{name}` (typed `BusinessEntity` with
  `system_fields` / `system_field_groups`), each grounded in a documented IDMC call (Search API, Read Master
  Record by Business ID, metadata v2). Not faked in the UI. Caveats: the Last updated SORT and the custom-entity
  filter prefix are documented shapes not yet proven on his org; "(documented)" system items come from the
  API reference, not from the org's metadata reply.

## v0.9.10 (2026-11-23): Master vs Source tabs, source edit, field groups, no pop-ups

### No pop-ups anywhere (owner decision 2026-11-23 01:53 CST)

Vamsi 01:51-01:53 CST: "remove all those pop-ups ... we don't need those pop-ups", then "Take it out."
for the agent-permission asks too.

- Nothing pops up, for a person or an agent: Run (CDI task, MDM job, taskflow), Abort, Save (create and
  edit) and Send to B360 act at once; the result or error shows inline on the same page.
- Removed: window.confirm in AddRecordsView send, TaskflowsPanel start and terminate, agent.ts allow()
  (now always yes), agentActions.ts runJob / runTaskflowByName / terminateTaskflow.
- Kept: `data-agent-confirm` sentences on those buttons, as descriptive labels the agent sees in
  snapshot(); they no longer block.
- Guard: `frontend/src/noPopups.test.ts` fails on any window.confirm / alert / prompt call in
  frontend/src (no exceptions). Cypress taskflows_fake.cy.js fails if a confirm ever fires.

### 0.9.12.4 (Vamsi 02:48-02:50 CST): Merge history (M) / (S) tabs + Copy IDMC curl

- Ribbon ends: ... | Merge (M) | Merge history (M) | Merge history (S).
- **Merge history (M)**: Business ID input ("Merge history master business ID", pre-filled with the
  row picked on Records (M)) + Load. Muted note (no merge-event log in the IDMC API; this app's own
  merges listed from backend memory, lost on restart). Table "Merge history master fields": field,
  value, source system, pkey, trust rule, trust score, manual override, last updated, trust entry
  (own / record-wide (/)). Table "Merge history contributors" oldest first. List "Pressed in this app".
- **Merge history (S)**: inputs "Merge history source system" (default zlv_ttf) + "Merge history
  sourcePKey" + Load. Belongs to master <id>; table "Merge history source trust"; table "Merge
  history source fields" (this source / master now / won yes-no / master value came from).
- **Copy IDMC curl**: button "Copy IDMC curl (B360 <entity>)" under the entity toolbar (also on
  Taskflows: "Copy IDMC curl (CDI taskflows)" / "(Business 360 taskflows)", and B360 jobs). Disabled
  until the screen has made an IDMC call. SUPERSEDED by 0.9.13.1 (see below): nothing is shown
  inline any more.

### 0.9.12.3 (Vamsi 02:45 CST): Records (M) | Records (S) | Metadata [Master | Source] | Add records (S) | Edit records (S) | Merge (M)

- **Records (S)** no longer shows the master list. Top: checkbox row "Source systems" (UI SDK
  Checkbox, aria "Source system zlv_ttf" / "zlv_eci" / "c360.default.system", testids
  `b360-sources-systems-<sys>`), default = [sources] default (zlv_ttf). Then the sourcePKey lookup, a
  muted line `b360-sources-filter-note` (filtered by tx-mdm after the IDMC read; paging per master
  page), Previous / Next master page buttons, and one flat table: Source system | sourcePKey (button
  "Open source record <sys>/<pkey>") | Master business id | fields | xref system columns (magenta).
- **Metadata**: one ribbon tab; beneath it a sub-tab strip (testid `b360-meta-subtabs`) "Metadata
  Master" (default, the old Metadata (M)) and "Metadata Source" (the old Metadata (S) plus the same
  checkbox row, testids `b360-meta-systems-<sys>`, and a line naming the ticked systems: one model
  for all of them). Agent: act("Section tabs","setValue",["metadata"]) then click "Metadata Source";
  the old id "source-metadata" still works and lands on Metadata > Source.
- The descriptions of Records (S) / Metadata (S) below are the 0.9.10 state, kept for history.

### Tabs (ribbon, 0.9.10): Records (M) | Metadata (M) | Records (S) | Metadata (S) | Add records (S) | Edit records (S)

- **Records (M)**: master list in its own scroll box `b360-records-scroll` (Vamsi 01:47 CST "I want a
  scrollbar"): horizontal scroll when wide, about 10 rows high (24rem), header row sticky. Above the table a
  chip row "Open master record" (SDK Listbox `b360-record-picker`) - clicking a chip or a table row opens the
  detail; the chip row is what an agent uses. System (_meta) columns follow the configured columns, magenta
  (`system-col`, data-origin SYSTEM), values exactly as the API returned them; the detail ends with a magenta
  "System fields (_meta)" block. Filters are SDK Inputs (Filter First name / Last name / Business ID), Apply /
  Clear / Previous page / Next page / Sort by Last updated are SDK Buttons.
- **Metadata (M)**: configured fields normal colour; two magenta groups, each with a one-line muted note
  (Vamsi 01:56-01:58 CST): "System fields" = business-facing, data-influenced (validationType,
  validationState, recordStateIndicator, _indexValidationError.code); "Record system metadata (_meta)" =
  purely system-owned, no user control (businessId, id, businessEntity, created / updated by and dates ...).
  Each table has an SDK Listbox "<group> field list" chip row (name, type, system / mandatory) for agents.
- **Records (S)**: the same master list on top ("Pick a master record"); below, the picked master's source
  records (Read Source Records by Master Record + Read Source Record each, max 20) in their own scroll box
  `b360-sources-scroll`, xref system columns magenta, chip row "Open source record". Lookup row: Source system
  (SDK Select, [sources] allowed) + sourcePKey + Open. Detail stacked: root fields, each group with `_id`, xref
  _meta in magenta, button "Edit this source record" -> Edit tab with it loaded. No "all source records" list:
  B360 says source records aren't searchable (p. 82).
- **Metadata (S)**: same view, muted note says it is derived (same entity metadata + documented xref _meta
  fields; no separate call exists).
- **Add records (S)**: as 0.9.8 plus field groups (any group from metadata, e.g. x_phone): Type it shows a
  block per group (add / remove rows); Generate makes 1-2 rows per MANY group, picklist codes only from
  values seen in real records; preview shows group rows under each record, editable and removable.
  Save / Send go at once, result inline.
- **Edit records (S)**: Source system + sourcePKey + Open (or "Edit this source record"). Typed form
  prefilled (root fields + group rows). "Show changes" = dry run: table Operation / Path / Old / New / Path
  shape (documented or UNVERIFIED) inline. SUPERSEDED by 0.9.13.1 (see below): Save enables on the first
  real change; "Show changes" became "Preview PATCH". Sends ONE PATCH; result note inline ("IDMC says
  approval is required" when approvalRequired). No master-record edit anywhere.

### Agent check (fake IDMC only)

`frontend/cypress/e2e/agent_b360_fake.cy.js` drives only window.agent snapshot()/act()/query(): open ZLV
Guest (left pane Listbox), Next page, Filter First name "Anna" + Apply, Metadata (M), Add records (S) ->
Generate mode -> 2 rows. Passed 2026-11-23 ~02:08 CST; every label was found. Snapshot: 6 components / 1535
chars at start, 15 / 3284 on Records (M), 15 / 4247 on Metadata (M), 57 / 9362 after generating 2 rows.
`window.agentReady` resolves once snapshot() lists something (`<html data-agent-ready="true">`); the
shell is ready first, the entity list a few seconds later - wait for the label you need.
Still not in the snapshot by design: tables themselves (own markup, labelled with aria-label); agents use
the chip-row Listboxes instead.

## v0.9.11 (2026-11-23 ~02:10 CST): hide fields via TOML, ffr_ left empty, API docs link

- **Title bar**: "API docs" link (`api-docs-link`, aria-label "OpenAPI docs") just before the version label;
  opens the backend Swagger UI `/docs` in a new tab. Vite proxies `/docs` and `/openapi.json` to the backend
  like `/api`, so it is same-origin on his laptop (Vamsi 02:08 CST).
- **Hide fields** (Vamsi 02:01 CST): `backend/b360_entities.toml` lists every field of zlv_guest under
  `fields = [...]`, one per line (configured, x_phone group + its fields, system fields, `_meta.*`). Comment a
  line out with `#` and restart the backend: that column / detail row disappears from Records (M) and Records
  (S) (a commented group hides the whole group). Metadata tabs still show everything. The page lists what is
  hidden (`b360-hidden-fields`); a name the metadata does not know shows a warning line
  (`b360-visibility-warning`) and is ignored. No list = show all. Backend-first: the records endpoints return
  a typed `visibility` {listed, hidden, warnings}.
- **Generate**: ffr_<x> = freeform reason (free text for when validation of <x> fails), so generated rows
  leave every ffr_* empty; the rules line says so.
- Fake IDMC note: the fake's zlv_guest has different field names (guestId, fullName ...), so with the repo
  TOML the fake screens show warnings and hide the fake-only fields. Expected; his org matches the list.

## v0.9.12 (2026-11-23 ~02:40 CST): Merge (M), Reference 360 picklists, API docs (typed)

### Merge (M) tab (ribbon of every B360 Data entity, after Edit records (S))
- Intended: merge 2-10 master records, choose a winner per root field, see what IDMC kept.
- Click order: paste ids into "Merge business IDs" (`b360-merge-ids`; spaces / commas / new lines
  split them; the selected Records (M) record is pre-filled) -> Load (`b360-merge-load`, read-only
  preview) -> table `b360-merge-table`, one row per field (`b360-merge-row-<field>`), one radio group
  per field (`b360-merge-winner-<field>`, aria-label "Winner for <field>"; options "<field> IDMC
  decides" (default, no override) and "<field> from <id>"). clns_ rows say "follows <field>" and have
  no radio. -> Merge (`b360-merge-go`, aria-label "Merge master records"; no pop-up,
  `data-agent-confirm` is a label only).
- Result inline (`b360-merge-result`): steps READ / MERGE / OVERRIDE / READ_BACK
  (`b360-merge-step-<STEP>`, OK / FAILED / SKIPPED + text), survivor id (`b360-merge-survivor`),
  overrides table (`b360-merge-overrides`: field, winner, sent, read back, stuck yes/no), note
  (`b360-merge-note`), errors (`b360-merge-error`).
- Undo (`b360-unmerge`): "Show source records to unmerge" (`b360-unmerge-load`) -> one checkbox per
  source ("Unmerge <system>/<pkey>") -> "Unmerge selected sources" (`b360-unmerge-go`) -> note
  `b360-unmerge-note`.
- His first use: ids `100000000000141 100000000000150`, first_name from 141, last_name from 150;
  expect Charles Harrison (clns CHARLES / HARRISON). Not yet seen live.

### Picklists from Reference 360
- Metadata (M) table has a new last column "Lookup list (Reference 360)"
  (`b360-meta-lookup-<field>`): rdm entity + where it came from (metadata attribute / code list
  label match), "GUESS" when matched by field name only, or "not found (UNVERIFIED ...)" with the raw
  attribute names of that field. First live look tells us what IDMC calls the reference.
- Add records (S) / Edit records (S): ph_typ dropdown = the 11 Reference 360 Codes; picklist note
  says where values came from. Generate fills x_phone again (random real Code).

### Title bar
- "API docs (typed)" link (`api-docs-typed-link`, aria-label "OpenAPI docs typed per business
  entity") next to "API docs": opens `/docs-typed` (Swagger on `/openapi-typed.json`).

## v0.9.12.1 (2026-11-23 ~02:45 CST): no boxes above tables (owner: "redundant information")
- Records (M): REMOVED the horizontal "Open master record" Listbox (`b360-record-picker`,
  items `b360-pick-<id>`). Click the row; the Business id cell is now an SDK Button
  (`b360-open-<id>`, aria-label "Open master record <id>") for the agent. Selected row keeps the
  existing neutral `selected` style.
- Records (S): REMOVED the "Open source record" Listbox (`b360-source-picker`). The sourcePKey cell
  is a Button (`b360-open-source-<system>/<pkey>`, aria-label "Open source record <system>/<pkey>").
- Metadata (M) / Metadata (S): REMOVED the horizontal field-list Listbox above each field table
  ("Root field list", "<group> field list", "System fields field list", `<testid>-list`). The tables
  stay and now carry aria-label "<title> fields" (e.g. "Root fields").
- Kept (not duplicates): Business ID lookup and name filters on Records (M), the source-system +
  sourcePKey lookup on Records (S) - they are inputs, not copies of the table.
- Agent Cypress (`agent_b360_fake.cy.js`) updated: looks for a label starting "Open master record ",
  waits on `b360-meta-fields` instead of "Root field list". Not re-run on this VM.

## v0.9.12.2 (2026-11-23 ~02:50 CST): lengths
- Metadata (M) / (S) field tables: new "Length" column (`b360-meta-length-<field>`), e.g.
  "max 3 (CONFIG)", "exactly 10 (CONFIG)", "max 12 (LONGEST_CODE)". Warnings above the root table
  (`b360-length-warning`) when a TOML length exceeds the metadata or names an unknown field.
- Type it / Edit: text inputs get maxlength, integer inputs min / max from the same bound.

## v0.9.13 (2026-11-23 ~03:10 CST): typed cleanup, no visible change intended
- Records (M) / (S) / Edit hide fields, groups and system columns from typed FieldPath objects
  (backend) instead of dotted strings; same screens, same labels.
- "Hidden by b360_entities.toml: ..." line renders each FieldPath as group.field / group / field.
- Merge box still accepts ids separated by spaces, commas, semicolons, tabs or new lines, quotes
  stripped (now a character loop, shared/text.ts).

## v0.9.13.1 (2026-11-23 ~03:20 CST): form alignment, Save enabling, row copy, curl to clipboard
- **Add records (S) Type it and Edit records (S)** (Vamsi 02:56 "not aligned properly"): ONE form grid
  (`FieldGrid`, role group, aria "Add form fields" / "Edit root fields", testid `b360-add-field-grid` /
  `b360-edit-field-grid`). Label column 16rem, left-aligned (label, "*" when required, the field name
  in small code); inputs, dropdowns 24rem wide, 30px high, same left edge; checkboxes sit in the
  input column. sourcePKey is a line of the same grid. Edit shows the record's system (_meta) values
  read-only in the same grid, magenta labels.
- **Field groups** (x_phone): a mini table, aria "<scope> <group> rows" (e.g. "Edit Phone rows"):
  columns # | each field (cntry_cd | ph_num | ph_typ | no_mrkt_calls) | Row (_id or "new" + Remove).
  One table row per phone row. Inputs keep their aria-labels ("Edit Phone row 1 ph_num").
- **Edit records (S) Save** (Vamsi 02:59 "the Save button is still disabled"): the pending changes are
  computed in the browser on every keystroke (typed `PendingChange`: CHANGED / ROW_ADDED /
  ROW_REMOVED, group, row, field, old, new) and listed under the form automatically (table aria "Edit
  pending changes", testid `b360-edit-pending`). Save enables as soon as there is one change. With no
  change: inline line "No changes yet." (`b360-edit-no-changes`). After Save the record is re-read
  from IDMC, so the list starts empty again. "Preview PATCH" (aria "Edit preview PATCH", was "Edit
  show changes") is optional: the backend dry run, showing the exact PATCH ops and path shape.
- **Add records Type it Save**: when disabled, an inline line says why (`b360-add-save-why`), e.g.
  "Save is disabled: pick a source system; first_name is required."
- **Row copy** (Vamsi 03:01): click a row in Records (M) or Records (S) (it highlights), then Ctrl+C /
  Cmd+C copies JUST that row: a tab-separated header line + value line (pastes into Excel); field
  group rows go into one cell each as compact JSON; ASCII only. A real text selection in the table
  keeps the browser's normal copy. Hint / result line above the table (`b360-records-copy-note`,
  `b360-sources-copy-note`): "Row copied to the clipboard." No pop-up, no toast.
- **Copy IDMC curl** (Vamsi 03:11 "You really don't have to show me on the screen"): the button copies
  the PowerShell script straight to the clipboard; a small "bash" button next to it copies the bash
  variant. Nothing is rendered. A small muted line beneath: "Text copied to the clipboard." (plus "It
  contains WRITE calls" when so) or "Could not copy to the clipboard: <reason>"
  (`idmc-curl-status-<slug>`). Clipboard: navigator.clipboard, fallback hidden textarea +
  execCommand("copy").
- Cypress screenshots of both forms: NOT taken in this patch (see report).

