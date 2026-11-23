# UI observations (agent notes - read first in any session touching the tx-mdm UI)

Standing rule (Vamsi, 2026-11-22 23:04 CST): keep these notes current whenever the app changes:
what each screen / element does, what to click for each workflow, intended vs actual behaviour.
Last updated: 2026-11-22 ~23:55 CST, v0.8.0 redesign commit. Observed with Cypress (Electron) against the
fake IDMC (backend/dev/fake_idmc.py). Not yet observed against the live org - see the end.

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

