# tx-mdm testing harness - design (BUILT in 0.10.0)

Status: built in 0.10.0. The no-code hold (21:34 + 21:41) was lifted 22:35 ("Write the code and
then you run it yourself"). Code: backend/app/testing/, backend/test_cases/, roadrunner-py/.
Consolidated 2026-11-23 22:17 CST from the decision log below. The log is history; THIS section
is the current design. Where they disagree, this section wins.

## 1. Shape
- API-driven only. NO frontend testing bookshelf (cancelled 21:54).
- Groups: SOURCE groups (TTF first, then ECI) and an MDM group (source-independent: purging,
  indexing, match and merge). Match and merge is also a step inside source pipelines.
- Inside each group: numbered use cases (use-case-1, use-case-2, ...).
- Two paths: /api/test/mock/<GROUP>/... = everything mocked (IDMC faked, SQLite stands in for the
  Oracle/Snowflake source and egress tables); /api/test/<GROUP>/... = real services.
  ("mock" right after "test" = mock everything.) /api prefix used in the approved draft; not
  confirmed verbatim.
- Mock runs ("dry runs") go through the mock API, so the same server code runs; for a laptop-only
  dry run the harness starts the same backend locally in mock mode.

## 2. Use-case TOML (one per use case per group)
- Human-only sections: [use_case] (id, source, title, template_version, author, last_updated),
  [scenario], [test_data], [expected.results], [expected.validation], [expected.data_issues], [notes].
  Code never interprets these; it copies them onto the Excel Home sheet.
- Machine-read [mock] section: scripts each faked step (status, row counts, merges, MDM records with
  validation state + reason, egress rows). Only part the code reads.

## 3. Excel (.xlsx only)
- Template prompt: EMPTY or AUTO-GENERATED data; if generated, tester picks NUMBER OF ROWS; data is
  shaped to the use case; Expected sheet comes PRE-FILLED to match (tester reviews/edits).
- Sheets: Home (FIRST: test name, use case, source, template version, then TOML blocks), CLIENTS,
  FYCLIENTS, DEMOGRAPHICS, SUBMISSIONS, Expected.
- Result workbook: Home, Handshakes, then actual vs expected with pass/fail per row.

## 4. TTF pipeline (source use cases)
load source tables -> tf_Ldg_MDM_CDI_TTF -> tf_Stg_MDM_CDI_TTF -> MDM ingress (zlv_ingr_guest-basic)
-> match and merge -> egress ("Egress ZLV Guest basic Src_TTF") -> read egress targets -> compare.
Entity zlv_guest, source zlv_ttf.

## 5. Use cases (approved 21:39; UC9 21:45-21:52)
TTF: UC1 new member, UC2 name/phone update, UC3 duplicate (same name+DOB -> one master),
UC4 not duplicate (diff DOB -> two masters), UC5 inactive, UC6 missing required field,
UC7 orphan DEMOGRAPHICS, UC8 multi-month latest wins, UC9 junk phones land in MDM with
validation failed + reason "invalid phone" (patterns are human notes only).
MDM group: purge, indexing, match and merge - use cases NOT yet drafted.

## 6. Endpoints ({base} = /api/test/mock/<GROUP> or /api/test/<GROUP>)
GET  {base}/use-cases
GET  {base}/{use_case}/template?mode=empty|generated&rows=N
POST {base}/{use_case}/runs                       upload filled Excel -> run_id
GET  {base}/{use_case}/runs/{run_id}              per-step status
POST {base}/{use_case}/runs/{run_id}/abort
GET  {base}/{use_case}/runs/{run_id}/comparison   typed JSON
GET  {base}/{use_case}/runs/{run_id}/result       result Excel
(Run-all is driven by the harness looping use cases; no server endpoint needed unless wanted.)

## 7. Desktop harness (pytest-bdd 9.x, runs on the tester's Windows desktop, talks HTTP to the Linux box)
- Separate client package; no backend imports; ASCII only.
- Start menu offers HELP before any scenario: dumbified step-by-step, copy-paste PowerShell, one
  directory per test case, which sheets are needed, fetches the template into the folder.
- Run one use case, a group, or ALL (dry run).
- Handshake pauses at manual steps (prepare Excel, run ingress/egress, confirm): options
  1/done (DEFAULT, Enter), 2/retry, 3/skip, 4/abort; number or word.
- Scripted answers TOML per use case keyed by step title; keyword HUMAN = wait for a person.
  Assistant's files never contain HUMAN -> fully unattended.
- Pre-flight check (server reachable, versions, sheets/columns/types) before anything loads.
- After Done, verify via API (job status + row counts); failed check -> pause again.
- Resume a run by run_id after the terminal closes (run state on the server).
- One real-path run at a time per source (lock). Mock runs not locked.
- Run log written beside the result Excel.
- NO data cleanup/purge/run-id tagging by runner or code. Tester owns cleanup.

## 8. Still open (needs Vamsi)
1. Egress target tables to read and the exact Expected-sheet columns.
2. Real-path source DB connection (Oracle or Snowflake, which schema).
3. Real match-and-merge job (jobDefinitionId, matchModelId, version) - not configured in his org.
4. zlv_guest field that carries the "invalid phone" reason (real path).
5. MDM-group use cases (purge, indexing, match-merge) - what each proves.
6. What he wants once the code is written (his 21:39 sentence was cut off).
7. /api prefix, command names (txmdm-test help/init/run), [mock] shape - proposals, unconfirmed.

## 8a. Assistant's picks (Vamsi 22:18: "I have not configured anything... come up with the names and
## the tables and all that the way you like it") - placeholders, config-driven, changeable
- Egress target (mock SQLite + real-path default name): EGR_ZLV_GUEST_TTF
  cols: MASTER_ID, SOURCE_SYSTEM, SOURCE_PKEY (CLIENTCODE), FIRST_NAME, LAST_NAME, MIDDLE_NAME, DOB,
  PHONE, ACTIVE, VALIDATION_STATE, VALIDATION_REASON, MERGED_SOURCE_COUNT, EGRESS_TS.
- Expected sheet cols: CLIENTCODE, EXPECT_IN_MDM (Y/N), EXPECT_MASTER_GROUP (rows sharing a value
  must merge to one master), FIRST_NAME, LAST_NAME, DOB, PHONE, ACTIVE, VALIDATION_STATE,
  VALIDATION_REASON, NOTES. Blank cell = not checked.
- Source DB: one connection setting in backend config, kind = oracle | snowflake | sqlite;
  mock path always sqlite. Table names = the LDG_TTF_* landing tables (schema configurable).
- Match-merge real job placeholder: jobDefinitionId "zlv_guest_match_merge", matchModelId
  "zlv_guest.ruleset1", version 1 - to create in B360 Console with those names, or overwrite.
- Invalid-phone field: VALIDATION_REASON in egress; in MDM read from _meta.validation (mock sets it).
- MDM group use cases: MDM-UC1 match and merge only (pre-seeded records -> expected merges);
  MDM-UC2 reset matched records; MDM-UC3 search indexing (record findable by name after index job);
  MDM-UC4 purge (record gone after purge, soft-deleted kept otherwise). Real-path purge/indexing
  job APIs to confirm from the B360 reference before build.

## 8b. Placeholders live in a TOML (Vamsi 22:18: "later I'm going to revisit and instruct you to
## change those... put that also into the Toml") - drafted here, file not created yet
Proposed file: backend/test_cases/test_config.toml (machine-read; one place to change names)

  [source_db]
  kind   = "sqlite"          # oracle | snowflake | sqlite (mock path always sqlite)
  schema = "LANDING"
  tables = ["LDG_TTF_CLIENTS", "LDG_TTF_FYCLIENTS", "LDG_TTF_DEMOGRAPHICS", "LDG_TTF_SUBMISSIONS"]

  [egress]
  table   = "EGR_ZLV_GUEST_TTF"
  columns = ["MASTER_ID", "SOURCE_SYSTEM", "SOURCE_PKEY", "FIRST_NAME", "LAST_NAME", "MIDDLE_NAME",
             "DOB", "ACTIVE", "VALIDATION_STATE", "VALIDATION_REASON",
             "MERGED_SOURCE_COUNT", "EGRESS_TS"]
  phone_table   = "EGR_ZLV_GUEST_TTF_PHONE"
  phone_columns = ["MASTER_ID", "SOURCE_PKEY", "CNTRY_CD", "PH_NUM", "PH_TYP", "NO_MRKT_CALLS",
                   "VALIDATION_STATE", "VALIDATION_REASON"]

  [expected_sheet]
  columns = ["CLIENTCODE", "EXPECT_IN_MDM", "EXPECT_MASTER_GROUP", "FIRST_NAME", "LAST_NAME", "DOB",
             "PHONE", "ACTIVE", "VALIDATION_STATE", "VALIDATION_REASON", "NOTES"]

  [pipeline.TTF]
  ldg_taskflow = "tf_Ldg_MDM_CDI_TTF"
  stg_taskflow = "tf_Stg_MDM_CDI_TTF"
  ingress_job  = "zlv_ingr_guest-basic"
  egress_job   = "Egress ZLV Guest basic Src_TTF"
  entity       = "zlv_guest"
  source       = "zlv_ttf"

  [match_merge.zlv_guest]
  job_definition_id = "zlv_guest_match_merge"
  match_model_id    = "zlv_guest.ruleset1"
  match_model_version = 1

  [validation]
  reason_field = "VALIDATION_REASON"

Every value marked as a placeholder in a header comment; Vamsi edits this file to change them.

## 8c. Phones are a 0..N field group (Vamsi 22:20) - verified in backend/b360_entities.toml lines 36-41
- zlv_guest field group x_phone: cntry_cd, ph_num, ph_typ (11-code picklist), no_mrkt_calls.
  A member can have ZERO, ONE or MANY phones.
- Design changes:
  - Egress: phones go in a CHILD table EGR_ZLV_GUEST_TTF_PHONE (MASTER_ID, SOURCE_PKEY, CNTRY_CD,
    PH_NUM, PH_TYP, NO_MRKT_CALLS, VALIDATION_STATE, VALIDATION_REASON); PHONE column dropped from the
    parent egress table.
  - Expected: a separate ExpectedPhones sheet (CLIENTCODE, PH_NUM, PH_TYP, CNTRY_CD, VALIDATION_STATE,
    VALIDATION_REASON); a member with no rows there = expect zero phones. Compare the SET of phones.
  - UC9 invalid phone: validation reason is per phone row, so one good + one junk phone on the same
    member is checkable.
  - New use cases: UC10 member with NO phone (zero rows, no error); UC11 member with TWO+ phones of
    different types (all land, none dropped).
  - Open: TTF source has one PHONE column on DEMOGRAPHICS; multiple phones for one member come from
    several months/rows. Confirm how the ingress maps PHONE -> x_phone (mapping not seen yet).
  - Generated data covers 0, 1 and 2+ phones per member.

---

# Decision log (history, newest at bottom)

# Testing bookshelf - design (held, NOT built)

Captured from Vamsi, voice call 2026-11-23 21:11-21:34 CST. His instruction at 21:34:
"hold the design in your thought process. Don't write any code."

## Shape
- Bookshelf > Notebook > Section > ribbon tab.
- Existing shelf: CDI, MDM, B360, Design. NEW separate Testing bookshelf (not a 5th notebook).
- Testing notebooks are by SOURCE SYSTEM: TTF first, then ECI.
- Sections inside a notebook are use-case based.

## TTF use case 1 - member end to end
- Entity: zlv_guest, source zlv_ttf (confirmed; not zlv_person).
- Flow:
  1. User downloads an Excel TEMPLATE from the UI.
     - Worksheet "Home": instructions on how to fill it.
     - One worksheet per TTF landing table: LDG_TTF_CLIENTS, LDG_TTF_FYCLIENTS,
       LDG_TTF_DEMOGRAPHICS, LDG_TTF_SUBMISSIONS (columns from idq-cli docs/LDG_EXPORT_OCT_16.sql).
     - Placeholders for EXPECTED RESULTS, filled by the user.
  2. User uploads the filled workbook.
  3. Harness loads the rows into the TTF source tables (Oracle OR Snowflake).
  4. Runs CDI tf_Ldg_MDM_CDI_TTF, then tf_Stg_MDM_CDI_TTF.
  5. Runs MDM ingress, then match and merge, then egress.
  6. Reads the egress target tables.
  7. Compares actual vs expected.
  8. User downloads a result Excel (actual alongside expected).

## Rules
- Headless: everything drivable via the API and/or the UI.
- Development testing: API only, no UI needed.
- Mock everything for development: mock scenarios behind the scenes.
- Usual tx-mdm rules: API-first, typed models, ASCII only, no pop-ups, SDK components with aria-labels.

## Open
- Match-and-merge job not defined in the org yet. B360 API reference (Oct 2026, ~line 7667)
  says a match and merge job must first be defined in Business 360 Console; the API call needs
  jobDefinitionId + matchModelId + matchModelVersion. Plan: toml placeholder for zlv_guest,
  step skipped until filled.
- Which egress target tables to read, and the expected-results layout, not yet specified.
- Source DB connection details (Oracle / Snowflake) not yet given.

## Mocking (his words 21:35: "mock the services end to end")
- Every service in the chain is mocked for development: Excel template/upload, source DB load
  (Oracle/Snowflake), CDI taskflows, MDM ingress, match and merge, egress, egress target-table read.
- Extend the existing fake IDMC stand-in rather than inventing a second one.
- SCOPE (his words 21:36): mocking happens ONLY on the mock endpoint path "test/mock/TTF".
  Everything else (presumably a non-mock test path) hits real systems. Exact prefix (/api?) and
  the real-path name not yet confirmed.

## Paths (his words 21:37)
- Mock:  test/mock/TTF/use-case-1, use-case-2, ...  -> mock ALL IDMC behaviour; SQLite stands in
  for the Oracle/Snowflake TTF source (and egress target) tables.
- Real:  test/TTF/use-case-1, ...                   -> real services.
- Rule: if "mock" comes right after "test" in the path, everything is mocked.

## Proposed test cases (DRAFT, for his review)
- UC1 New member: 1 CLIENTS + 1 FYCLIENTS + 1 SUBMISSIONS + 1 DEMOGRAPHICS row -> one zlv_guest
  master under zlv_ttf; egress row with same name, DOB, phone.
- UC2 Name/phone update: same member, later month with changed LASTNAME/PHONE -> master updated.
- UC3 Duplicate member: two CLIENTS, same name + DOB -> match and merge gives one master, two
  sources (needs his match-merge job; skipped on real path until configured).
- UC4 Not a duplicate: same name, different DOB -> two masters.
- UC5 Inactive member: ACTIVE=0 + INACTIVEDATE -> record soft-deleted / inactive in MDM.
- UC6 Missing required field (no DOB or no LASTNAME) -> rejected, error captured, no egress row.
- UC7 Orphan row: DEMOGRAPHICS with no matching CLIENTS/FYCLIENTS -> rejected at staging.
- UC8 Multi-month: three DEMOGRAPHICS months, one member -> one master, latest values win.

## Proposed endpoints (DRAFT; {base} = /api/test/mock/TTF or /api/test/TTF)
- GET  {base}/use-cases                       list use cases
- GET  {base}/{use_case}/template             download Excel template (Home + 4 sheets + Expected)
- POST {base}/{use_case}/runs                 upload filled Excel, start run -> run_id
- GET  {base}/{use_case}/runs/{run_id}        status per step (load, ldg, stg, ingress, match-merge, egress, read, compare)
- POST {base}/{use_case}/runs/{run_id}/abort  stop the run
- GET  {base}/{use_case}/runs/{run_id}/comparison   typed JSON: expected vs actual, pass/fail per row
- GET  {base}/{use_case}/runs/{run_id}/result       download result Excel
- Match and merge (his words 21:40: "you can mock the match and merge job"): on the mock path it is
  mocked like every other step, so UC3/UC4 run fully under test/mock/TTF. Only the real path waits
  on a real match-merge job definition.

## Refinements (his words 21:41, still no code)
- UI TESTING REQUIRED for this feature: test in the UI that (1) template download, (2) filled
  Excel upload, (3) after-run result Excel download all work - not API-only for these three.
- Format: EXCEL (.xlsx) - decided 21:42 ("let's stick with Excel"); CSV dropped. Home sheet MUST be the very first sheet and tell: what the test
  is, the use case, and the VERSION of that template document.
  Note: a CSV holds one sheet only, so Home + 4 tables + Expected needs xlsx (or a zip of CSVs
  with a Home.csv) - to confirm with him.
- UC9 Junk phone patterns (his words 21:45, CORRECTED 21:46): phones like all-same digits
  (2222222222, 3333333333) or sequences (1231231234, 1234567890). They DO go into MDM ("let them
  go into the MDM"), but MDM carries a VALIDATION REJECT REASON on them. Mock data includes a
  couple of each; pass = record present in MDM with the reject reason set for the phone.
  Mechanism (his words 21:46): record still gets into MDM, VALIDATION FAILS, and an ADDITIONAL
  validation-reason field says "invalid phone". Test checks: record present, validation failed,
  reason = invalid phone. (Exact field name in zlv_guest not yet identified.)
  SUPERSEDED 21:52 (his words): the junk-phone patterns are NOT config for programmatic validation.
  They are human notes in the use-case TOML only ("nothing for programmatic validation... just notes
  for the user"). The app does not check phone patterns itself; MDM does the validating.

## Use-case description TOML (his spec 21:50, design only)
- One TOML per use case per source, e.g. backend/test_cases/TTF/use-case-9.toml.
- HUMAN-ONLY: the tester fills/edits it; the app does NOT interpret it. The app only shows it in
  the UI (editable) and copies it onto the Excel Home sheet (template and result workbooks), so the
  downloaded result carries the use-case context next to the results.
- Proposed structure (all free text, ASCII only):

  [use_case]
  id            = "use-case-9"
  source        = "TTF"
  title         = "Junk phone numbers"
  template_version = "1.0"
  author        = ""
  last_updated  = "2026-11-23"

  [scenario]
  summary  = "Members arrive with junk phones (all-same digits, repeating sequences)."
  steps    = ["Load CLIENTS/DEMOGRAPHICS rows", "Run ldg + stg taskflows", "Ingress", "Match and merge", "Egress"]

  [test_data]
  description = "2 members with 2222222222 and 1231231234; 1 member with a good phone as control."
  rows        = ["CLIENTS: 3 rows", "DEMOGRAPHICS: 3 rows", "FYCLIENTS: 3 rows", "SUBMISSIONS: 1 row"]

  [expected.results]
  description = "All 3 members land in MDM as zlv_guest under zlv_ttf."

  [expected.validation]
  issues = ["Junk-phone members: validation failed, reason = invalid phone", "Control member: passes"]

  [expected.data_issues]
  issues = []

  [notes]
  text = "Junk patterns used: all-same digits (2222222222, 3333333333), repeating sequences
          (1231231234, 1234567890)."

- Approved by him 21:52 ("It feels right for the testers").
- Home sheet layout: test name, use case id, source, template version, then each TOML section as a
  labelled block in the same order. Same Home sheet goes into the result workbook.

## SCOPE CHANGE 21:54 (his words): NO FRONTEND TESTING BOOKSHELF
- "let's not worry about the bookshelf for the testing at all... the backend API, let's keep it
  intact... the frontend bookshelf for testing... way too complicated. Let's not do that. Instead,
  I want everything to be driven via the API."
- DROPPED: second bookshelf, shelf switcher, TTF notebook, use-case sections in the UI, and the
  earlier "test template download / upload / result download IN THE UI" requirement.
- KEPT: all /api/test/mock/TTF/... and /api/test/TTF/... endpoints, Excel template (Home first),
  upload, run, status, abort, comparison, result Excel, use-case TOMLs, UC1-UC9, mocks + SQLite.
- Use-case TOML is edited as a file (or via API if we add GET/PUT for it - not decided), and the
  API copies it onto the Home sheet.

## Python BDD (raised by him 21:54: "take these ideas forward... use the Python BDD")
- Backend already uses pytest>=8 (backend/pyproject.toml). pytest-bdd latest on PyPI 9.0.1 (checked
  2026-11-23); alternative behave 1.3.3. Leaning pytest-bdd: plugs into existing pytest + fake IDMC
  fixtures. Not yet confirmed by him which library; still no code.

## Interactive BDD runner (his spec 21:56) - pytest-bdd CONFIRMED
- Gherkin Given/When/Then style kept, but the runner PAUSES at manual steps: it prompts the user in
  the terminal ("go ahead and do X, tell me when done"), shows OPTIONS, waits, then continues on the
  user's pick. Manual steps include: kick off MDM ingress, egress jobs, prepare the Excel sheet.
- Proposed prompt options (ASCII, numbered): [1] Done - continue  [2] Retry this check
  [3] Skip this step (mark SKIPPED)  [4] Abort the run.
- Proposed Gherkin form: a step like  When the tester manually runs "MDM ingress"  triggers the pause.
- Tech note: pytest captures stdin/stdout by default, so input() fails under plain pytest. The pause
  step must use capsys.disabled() (or the runner always passes -s). Wrap it in one helper.
- Open question: on the mock path, should manual steps auto-continue (no pause) so mock runs stay
  unattended? Ask him.

## Human handshake - plan (his ask 21:57: each test case can have ONE OR MANY human interventions)
1. One reusable helper handshake(step_title, instruction, options) in tests/bdd/handshake.py.
   Prints an ASCII [PAUSE] block, numbered options, reads the answer with stdin capture disabled
   (capsys.disabled()), re-asks on bad input. Returns a typed HandshakeResult (enum choice + time).
2. A small fixed set of Gherkin phrases trigger it, usable any number of times in one scenario:
     Given the tester prepares "<thing>"          (e.g. the Excel workbook)
     When the tester manually runs "<job>"        (e.g. MDM ingress, egress)
     Then the tester confirms "<observation>"     (e.g. record visible in B360 UI)
3. After [1] Done, the program VERIFIES where it can through the backend API (e.g. latest ingress
   job status / row counts). If the check fails it pauses again with Retry / Skip / Abort.
4. Every handshake (step, choice, timestamp, verify result) is logged per run and written to a
   'Handshakes' sheet in the result Excel, after Home.
5. Unattended mode for mock runs and CI: --auto (or env TXMDM_BDD_AUTO=1) answers Done to every
   pause; optionally a per-use-case answers file for scripted Skip/Abort tests. (Confirm with him.)
6. Run: a start script (run-bdd.ps1) wrapping: pytest backend/tests/bdd -s  [--auto]
7. Order of build (when he lifts the no-code hold): handshake helper + its unit tests -> step library
   -> UC1 feature on mock path end to end -> UC2-UC9 -> real path.
- DECIDED 21:58 (his words "It should wait... with options for the user to type done or what not"):
  pauses WAIT on the mock path too - no auto-answer by default. Answers accepted as the number OR a
  typed word: 1/done, 2/retry, 3/skip, 4/abort (case-insensitive). --auto stays only as an optional
  CI flag, off by default (not yet confirmed he wants it at all).
- 21:59 he began "When you are testing..." (cut off) - likely about how the assistant answers pauses during its own dev testing (scripted answers file / --auto). Await his words.
- DECIDED 21:59 (his words): every pause has a DEFAULT option (Done). Human tester: pause waits and
  shows the options; pressing Enter takes the default. Assistant's own dev testing: UNATTENDED, the
  default is taken every time (--auto / TXMDM_BDD_AUTO=1). Supersedes the 21:58 "auto off / maybe drop".
- DECIDED 22:00 (his words) - SCRIPTED ANSWERS FILE: a tester may pass a file of scripted answers,
  one answer per pause in order. Allowed answers: done, retry, skip, abort, and the keyword HUMAN.
  HUMAN = at that pause, wait for a real person (show options, Enter = default). So a human run can
  MIX scripted and live interventions. The assistant's own scripted files NEVER contain HUMAN, so its
  runs are fully automatic with no pauses. No file given = every pause waits for the human.
  Open: file format (proposed: one TOML per use case, keyed by step title) - not yet confirmed.
- DEPLOYMENT (his words 22:02): backend API + frontend are served from the LINUX BOX (server).
  The pytest-bdd harness runs on the TESTER'S DESKTOP (separate client). The tester creates a
  working directory and puts the needed Excel sheets (and answers file etc.) in it. Harness talks
  to the server over HTTP (base URL configurable). He was still describing - more to come.
  Implication: harness = separate installable client package (no backend imports); Windows-safe.
- TUTOR BEHAVIOUR (his words 22:03): runner picks up the tester's Excel files, does its work, writes
  the result Excel back. It also TUTORS: prints a user guide (create this directory, put these files);
  'help' before running tells, per test case, which Excel sheets it needs and hands over the Excel
  template (downloaded from the server's template endpoint into the folder). Still being described.
  Proposed commands (not confirmed): txmdm-test help [use-case], txmdm-test init <dir>,
  txmdm-test run <use-case>.
- 22:04 (his words): before running ANY scenario, the runner offers the human a HELP option. Help
  walks them through creating the directories and changing into them. ONE DIRECTORY PER TEST CASE
  (e.g. ttf\use-case-1\, ttf\use-case-2\ ...). Must be "pretty dumbified" - plain step-by-step,
  copy-paste PowerShell commands. The assistant may use the same prompts for its own runs if useful.
  Proposed start menu (not confirmed):  [1] Help - set me up (default for first run)
  [2] Run a test case  [3] Quit.
- 22:04 fragment (his words): "Source test case or MDM test case. Things like that." - directories /
  help may distinguish source-side test cases (TTF, ECI) from MDM-side test cases. Meaning not yet
  confirmed - ask.

## Assistant's improvement proposals (22:05, he asked "what can we improve") - NOT yet agreed
1. Pre-flight check before any run: server reachable, harness vs server version match, template
   version in the Home sheet matches, required sheets/columns present, values typed right. Fail fast
   on the desktop before anything is loaded.
2. Resume: run state lives on the server; if the terminal closes mid-pause, `resume <run_id>` picks
   up at the step it stopped on.
3. Verify manual steps: after the tester says Done for ingress/egress/match-merge, poll the B360 job
   status and row counts instead of trusting the word.
4. Test-data isolation + cleanup (real path): tag every test key with the run id (e.g. CLIENTCODE
   prefix) so reruns and parallel testers don't collide; a cleanup step removes/soft-deletes the
   test rows and MDM records afterwards.
5. One-at-a-time lock per source on the real path, so two testers can't run TTF at once.
6. Every run writes a short run log next to the result Excel (steps, timings, handshakes).
- 22:06 (his words): "there are some cases where MDM tests are independent of the sources" - so MDM-only test cases exist alongside source (TTF/ECI) test cases. Example still coming.
- 22:07 (his words): MDM-ONLY test cases exist, independent of sources: e.g. PURGING, INDEXING, MATCH AND
  MERGE. Match and merge lives in BOTH places: as an MDM-only test, and as a step inside a source
  pipeline (TTF UC flow). Layout: source groups (TTF, ECI) + an MDM group; match-merge reusable in both.
- 22:08 DECIDED (his words): "I do not want any data cleanup by IDs or anything like that done by the
  test runner or in the code. We will let the user handle it." -> proposal 4 DROPPED: no cleanup step,
  no run-id tagging of test keys by the runner. Tester owns data cleanup. Help text may tell the
  tester to clean up before re-running (wording only, no code action).
- 22:09 (his words, cut off): "if the user wants to run everything" - a RUN-ALL option (all test cases, or all in a group). Details still coming.
- 22:09 (his words, still talking): the user can RUN EVERYTHING on the desktop/laptop as a 100% MOCK run
  with SQLite - call these DRY RUNS / MOCK RUNS. The assistant uses the same mock runs for its own testing.
  Plan for it in the design. OPEN: does the mock run still call the server's /api/test/mock/... path,
  or run entirely on the laptop with no server (mock backend in-process)? Ask.
- 22:10 he asked: should mock runs hit the mock API or not? ASSISTANT RECOMMENDATION (not yet agreed):
  YES - always go through /api/test/mock/... . Reason: the mock path then exercises the SAME server code
  (Excel parsing, run state, step order, comparison, result Excel); only IDMC + Oracle/Snowflake are faked.
  A harness-only mock would test different code and drift. For a 100% laptop dry run with no Linux box,
  the harness can start the same FastAPI app on localhost in mock mode (SQLite), e.g.
  `txmdm-test run --all --dry-run --local`; otherwise it points at the server's mock path.
- 22:11 AGREED: mock runs hit the mock API (local or server). His philosophy (22:11): the mock case is
  about BRAINSTORMING the use cases and the DATA behind them.
- 22:12 (his words): "the behavior of the mock can be controlled by the Toml files."
  CONFLICT TO RESOLVE: 21:50 rule says the use-case TOML is human-only, never machine-interpreted.
  Assistant proposal: keep that file human-only, and add a SEPARATE machine-read mock TOML per use case
  (e.g. mock/TTF/use-case-9.mock.toml) that scripts each faked step: job status (SUCCESS/FAILED/
  SUSPENDED), row counts, delays, which records land in MDM, validation state + reason (UC9 "invalid
  phone"), match-merge outcome (which sources merge), egress rows. Awaiting his answer.
- 22:13 DECIDED (his words): "One combined Toml is good idea." ONE TOML per use case per source holds
  BOTH parts: the human-only description sections ([use_case], [scenario], [test_data], [expected.*],
  [notes]) which the code never interprets (only copies to the Home sheet), AND a machine-read [mock]
  section that scripts the faked steps. SUPERSEDES the 21:50 "whole file never machine-interpreted" rule:
  now only the [mock] section is read by code. Proposed [mock] shape (not yet confirmed):
    [mock.steps.ingress]      status="SUCCESS"  rows_in=3  rows_loaded=3
    [mock.steps.match_merge]  status="SUCCESS"  merges=[["CL-001","CL-002"]]
    [[mock.mdm_records]]      client="CL-009"  validation="FAILED"  reason="invalid phone"
    [mock.steps.egress]       status="SUCCESS"  rows=3
- 22:14 DECIDED (his words): "the rest of the recommendations put it in. The only one recommendation
  which I said no is the purging or deleting of the data." ACCEPTED into the design:
  (1) pre-flight check (server reachable, harness/server/template versions, sheets + columns, types)
  (2) resume a run by run_id after the terminal closes (run state on the server)
  (3) verify manual steps via API (job status + row counts) after the tester says Done
  (5) one real-path run at a time per source (lock)
  (6) run log written next to the result Excel
  plus: run-all option (dry run over all use cases), mock runs via the mock API (local backend in mock
  mode for laptop-only), combined TOML with [mock] section.
  REJECTED: (4) data purge/delete/cleanup by the runner or code, including run-id tagging of test keys
  for cleanup. Tester owns cleanup.
- 22:15 DECIDED (his words): before the template download, the prompt asks: EMPTY template or
  template with AUTO-GENERATED sample test data? If generated, the user gives the NUMBER OF ROWS.
  Data is generated to fit the USE CASE (e.g. UC3 = pairs with same name + DOB; UC4 = same name,
  different DOB; UC9 = junk phones like 2222222222 / 1231231234; UC7 = orphan DEMOGRAPHICS rows).
  Endpoint shape (proposal): GET {base}/{use_case}/template?mode=empty|generated&rows=N.
  Proposal: Expected sheet is pre-filled to match the generated rows (tester can edit); optional
  seed so the same data can be regenerated. Not yet confirmed.
- 22:16 DECIDED: generated template comes with the Expected sheet PRE-FILLED to match the generated rows; tester reviews/edits.
- 22:22 (his words, cut off): "should this be a Java based..." - reconsidering the language (likely the desktop harness: Java/Cucumber-JVM vs pytest-bdd). pytest-bdd was confirmed 21:56; not changed yet. Await his words.
- 22:23 DECIDED (his words): runner stays PYTHON (pytest-bdd), not Java - "It's just a runner. Okay,
  let's use Python." Code rules: STRONGLY TYPED (full type hints, Pydantic/dataclasses + enums,
  mypy --strict clean), pragmatic and succinct Python, NO excessive comments - at most THREE lines per
  comment, and NO excessive tests (necessary-only).
- 22:24 (his words): "make sure it's strongly typed. And also linted and also other practices that
  read the code elegantly, without a lot of noise and confusion." -> harness code: type-checked
  (PYREFLY, decided 22:26; was mypy --strict), linted + formatted (ruff), small functions, clear names, no noise. Tests: he
  noted unit tests are not the focus; BDD scenarios are the tests, plus only what is truly needed.
- 22:25 (his point): Meta/Facebook type checkers may beat mypy. Checked PyPI 2026-11-23: pyrefly 1.5.0
  (Meta, Rust-based, current), pyre-check 0.10.0 (Meta's older checker, pyrefly replaces it).
  Proposal: harness uses PYREFLY instead of mypy; ruff stays for lint/format. Caveat: backend uses
  mypy with the pydantic.mypy plugin - check pyrefly's Pydantic handling before switching backend too.
  Awaiting his pick: harness only, or backend as well.
- 22:26 DECIDED (his words "For the runner for now."): PYREFLY (Meta) is the type checker for the desktop runner; ruff for lint/format. Backend stays on mypy + pydantic.mypy for now.
- 22:26 DECIDED (his words): when the code is created, the desktop runner goes under a directory called "runner-py" (repo root of tx-mdm, beside backend/ and frontend/ - placement assumed). Still on no-code hold.
- 22:27 RENAMED (his words "Call it desk runner."): runner directory = "desk-runner" (replaces runner-py), repo root beside backend/ and frontend/.
- 22:28 Folder name NOT final: he is still deciding ("hold on let me think about it"). desk-runner is a placeholder; desk_runner (said by assistant) was never agreed.
- 22:34 FOLDER NAME (his words, voice "Roadrunner dash pie"): runner directory = "roadrunner-py" (heard as roadrunner-py; replaces desk-runner), repo root beside backend/ and frontend/. Spelling read back to him for confirmation.
- 22:34 RULE (his words "No spaces in the folder name."): folder name has no spaces - roadrunner-py (lowercase, one dash) complies.
