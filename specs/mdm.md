# Spec — MDM (Business 360)

**Version:** 1.0.0 (2026-11-22) · **State:** Reconciled. Status: CODE. The id resolution is
UNVERIFIED.

## Why

Vamsi wants to run Business 360 ingress, egress and match-merge jobs and see their counts and
errors, without the console.

## Requirements

**FR-M01 Job definition list from metadata.** `CODE`
- Given a valid session, when `GET /api/mdm/jobs` is called, then the backend queries
  `{baseApiUrl}/public/core/v3/objects?q=type=='MDM_JOB_DEFINITION'`.
- Each result is an `MdmJob` with `asset_id`, name and path.

**FR-M02 Resolve the internal id and kind (pluggable, UNVERIFIED).** `CODE`
- Given the metadata has no `jobDefinitionId` and no job type,
- then `JobDefinitionResolver` fills them in.
- The current `JobSearchResolver`:
  - matches normalised definition names against recent B360 job search results
    (`jobDefinition.id`, `jobType`)
  - skips `internal.c360.ingress.fileImportJob` and training jobs
  - recognises egress by the substring "egress", never by a hard-coded type
  - caches results for `MDM_RESOLVER_CACHE_SECONDS`
- An unresolved job is listed with `runnable=false` and a note.

**FR-M03 Run.** `CODE`
- Given a runnable job, when `POST /api/mdm/runs {asset_id}` is called, then the backend sends
  `POST {mdm}/job/public/api/v1/jobInstance/{Ingress|Egress|MatchMerge} {jobDefinitionId}`
  once and returns a QUEUED run.
- Given the job is not runnable, the API returns 400.
- Given the job is unknown, the API returns 400 (LookupError).

**FR-M04 Monitor.** `CODE`
- Given a run, when `GET /api/mdm/runs/{run_key}` is called, then the backend reads
  `jobInstance/{id}?details=true`:
  - `_meta.state` maps to the run status.
  - `jobLevelMetrics` supplies the counts.
  - Any `errorMessage`-style fields supply the errors.
  - `_meta.startedAt` supplies `idmc_started_at`. It never overwrites `started_at`.

## Out of scope

- Editing job definitions.
- Ingress file upload.
- Purge.
- Delete/restore of records.

## Open (needs a live probe)

- The authoritative source of `jobDefinitionId` and job type: job search, the export package,
  or FRS documents.
- The egress `jobType` string.
- The exact error payload fields.

## Success criteria

- SC-M01: the MDM tests in `backend/tests/` pass.
- SC-M02 (LIVE, pending): every job definition Vamsi names as in use resolves, with 0 wrong
  mappings.
