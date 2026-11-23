# Spec - MDM (Business 360 jobs)

**As of:** 0.9.11 (2026-11-23). Replaces 1.0.0 (2026-11-22). B360 records: see `b360-data.md`.

## Why

Run Business 360 ingress / egress jobs and the MDM taskflows that wrap them, see every B360 job
running in the org whoever started it, and look up any job instance by id.

## Requirements

- **M01** Job list from metadata: `GET /api/mdm/jobs` (v3 objects `MDM_JOB_DEFINITION`); internal
  jobDefinitionId + kind resolved from job search; unresolved jobs listed `runnable=false` with a
  note. `CODE` / `LIVE` (4 jobs: 2 Job Recovery not runnable, ingress + egress runnable)
- **M02** Business 360 notebook sections: All jobs, Ingress jobs, Egress jobs, Taskflows
  (jobInstanceId), Currently running, Runs. `CODE`
- **M03** Run: `POST /api/mdm/runs {asset_id}` -> one `POST {mdm}/job/public/api/v1/jobInstance/
  {Ingress|Egress|MatchMerge} {jobDefinitionId}`; not runnable -> 400; already running -> 409. `CODE` / `LIVE` (egress)
- **M04** Refresh: `GET /api/mdm/runs/{run_key}` reads `jobInstance/{id}?details=true` (state, counts,
  errors, `idmc_started_at`). `GET /api/mdm/runs` lists runs started here. `CODE` / `LIVE`
- **M05** Currently running: `GET /api/mdm/monitor?row_limit=25` - every RUNNING/QUEUED job whose type
  starts `b360.` or `c360.`, whoever started it (portal, app, other user), plus recently finished;
  other types counted, not listed. Tabs Everything / Running now / Recently finished / Look up id;
  elapsed ticks each second; 15 s refresh. Read-only. `CODE`
- **M06** Look up any instance: `GET /api/mdm/job-instances/{instance_id}` (spaces, quotes, trailing dot
  trimmed; unknown -> 404). Read-only. `CODE`
- **M07** MDM taskflows (`tf_MDM_*`, `*_EGR`, `*_IGR`) live here, section "Taskflows (jobInstanceId)"
  (`/mdm/taskflows`, run deep link `/mdm/taskflows/runs/:id`): same Run / Summary / Session log tabs,
  history, Clear and Abort as cdi.md C08-C14, served by the same `/api/cdi/taskflows/...` routes. `CODE` / `LIVE`
- **M08** jobInstanceId field starts EMPTY (no placeholder); Run is disabled until a value is typed;
  backend enforces it (cdi.md C06). `CODE`
- **M09** MDM child mapping tasks (`mt_m_MDM_*`) shown read-only under the run box with "runs via its
  taskflow"; never startable alone. `CODE`

## Out of scope

Editing job definitions; ingress file upload; purge; match-merge model choice in the UI.

## Known gaps / UNVERIFIED

- Monitor status-filter spelling, sort order of the unfiltered page, and whether the search is
  org-wide or own-jobs only: UNVERIFIED (portal job 1309395637279657984 is the live test case).
- A fully successful MDM taskflow run needs a REAL jobInstanceId from Vamsi; ABC123 got past the
  parameter error but wrote 0 rows (LIVE, 2026-11-22).
- Both ZLV taskflows need `VVamsi-idmcdev` (exact case) in Allowed Users, else 403 (LIVE).
- Oracle-bound mappings fail with socket-closed errors when his laptop is off the VPN (LIVE, his diagnosis).
