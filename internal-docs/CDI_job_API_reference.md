# CDI job API reference: run and monitor IDMC Data Integration jobs

Research date: 2026-11-22. Read-only research from public docs. No calls were made to Vamsi's org.

**Primary source (S1):** IICS REST API Reference, November 2025 edition (published 2025-12-12). This is the newest full edition I could read; newer editions may exist.
https://docs.informatica.com/content/dam/source/GUID-B/GUID-BA8ED0B4-AB32-46B1-A7B8-358FAB844D6B/64/en/IICS_November2025_(REST-API)Reference_en.pdf
Page numbers below are the PDF's own page numbers.

Other sources:
- S2: developer.informatica.com, "Monitoring taskflow status with the status resource": https://developer.informatica.com/tpn/v2.0/reference/monitoring-taskflow-status-with-the-status-resource
- S3: Informatica KB 000198448, taskflow status auth: https://knowledge.informatica.com/s/article/000198448?language=en_US
- S4: community, "How to Run Taskflow as an API in IDMC?": https://network.informatica.com/community/s/question/0D56S0000EMXiEPSQ1/how-to-run-taskflow-as-an-api-in-idmc
- S5: developer.informatica.com, "REST API versions": https://developer.informatica.com/tpn/v4/reference/rest-api-versions-1

Legend: **[VERIFIED]** means stated in an official doc I read. **[INFERRED]** is my reasoning from the docs. **[UNVERIFIED]** means not confirmed and needs a live test.

---

## 0. TL;DR for the UI ("pick from a list, then run")

1. Log in with **v3** and keep both values it returns: the `sessionId` and the `baseApiUrl` from the `products[]` array. You only need the v2 `serverUrl` if you use the v2 login.
2. To build the picker, call `GET {baseApiUrl}/public/core/v3/objects?q=type=='MTT'` (and the same with `'TASKFLOW'`, `'WORKFLOW'`, `'PROJECT'` and `'FOLDER'` for the tree). Page with `limit` (200 max) and `skip`.
3. Each item's **`id` is the `taskFederatedId`** that the run call needs. Its `path` is a folder path you can show in the UI.
4. Run mapping tasks (MTT) and linear taskflows (WORKFLOW) with `POST {serverUrl}/api/v2/job` and `{ "taskFederatedId": id, "taskType": "MTT" }`. The response gives you `runId` and the v2 `taskId`.
5. **Advanced taskflows (type TASKFLOW) don't run through `/api/v2/job`.** They have to be published as a service and are started at `<pod>/active-bpel/rt/<API_name>`. You check their status at `<pod>/active-bpel/services/tf/status/<runId>`.
6. While a job runs, check `GET {serverUrl}/api/v2/activity/activityMonitor?details=true` (states: QUEUED, INITIALIZED, RUNNING, STOPPING). When it finishes, read `GET {serverUrl}/api/v2/activity/activityLog?runId=<runId>&taskId=<taskId>` (`state` 1 = success, 2 = completed with errors, 3 = failed). That log also has row counts and `errorMsg`.

---

## 1. Login and session headers

### v3 login (recommended)
- `POST https://dm1-us.informaticacloud.com/saas/public/core/v3/login` **[VERIFIED S1 p.168]**. The POD table maps USW1-1 and USW3-1 to `dm1-us`. Vamsi's portal lands on `usw1.dm1-us...`, which fits a USW1-1 POD **[INFERRED]**.
- Headers: `Content-Type: application/json`, `Accept: application/json`. Do **not** send a session header on login **[VERIFIED S1 p.24]**.
- Body: `{ "username": "...", "password": "..." }`
- Response **[VERIFIED S1 p.169-170]**:
```json
{ "products": [ { "name": "Integration Cloud", "baseApiUrl": "https://usw3.dm-us.informaticacloud.com/saas" } ],
  "userInfo": { "id": "...", "name": "user", "parentOrgId": "...", "orgId": "...", "orgName": "MyOrg_INFA", "groups": {}, "status": "Active", "sessionId": "<sessionId>" } }
```
  `sessionId` is inside `userInfo`. `baseApiUrl` is inside each `products[]` entry.
