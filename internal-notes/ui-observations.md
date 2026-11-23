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
