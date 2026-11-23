# Spec — shared behaviour (session, run rules, results)

**Version:** 1.0.0 (2026-11-22) · **State:** Reconciled. The code exists and this spec was
written alongside it. It is not yet authoritative against the live org.

## Why

Vamsi wants to run and watch IDMC jobs through the APIs instead of the console, with one
consistent results view, and with no risk of double-starting or silently retrying a job.

## Requirements

**FR-S01 Credentials stay server-side.** `CODE`
- Given the backend is configured with `IDMC_USERNAME` / `IDMC_PASSWORD`,
- when any page or API response is produced,
- then neither the password nor a session id appears in it, in the logs, or in an error message.

**FR-S02 Separate sessions.** `CODE`
- Given CDI and MDM calls are made,
- then each service uses its own v3 login session.
- When one session expires, the other is unaffected.

**FR-S03 Re-login once on 401.** `CODE`
- Given a call returns 401,
- when the backend logs in again and resends that request once,
- and it fails again,
- then the error is returned. There is no loop.

**FR-S04 429 is a hard stop.** `CODE`
- Given IDMC returns 429 on a list or status call, then the API returns 429 with a readable
  message and does not retry.
- Given IDMC returns 429 on a start call, then the run is recorded FAILED with the rate-limit
  message and is not retried.

**FR-S05 One active run per job.** `CODE`
- Given job J has a run that is not in a final state,
- when a second start for J arrives,
- then the API returns 409 and nothing is sent to IDMC.

**FR-S06 Never auto-retry.** `CODE`
- Given a start or a run fails,
- then the run stays FAILED.
- Only a person (or an agent with a person's confirmation) can start a new run.

**FR-S07 Run statuses.** `CODE`
- A run is QUEUED → RUNNING → one of SUCCESS / WARNING / FAILED / STOPPED (the final states),
  or UNKNOWN when the IDMC state cannot be mapped.
- Polling stops at a final state.

**FR-S08 Results screen.** `CODE`
- Given a run, the screen shows:
  - the job name at the top
  - the status
  - **Requested** (`started_at`, when this backend submitted the run)
  - **Started in IDMC** (`idmc_started_at`, or "not reported yet")
  - the end time
  - a short log
  - counts on one side and errors on the other

**FR-S09 Outbound proxy policy.** `CODE`
- Given the process environment has proxy variables that httpx cannot parse,
- when the backend starts,
- then IDMC calls still work. They use `IDMC_PROXY_URL`, or a direct connection.
- Env-var proxies are used only with `HTTP_TRUST_ENV=true`.

## Out of scope

- Persisting runs across backend restarts.
- Stopping a running job.
- Scheduling.
- Multi-user access control.

## Success criteria

- SC-S01: `pytest -q` passes, including the tests for registry, 401/429 handling and the HTTP
  client.
- SC-S02: in the offline end-to-end check (fake IDMC), starting the same job twice gives 409
  the second time.
