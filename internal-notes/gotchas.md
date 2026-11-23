# Gotchas

Each entry: the symptom, why it happens, and what to do.

## 1. Every IDMC call fails with `InvalidURL: Invalid port: ':1]'`

- **Symptom:** the backend returns 500 on every list, run and status call. The tests pass.
- **Why:** `httpx.Client()` reads `HTTP(S)_PROXY` / `NO_PROXY` from the environment by default
  (`trust_env=True`). This VM's `NO_PROXY` contains an IPv6 entry (`::1`), which httpx 0.28
  cannot parse, so building the client raises an error.
- **Fix in code:** `app/dependencies.py::build_http_client` builds the client with
  `trust_env=False` and uses the proxy from `IDMC_PROXY_URL` (empty means direct). With
  `HTTP_TRUST_ENV=true` it tries the env vars. If httpx cannot parse them, it logs a warning
  and falls back to `IDMC_PROXY_URL`. `tests/test_http_client.py` covers this with a bad
  `NO_PROXY`.
- **In tests:** the respx fixtures in `tests/conftest.py` build `httpx.Client(trust_env=False)`
  for the same reason.
- **If a corporate proxy is needed:** set `IDMC_PROXY_URL`. Do not switch `HTTP_TRUST_ENV` on
  just to make the proxy work.

## 2. Vite listens on `[::1]`, not `127.0.0.1`

`npm run dev` binds to `localhost`, which on this VM resolves to IPv6 `::1`. So
`curl http://127.0.0.1:5173` fails while `http://localhost:5173` works. Use `localhost`, or
start Vite with `--host 127.0.0.1`. The Vite proxy targets the backend at `127.0.0.1:8000`,
so start uvicorn on `127.0.0.1` (its default).

## 3. Two start times on the results screen

- `started_at` = when **this backend** submitted the run. It is always set, and the UI labels
  it "Requested".
- `idmc_started_at` = the start time **IDMC** reports: B360 `_meta.startedAt` for MDM, and
  activity monitor / activity log `startTimeUtc` for CDI. The UI labels it "Started in IDMC" and
  shows "not reported yet" until IDMC reports it.
- The backend never overwrites `started_at` with the IDMC time. An earlier build did, and the
  fake returned a date a year old.
- CDI `startTime`/`endTime` without `Utc` are US Eastern Time. Always use the `*Utc` fields.

## 4. MDM jobs listed but "not runnable"

The `MDM_JOB_DEFINITION` objects list carries no internal `jobDefinitionId` and no job type.
`app/mdm/resolver.py` fills them in by matching names against recent job instances from the B360
job search. A definition that has never run cannot be resolved this way. **This is expected, not
a bug.** Swap the resolver once the real id source is confirmed (see `api-facts.md`).

## 5. Run state lives in memory

`RunRegistry` is in memory. Restarting the backend forgets the runs, so a deep link like
`/mdm/runs/<key>` then returns 404, and the UI stops polling on a 404. The jobs themselves keep
running in IDMC.

## 6. Do not call the real org from an agent session without credentials and a go-ahead

There is no live IDMC access in CI or in agent sandboxes. Use `backend/dev/fake_idmc.py`. Live
verification against Vamsi's org is a separate, explicit step.

## 7. This repo is public

- Never commit a password, a session id, a `.env`, or a screenshot that shows credentials.
- The IDMC username and hostnames are fine to commit.
- Run the secret scan in `run-and-test.md` before every push.

## ASCII only (Vamsi, 2026-11-22)

ASCII only in code, logs, terminal output and docs - no emoji, icons or special Unicode
(Windows terminals garble them). Use `->`, `-`, `...`, `OK`/`FAIL`, and `+--`/`|` for tree
diagrams. `backend/tests/test_ascii_only.py` fails the build if a tracked text file breaks
this; `app/main.py` forces stdout/stderr to ASCII with backslash escapes at runtime.

## Monitor tab (2026-11-22)

- activityMonitor `objectName` is the SOURCE object, not the task. Use `taskName` there; in
  activityLog `objectName` is the task name. Getting this wrong makes the "my tasks" filter empty.
- errorMsg on clean runs is "No errors encountered." - treated as no error.
- Advanced taskflows may not appear in the v2 activity calls at all (UNVERIFIED). If the
  Monitor shows only their MTT steps, that is why; the per-run taskflow status call is
  `/active-bpel/services/tf/status/{runId}`.
- Starting tf_MDM_ZLV_TTF_Guest_Basic over the API on 2026-11-22 returned IDMC 403 "User
  VVamsi-idmcdev not authorized to access service ..." - the taskflow needs the user in its
  Start step Allowed Users and must be re-published.

