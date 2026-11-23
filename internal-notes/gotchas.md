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