- Logout: `POST https://dm1-us.informaticacloud.com/saas/public/core/v3/logout` with `INFA-SESSION-ID` **[VERIFIED S1 p.170]**.

### v2 login
- `POST https://dm1-us.informaticacloud.com/ma/api/v2/user/login`. Same body. It returns a `user` object with `icSessionId` and `serverUrl` (for example `https://usw3.dm-us.informaticacloud.com/saas`) **[VERIFIED S1 p.53-56]**.

### Which header goes with which call **[VERIFIED S1 p.21-22]**
| Call family | Header | Base URL |
|---|---|---|
| v2 (`/api/v2/...`: job, activityLog, activityMonitor, task, mttask) | `icSessionId: <id>` | `serverUrl` (v2 login) |
| v3 (`/public/core/v3/...`: objects, lookup) | `INFA-SESSION-ID: <id>` | `baseApiUrl` (v3 login) |
| Other services (for example the B360 `/job/public/api/v1/...` calls in his Postman collection) | `IDS-SESSION-ID: <id>` | service URL |

- **One session ID works for v2 and v3 alike** **[VERIFIED S5, "You can use the same session ID for version 2 and version 3 resources"]**. So a single v3 login can drive the v2 job, activityLog and activityMonitor calls. Send the `sessionId` as `icSessionId` on those.
- **Base URL for v2 calls after a v3 login:** use `baseApiUrl`. It has the same `https://<pod>.<region>.informaticacloud.com/saas` shape as `serverUrl` in every doc example **[INFERRED from S1 p.170 and p.54 examples; confirm in the first live test]**.
- Session lifetime: 30 minutes of inactivity, plus up to about 2 minutes of grace **[VERIFIED S1 p.21]**. Since 2025-11-03 an org admin can switch the org to **JWT** auth. The `sessionId` value is then a JWT, and the client must re-authenticate before it expires **[VERIFIED S1 p.21-22]**. To be safe, re-login on any `401`.
- Session check (session-ID orgs only): `POST {serverUrl}/api/v2/user/validSessionId` with body `{ "@type":"validatedToken", "userName":"...", "icToken":"<id>" }`. It returns `{ timeUntilExpire, isValidToken }` **[VERIFIED S1 p.22]**.
- Doc inconsistency: the Cloud Data Profiling getting-started PDF says to use IDS-SESSION-ID for v2. The main REST API Reference says icSessionId. Trust the main reference.

---

## 2. Listing runnable assets (the picker), the main focus

### 2a. v3 objects query (best for the picker) **[VERIFIED S1 p.206-210]**
- `GET {baseApiUrl}/public/core/v3/objects?q=<filter>&limit=<n>&skip=<n>`
- Header: `INFA-SESSION-ID`
- Filter fields in `q`:
  - `type` with `==` or `!=`. Data Integration values include `MTT` (mapping task), `DSS`, `DMASK`, `DRS`, `PCS`, `WORKFLOW` (linear taskflow), `TASKFLOW` (advanced taskflow), `DTEMPLATE` (mapping), `PROJECT` and `FOLDER`. MDM SaaS values include `MDM_JOB_DEFINITION`. Types aren't case sensitive.
  - `location` with `==`, for example `location=='Default/Sales'`.
  - `updateTime` with `<`, `<=`, `==`, `=>`, `>` or `!=`.
  - `updatedBy` and `tag`, plus the `sourceControl.*` fields.
  - Combine filters with `and`, for example `q=type=='MTT' and location=='MDM/Loads'`.