## Taskflow Allowed Users is case-sensitive (verified live 2026-11-22)
- tf_MDM_ZLV_TTF_Guest_Basic returned 403 "not authorized to access service" until
  Allowed Users held the user EXACTLY as IDMC reports it in the error: `VVamsi-idmcdev`
  (not `VVamsi-IDMCDev`, not all lowercase). After unpublish / fix / publish, the
  /active-bpel/rt/{api_name} call was accepted (runId 1309380263289049088) and went RUNNING.
- The service URL API name matched the task name, so the api_name default was correct.

## Taskflow input fields must be sent in the rt call (2026-11-22)
- Run 1309380263289049088 of tf_MDM_ZLV_TTF_Guest_Basic ended SUSPENDED: child
  mt_m_MDM_ZLV_TTF_Guest_Basic failed "[FATAL] Invalid/Default JobInstanceId is passed as
  runtime parameter". The start call had sent an empty JSON body `{}`.
- The taskflow's Start step needs input field `jobInstanceId` (exact case, Vamsi). Send it as
  a top-level JSON key of `POST {pod}/active-bpel/rt/{api_name}`, e.g. `{"jobInstanceId":
  "ABC123"}` (shape per Informatica KB curl example; not yet verified live with this field).
- Backend: `POST /api/cdi/taskflows/{name}/run` body `{"parameters": {"jobInstanceId": ...}}`;
  `POST /api/cdi/runs` takes the same `parameters`. UI prefills jobInstanceId = ABC123.

## Terminating (aborting) a taskflow run (2026-11-22)
- `PUT {pod}/active-bpel/services/tf/terminate`, header INFA-SESSION-ID, body
  `{"runid": ["<run id>", ...]}` (max 200). 204 No Content = accepted; 500 = some id is invalid
  or no longer active. Source: Informatica KB 000216333 (method + path only in its screenshots;
  a community post confirms PUT /active-bpel/services/tf/terminate). Not yet called live.
- Backend: `POST /api/cdi/taskflows/runs/{run_id}/terminate` (optional `{"run_ids": [...]}`).
  IDMC 500 -> our 502 with the text; never retried. UI: "Abort run" while RUNNING, with confirm.

## A person's abort reports FAILED, not STOPPED (seen live 2026-11-22 23:21 CST)
- Do not read "FAILED" on a taskflow as a crash without checking `aborted` (code
  processManuallyTerminated). The child mapping task shows STOPPED "stopped by user ... using the
  API" even when the stop was pressed in the portal Monitor. The reason text arrives in extra quotes.

## MDM vs CDI taskflows: naming rule (Vamsi, 2026-11-23 00:41 CST)

- Business 360 / MDM taskflow: the name starts with `tf_MDM_`, or ends with `_EGR` (egress)
  or `_IGR` (ingress). Case doesn't matter. These need the Start-step input field
  `jobInstanceId` (exact name) with a real value.
- CDI taskflow: everything else, in particular `tf_Ldg_*` and `tf_Stg_*`, even when the name
  contains MDM (e.g. `tf_Stg_MDM_CDI_TTF`). These must NOT get `jobInstanceId`.
- Seen live 2026-11-23 06:39Z: `tf_Stg_MDM_CDI_TTF` started with a pre-filled
  `jobInstanceId` answered `IDMC 400 Validation failed, extra: jobInstanceId`.
- The rule lives in ONE place, `backend/app/cdi/taskflow_kind.py`. `GET /api/cdi/tasks`
  tags every item with `domain` ("mdm" | "cdi"). Only TASKFLOW items are classified; mapping
  tasks and linear taskflows are always "cdi".
- Guard: `POST /api/cdi/taskflows/{name}/run` and `POST /api/cdi/runs` answer 400 without
  calling IDMC when an mdm taskflow lacks `jobInstanceId`, or a cdi taskflow carries it.

## Typed models end to end (standing rule, Vamsi 2026-11-23 00:49 CST)
- Every API path is strongly typed, never "stringy" dict/Any. Backend: Pydantic v2 models,
  every route has response_model so Swagger (/docs) shows the full schema. IDMC JSON is parsed
  into models ONCE at the client boundary (e.g. app/b360data/wire.py); past it, no raw dict
  access. Field values use a typed union driven by the declared data type.
- Frontend: TypeScript types for the same models, generated from the backend OpenAPI schema
  (`npm run gen:types` -> frontend/src/b360/api-types.ts) and committed. backend/tests/
  test_b360_types.py fails when the committed file drifts. No `any`.
- openapi-typescript does not install next to TypeScript 7 (npm ERESOLVE peer range), so the
  generator is a small script: backend/dev/gen_ts_types.py. Older modules (cdi, mdm, taskflows)
  still have hand-written TS types; move them under the generator when they are next touched.

