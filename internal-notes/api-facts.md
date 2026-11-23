# Informatica API facts - verified vs. not

Labels:

- **DOC** - stated in an official Informatica document. The research notes in
  `internal-docs/` give page references.
- **CODE** - exercised by this repo's tests, but only against mocks or `fake_idmc`.
- **LIVE** - seen working against Vamsi's real org.

**As of 2026-11-22, nothing is LIVE.** No code in this repo has called the real org.

## Login and session

| Fact | Status |
|---|---|
| `POST https://dm1-us.informaticacloud.com/saas/public/core/v3/login`, body `{username, password}` | DOC |
| The response carries `userInfo.sessionId` and `products[0].baseApiUrl` | DOC |
| v3 calls send `INFA-SESSION-ID`; v2 calls send `icSessionId`; B360 calls send `IDS-SESSION-ID` | DOC (B360 header also seen in Vamsi's own .http file) |
| One v3 session id works for both the v2 and v3 platform calls | DOC |
| Sessions expire after 30 min idle; the backend re-logs in once on a 401 | DOC / CODE |
| The org may use JWT auth instead of session ids (an option since 2025-11) | UNVERIFIED for this org |
| `baseApiUrl` also serves the v2 `/api/v2/job` and activity calls | UNVERIFIED |

## CDI

| Fact | Status |
|---|---|
| Picker: `GET {baseApiUrl}/public/core/v3/objects?q=type=='MTT'` (also WORKFLOW, TASKFLOW), `limit` up to 200, `skip` offset | DOC / CODE |
| The v3 `id` is the `taskFederatedId` for the job call | DOC |
| Run: `POST {baseApiUrl}/api/v2/job {taskFederatedId, taskType}`; type list DMASK/DRS/DSS/MTT/PCS/WORKFLOW | DOC / CODE |
| Advanced taskflows are not run by `/api/v2/job`; use the published `POST {pod}/active-bpel/rt/{apiName}` | DOC / CODE |
| `INFA-SESSION-ID` accepted on the `/active-bpel/rt/` run call | UNVERIFIED (documented only for the status call) |
| Run-id field name in the `/active-bpel/rt/` response | UNVERIFIED |
| Published API name = task name | UNVERIFIED (the UI lets you type a different one) |
| Monitor: `activityMonitor` lists all running jobs with no filter (match on runId + taskId); then `activityLog`, where state 1 = success, 2 = warning, 3 = failed | DOC / CODE |
| Taskflow status: `GET {pod}/active-bpel/services/tf/status/{runId}` | DOC / CODE |
| `startTime`/`endTime` are US Eastern Time; the `*Utc` fields are UTC | DOC |
| Rate limits for these platform calls | Not documented. The backend treats a 429 as a hard stop anyway |

## MDM (Business 360)

| Fact | Status |
|---|---|
| List: `GET {baseApiUrl}/public/core/v3/objects?q=type=='MDM_JOB_DEFINITION'` | DOC / CODE |
| That list has **no** internal `jobDefinitionId` and **no** job type | DOC (by absence) |
| Run: `POST {mdm}/job/public/api/v1/jobInstance/{Ingress\|Egress\|MatchMerge} {jobDefinitionId}` | DOC (Postman collection + PDF) / CODE |
| Status: `GET {mdm}/job/public/api/v1/jobInstance/{id}?details=true`, `_meta.state`, `jobLevelMetrics` | DOC / CODE |
| Job search returns `jobDefinition.id` + `jobType`, used by the resolver | DOC for the call; using it to map definitions to ids is UNVERIFIED |
| `internal.c360.ingress.fileImportJob` is an internal job type, so the resolver skips it | DOC (seen in the collection) |
| Egress `jobType` string | UNVERIFIED. Recognised by the substring "egress" and never hard-coded |
| Search Job Instances body: `search`, `pageSize`, `pageOffset`, `filters{operator, filter[{fieldName, fieldValue}]}`, fieldName `name`/`status`/`jobType` | DOC (PDF pp. 130-132) / CODE (0.9.0) |
| Search response: `totalRecords`, `totalPages`, `currentPage`, `jobInstances[]` each with `id`, `name`, `jobType`, `jobDefinition.id`, `_meta{state, startedAt, startedBy, completedAt, isCompleted}` (epoch ms) | DOC (PDF example pp. 132-134) / CODE |
| Status filter value spelling (we send `RUNNING`, `QUEUED`) | UNVERIFIED. Running jobs found in the unfiltered page are merged in too |
| Sort order of an unfiltered search | UNVERIFIED. Backend sorts by `startedAt`, newest first |
| Search is org-wide (all users), not only the caller's jobs | UNVERIFIED (PDF says you can search by the user who started it, which suggests org-wide) |
| Job types seen live: `b360.ingress.load` (portal ingress 1309395637279657984, 2026-11-22 23:50:47 CST), `c360.egress.etl` (app egress 1309392734552862720, 23:39 CST) | LIVE (portal screen read by Vamsi + backend run list) |
| Field names in the `details=true` error payload | UNVERIFIED. Errors are collected from any `errorMessage`-style field |

## How to promote a fact to LIVE

Do it only with Vamsi's go-ahead and his credentials in `backend/.env`:

1. Run the one read-only call that proves the fact (for example, the MDM job list, or a job
   search).
2. Record the date, the call and the response shape, with ids redacted, in this file.
3. If the fact changes behaviour, write a change proposal under `changes/`.

## Taskflow terminate (2026-11-22)
- DOC (KB 000216333): body {"runid": [...]}, INFA-SESSION-ID or Basic auth, 204 success, max 200
  ids, 500 if any id is invalid. https://knowledge.informatica.com/s/article/000216333?language=en_US
- COMMUNITY: method/path PUT /active-bpel/services/tf/terminate (pod host, same as tf status).
- VERIFIED live 2026-11-22 23:21 CST: a terminated run shows FAILED + code processManuallyTerminated (see below).

## Abort seen live (2026-11-22 23:21 CST, run 1309386379683184640, stopped from the portal Monitor)
- Taskflow status after the terminate: `FAILED` (final), NOT STOPPED or SUSPENDED. errorMessage is a
  JSON string: reason `"Manual Process Termination"` (wrapped in its own extra quotes), code
  `processManuallyTerminated`.
- Child MTT mt_m_MDM_ZLV_TTF_Guest_Basic: `STOPPED`, error "The job was stopped by user
  vvamsi-idmcdev using the API." Rows: source_success 20, target_success 0 (7.6 min).
- Since 0.8.0 the backend sets `aborted: true` on that code and strips the extra quotes; the UI
  shows "ABORTED (IDMC: FAILED)" in grey. An ordinary failure keeps `aborted: false`.