- **Paging:** `limit` goes up to 200 and `skip` is an offset. Next page: `?limit=200&skip=200` **[VERIFIED]**. One response holds at most 200 assets. The `count` can be imprecise for up to 90 seconds when there are more than 1000 objects, and it may not be the first field in the response **[VERIFIED p.209]**. So page until a page comes back with fewer than `limit` items, rather than trusting `count` **[INFERRED]**.
- The results leave out assets the user can't read **[VERIFIED]**.
- Response:
```json
{ "count": 4,
  "objects": [ { "id": "1a3TnUrT2cfiwQGtkWQEUy", "path": "P1/F1", "type": "Folder", "description": "",
                 "updatedBy": "...", "updateTime": "2018-12-17T00:29:29Z", "tags": [], "sourceControl": {...} },
               { "id": "0dGB1jBDWcuhrTxG9Gy1Kh", "path": "P1/Mapping1", "type": "DTEMPLATE", ... } ] }
```
- **IDs:** `id` is the global (FRS) ID. The doc says to use it as `taskFederatedId` in the job request **[VERIFIED p.209]**. `path` gives you project, folder and name. The display name is the last segment of `path` **[INFERRED]**.
- The `q` value has spaces, quotes and `==`, so URL-encode it **[INFERRED]**.
- Suggested picker calls:
  - Mapping tasks: `q=type=='MTT'`
  - Linear taskflows: `q=type=='WORKFLOW'`
  - Advanced taskflows: `q=type=='TASKFLOW'`. These run differently, see §3b.
  - Tree: `q=type=='PROJECT'`, then `q=type=='FOLDER'`. Or list by `location=='<Project>'` and group by `path`.

### 2b. v3 lookup (resolve one path or ID) **[VERIFIED S1 p.171-174]**
- `POST {baseApiUrl}/public/core/v3/lookup` with header `INFA-SESSION-ID`
- Body: `{ "objects": [ { "path": "MyProject/MyFolder/mt_Load", "type": "MTT" }, { "id": "<frsId>" } ] }`. Each entry needs either `id`, or `path` plus `type`.
- Response: `{ "objects": [ { "id", "path", "type", "description", "updatedBy", "updateTime" } ] }`. The **`id` is the `taskFederatedId`** for a job request **[VERIFIED p.171, p.173]**.
- Use it when the UI or config stores a path instead of an ID. It can resolve several objects in one call.

### 2c. v2 task list (legacy; limited) **[VERIFIED S1 p.105]**
- `GET {serverUrl}/api/v2/task?type=MTT` with header `icSessionId`. Valid types: DMASK, DRS, DSS, MTT, PCS. **There's no WORKFLOW or TASKFLOW type here.**
- Response: an array of `{ id, orgId, name, description, createTime, updateTime, createdBy, updatedBy }`. **No folder path.**
- **No paging parameters are documented** **[VERIFIED: none listed]**.
- **Official warning:** "Do not use this resource to obtain a task ID to run a job. Instead, use the lookup resource." The `id` it returns (the short v2 ID) only works as `taskId` for tasks in the **Default** folder **[VERIFIED p.105]**.
- Verdict: don't use it for the picker. Use 2a.

### 2d. v2 mttask (detail only, not a list) **[VERIFIED S1 p.442]**
- `GET {serverUrl}/api/v2/mttask/<id>`, or `/api/v2/mttask/frs/<federatedId>`, or `/api/v2/mttask/name/<name>`. Encode spaces in names as `%20`.
- It **returns one task, not a list.** No list form is documented.
- Useful for a details panel after the user picks a task. It includes `parameters[]` (name, type, value, source and target connection, and object names), `runtimeEnvironmentId`, `agentId` and the notification emails.

### 2e. Taskflow list
- There's no separate taskflow-list endpoint in S1. Use the v3 objects query with `type=='TASKFLOW'` (advanced) or `type=='WORKFLOW'` (linear) **[VERIFIED: both are listed objects types, p.207]**.
- A taskflow can only be run by API if it's **published** and has Allowed Users or Allowed Groups set **[VERIFIED S4]**. The objects query does **not** say whether a taskflow is published **[UNVERIFIED; no field documented]**. The UI may need to handle a "not published" error.

### ID cheat-sheet
| Source | Field | Use in `POST /api/v2/job` as | Works outside Default folder? |
|---|---|---|---|
| v3 objects / v3 lookup | `id` (FRS, 22 chars) | `taskFederatedId` | Yes **[VERIFIED]** |
| v2 task list / mttask | `id` (short v2 ID) | `taskId` | No, Default folder only **[VERIFIED]** |
| Any | name | `taskName` | Yes only if the name is unique **[UNVERIFIED]** |
| Job response | `taskId` | use it for the `activityLog?taskId=` and `stop` calls | **[INFERRED]** |

---

## 3. Starting a job