## MDM child mapping tasks never run on their own (0.9.6)

- mt_m_MDM_* / *_EGR / *_IGR mapping tasks read the jobInstanceId their taskflow passes. Started
  alone they get the default value and fail ("[FATAL] Invalid/Default JobInstanceId", seen live
  2026-11-22). So they are visible only (Business 360 Taskflows, "Child mapping tasks") and the
  backend refuses a direct start with 400. Start the taskflow instead.
- Parent link in the UI is a name guess (tf_X -> mt_m_X); with no match it just says "runs via
  its taskflow".

## B360 entities TOML (0.9.7)
- Edits to `backend/b360_entities.toml` do nothing until the backend restarts (read once, cached).
- File must be plain ASCII; a typo in `name` does not crash - the left pane shows
  "not found in org" (`found: false` in `GET /api/b360/entities`).
- The left pane loads the focus list once per page load; reload the browser after a restart.


## B360 Add records (0.9.8)

- Source system ids are CASE-SENSITIVE: `zlv_ttf`, not `ZLV_TTF` (Vamsi's correction 2026-11-23 01:10 CST).
  The backend compares exactly; anything not in `[sources] allowed` is a 400 and nothing is sent.
- The TOML is never written from code; edit it and restart the backend.
- Validation happens for the WHOLE request before the first call: one bad row -> 422, zero records sent.
- A network error mid-send marks that row UNKNOWN and stops: it may exist in B360. Check the Records tab
  before sending again (a repeat would create a second record with a new sourcePKey).
- `ffr_` = FREEFORM REASON (Vamsi 2026-11-23 02:01 CST): free text for when validation of the field fails.
  Since 0.9.11 the generator leaves every ffr_* empty (0.9.8-0.9.10 wrongly copied a lower-cased name in).
  `clns_` = upper-case letters and digits of the row's own value. Both in `app/b360data/testdata.py`.
- `pip install -e ".[dev]"` again after pulling 0.9.8: `faker` is a new dependency.

## B360 lastUpdateDate types (0.9.9)

`_meta.lastUpdateDate` is an epoch-ms STRING in search results but an epoch NUMBER in Read Master Record.
`wire._epoch_or_iso` takes both (and ISO text). The filter fieldName prefix for custom entities is not
documented beyond `c360person.firstName`; the backend reuses the prefix the last search reply used.

## 0.9.11.1 (2026-11-23): Generate test data returned a bare HTTP 500
- Live cause: on his org x_phone.ph_typ is a REQUIRED picklist, and no documented call lists
  its values. The generator leaves picklists empty (never invents codes), then its own Pydantic
  check rejected the row, and that RecordInvalidError was not caught -> "Internal Server Error".
- Fix: a group whose required picklist has no known codes is generated with zero rows (rule text
  says "group skipped ... add rows by hand"); a required ROOT picklist with no codes -> 422 with a
  plain message. Generate also maps RecordInvalidError to 422.
- Catch-all handler in app/main.py: any unhandled error returns JSON detail
  "Backend error on <METHOD> <path>: <Type>: <message>" (UI already shows detail inline);
  the traceback still prints in the backend window. Never a bare 500 again.

## Lengths (0.9.12.2, 2026-11-23 02:40 CST)
- x_phone.cntry_cd and x_phone.ph_num are INTEGER fields in his zlv_guest metadata, so a leading
  zero can never survive (country code 044, a phone starting 0). The bound is in DIGITS: cntry_cd
  <= 999, ph_num exactly 10 digits (1000000000-9999999999). If leading zeros matter, change the
  fields to text in the B360 portal; then the same config counts characters.
- A lookup code's length (ph_typ) is not configured: declared length of the rdm entity's Code field
  if its metadata has one, else the longest live Code ("Contaminated" = 12 on his org, 02:27 CST).

## No regex, no string parsing (0.9.13, 2026-11-23 02:35 CST standing rule)
- The guard test fails on `import re` / `pattern=r` in backend/app and on RegExp, `.split(`,
  `.match(`, `.replace(/`, `/.test(` in frontend/src (tests and shell/search.ts excepted).
- Need a new name rule? Add a row to a NameRule table in app/common/naming.py (or the table next
  to its use, e.g. TASKFLOW_RULES), do not write startswith chains. Need a new derivation? Add a
  Transform member and its `match` arm.
- Visibility: a TOML line like `x_phone.ph_num` is matched whole against the tree node
  GROUP_FIELD(x_phone, ph_num); a system field whose own name has a dot
  (`_indexValidationError.code`) is therefore no special case.