### 3a. `POST {serverUrl}/api/v2/job` **[VERIFIED S1 p.49-50]**
- Headers: `Content-Type: application/json`, `Accept: application/json`, `icSessionId`
- Body fields:
  - `taskFederatedId`: needed when the task isn't in the Default folder.
  - Or `taskId`, or `taskName`.
  - `taskType` (**required**): `MTT` (mapping task), `DSS`, `DMASK`, `DRS`, `PCS` or `WORKFLOW` (linear taskflow). Doc examples also write `"Workflow"`.
  - `callbackURL` (optional): a public URL that receives the job status.
  - `runtime` (optional): `{ "@type": "mtTaskRuntime", "parameterFileName": "...", "parameterFileDir": "..." }`. With `runtime` included, the same task can run at the same time in other runtime environments.
- Example:
```json
POST {serverUrl}/api/v2/job
{ "@type": "job", "taskFederatedId": "<id from objects>", "taskType": "MTT" }
```
- Response: `{ "@type":"job", "taskId":"0116Q70Z0000000000N4", "taskType":"MTT", "runId":59, "taskName":"mct_...", "runInParallel":false }`. Keep `taskId` and `runId`.
- Callback payload: `{ "@type":"callbackUrlResponse", "endTime", "objectId", "objectName", "runId", "status":"COMPLETED"|"FAILED" }` **[VERIFIED S1 p.48-49]**. A browser-only UI can't receive callbacks, so poll instead.
- Mappings themselves can't run directly. A mapping has to be wrapped in a mapping task (MTT) **[community; consistent with S1 type list]**.
- Runtime parameter overrides: only a parameter file name and directory, through `runtime` **[VERIFIED]**. You can't pass arbitrary values.

### 3b. Advanced taskflows (TASKFLOW)
- **Not covered by `/api/v2/job`**, whose type list is only DMASK, DRS, DSS, MTT, PCS and WORKFLOW **[VERIFIED p.49]**.
- Publish the taskflow, then copy its Service URL `<IICS URL>/active-bpel/rt/<API_name>` from Actions > Properties Detail **[VERIFIED S4; Informatica community page]**. It also has a Swagger file with the method and inputs. Calling it returns the taskflow **run ID**.
- Auth for `/active-bpel/...` calls: basic auth, or the `INFA-SESSION-ID` header from the v3 login **[VERIFIED S2, S3]**.
- The host is the pod host **without** `/saas` **[INFERRED from S3's example `https://apse1.dm-ap.informaticacloud.com/active-bpel/...`]**.
- **[UNVERIFIED]** I didn't confirm whether `INFA-SESSION-ID` is accepted on the `/active-bpel/rt/` *run* call. The docs I read only confirm it for the status call.

---

## 4. Checking status

### 4a. Running jobs: activityMonitor **[VERIFIED S1 p.37-39]**
- `GET {serverUrl}/api/v2/activity/activityMonitor?details=true|false` with header `icSessionId`
- Returns `activityMonitorEntry[]` with: `id`, `type` (MTT, WORKFLOW, MAPPING, MTT_TEST and others), `taskId`, `taskName`, `objectName`, `runId`, `startTime`/`endTime` (ET), `startTimeUtc`/`endTimeUtc`, `executionState`, success and failed source and target row counts, `errorMsg`, `entries` (children when `details=true`), `agentId`, `runtimeEnvironmentId`, `startedBy`, `runContextType` (UI, SCHEDULER, REST-API), `scheduleName` and `callbackURL`.
- **`executionState` values:** QUEUED, INITIALIZED, RUNNING, STOPPING, and FAILED (FAILED only for linear-taskflow subtasks). The doc's XML sample also shows `COMPLETE`.
- It lists **all** running jobs, with no filter, so match on `runId` plus `taskId` in the client **[VERIFIED: no filter params documented]**.

### 4b. Completed jobs: activityLog **[VERIFIED S1 p.27-36]**
- `GET {serverUrl}/api/v2/activity/activityLog?runId=<runId>&taskId=<taskId>`. **`taskId` is required whenever `runId` is sent.**
- Other forms: `/activityLog/<id>`, `?taskId=`, `?offset=&rowLimit=`. `rowLimit` goes up to 1000 and defaults to 200.
- Session log: `/api/v2/activity/activityLog/<id>/sessionLog`
- Entry fields: `id`, `type`, `objectId` (task ID), `objectName`, `runId`, `startTime`/`endTime` (ET), `startTimeUtc`/`endTimeUtc`, **`state`**, `failedSourceRows`, `successSourceRows`, `failedTargetRows`, `successTargetRows`, `totalSuccessRows`, `totalFailedRows`, `errorMsg`, `startedBy`, `runContextType`, `isStopped`, `entries` (children), `scheduleName`. With `/<id>` you also get `logFilename`, `errorFilename`, `errorFileDir` and `items[]`.
- **`state` values:** 1 = completed successfully, 2 = completed with errors, 3 = failed. 4 = not started, which only appears on child entries.
- Suggested polling flow **[INFERRED]**:
  1. After the run call, poll activityMonitor until the `runId` is gone.
  2. Then fetch activityLog by `runId` plus `taskId` to get the final state and row counts.
  3. If activityLog has no row yet, retry after a short wait.

### 4c. Advanced taskflows **[VERIFIED S2]**
- `GET <pod>/active-bpel/services/tf/status/<runId>` with `Accept: application/json` and either `INFA-SESSION-ID` or basic auth.
- Returns `assetName`, `assetType` (TASKFLOW), `duration`, `endTime` (UTC), `errorMessage`, `location`, `runId`, `runtimeEnv`, **`status`** (RUNNING, SUCCESS, FAILED or SUSPENDED), and `tasks[]` with each subtask's `runId`.

### 4d. v3 jobs/monitor
- I couldn't find a `/public/core/v3/jobs` or `.../monitor` endpoint in the November 2025 reference. A search of the PDF for "jobs/monitor" found nothing **[VERIFIED absent from S1]**. Use activityMonitor and activityLog.

---

## 5. Stopping a job **[VERIFIED S1 p.51-52]**
- Stop: `POST {serverUrl}/api/v2/job/stop` with a body in the same shape as the run call: `taskId`, `taskFederatedId` or `taskName`, plus `taskType`.
- Clean stop: `POST {serverUrl}/api/v2/job/stop?cleanStop=true`
- Example: `{ "@type":"job", "taskName":"MappingTask1", "taskType":"MTT" }`. It returns a success object.
- The stop call takes a task, not a run ID **[VERIFIED: no runId field]**. That means it stops that task's running job.

---

## 6. Rate limits and warnings
- **No documented rate limit for the platform v2/v3 job, activityLog and objects calls** in S1 **[UNVERIFIED; not found]**. Published limits belong to other products: CDGC allows 120 calls a minute and 10,000 a day, and API Center's org default is 1,000 calls a minute. Don't assume those numbers apply here.
- Vamsi's B360 PDF (October 2026) warns against sending several job-instance requests in a row. Apply the same caution here: one run per click, then poll at a modest interval of a few seconds, with backoff **[INFERRED]**.
- If a 429 comes back, stop and show it. Don't auto-retry in a loop.
- Other rules **[VERIFIED S1 p.24-25]**:
  - Resources and attributes are case-sensitive.
  - `@type` is optional for v2 JSON and must **not** be used for v3 JSON.
  - Don't log out while requests are still running.
  - Don't put the HTTP version in the URL; Postman adds it.
- Timestamps: `startTime`/`endTime` are **Eastern Time**. Use the `*Utc` fields for display, converted to the user's zone **[VERIFIED]**.
- **CORS [UNVERIFIED, likely blocking]:** a browser-only Vite app calling `informaticacloud.com` directly will probably hit CORS. Plan a small proxy, such as a Vite dev proxy or a thin server, which also keeps the password out of the browser.

---

## 7. Open items to confirm on the first live test (needs Vamsi's go-ahead)
1. The v3 login `products[].baseApiUrl` for his org, and whether v2 `/api/v2/job` works with it plus `icSessionId: <v3 sessionId>`.
2. Whether his org uses session-ID auth or JWT auth.
3. Whether `objects?q=type=='TASKFLOW'` returns his taskflows, and whether those are advanced (TASKFLOW) or linear (WORKFLOW).
4. CORS behaviour from a browser origin.
5. Which CDI tasks he actually wants in the picker, by folder.
