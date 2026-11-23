# IDMC job-runner UI - API map

Sources: Business 360 REST API Reference (October 2026, published 2026-11-19, 299 pp) and the B360 Postman collection ("Public API POSTMAN ROLLOUT", 50 requests) Vamsi uploaded 2026-11-22. CDI rows come from the IICS platform REST API Reference, which is NOT in either upload.

## 1. Login (shared by everything)
- `POST https://dm1-us.informaticacloud.com/saas/public/core/v3/login` - body `{username, password}`.
- Response: `userInfo.sessionId` and `products[].baseApiUrl` (e.g. `https://usw1.dm1-us.informaticacloud.com/saas`).
- Session expires after 30 min idle (2-min grace). Re-login on 401.
- **Two hosts from one login:**
  - Business 360 (ingress / egress / match-merge): take `baseApiUrl`, drop `/saas`, change `usw1` -> `usw1-mdm` -> `https://usw1-mdm.dm1-us.informaticacloud.com`. Header `IDS-SESSION-ID: <sessionId>` (never `Authorization`). This confirms the `usw1-mdm` base URL in his .http file is right.
  - CDI (Data Integration): uses `baseApiUrl` as-is (`.../saas`) with `/api/v2/...` and header `icSessionId: <sessionId>`.

## 2. Business 360 job API (ref pp. 126-140; collection folder "Job Instance")
| Action | Call | Body |
|---|---|---|
| Run ingress | `POST {mdm}/job/public/api/v1/jobInstance/Ingress` | `{"jobDefinitionId": "<id>"}` |
| Run egress | `POST {mdm}/job/public/api/v1/jobInstance/Egress` | `{"jobDefinitionId": "<id>"}` |
| Run match & merge | `POST {mdm}/job/public/api/v1/jobInstance/MatchMerge` | `jobDefinitionId, matchModelId, matchModelVersion, parameters:[{name:"processType", value:"Match Only"|"Merge Only"|"Match and Merge"|"Reset Matched Records"}]` |
| List / filter runs | `POST {mdm}/job/public/api/v1/search` | `search, pageSize, pageOffset, filters{operator, filter[{fieldName: name|status|jobType, fieldValue}]}` |
| Run summary | `GET {mdm}/job/public/api/v1/jobInstance/{id}` | - |
| Run details (steps) | `GET {mdm}/job/public/api/v1/jobInstance/{id}?details=true` | - |

- Every create call returns `{"id": "<jobInstanceId>"}`; poll summary until `isCompleted`.
- States: RUNNING, SUCCESS, FAILED, STOPPED, WARNING, SKIPPED, QUEUED.
- Results to show: `_meta` (state, startedAt/By, completedAt - epoch ms), `runTimeParameters`, `jobLevelMetrics`, and step list from details.
- Job types seen: `c360.ingress.load`, `c360.be.matchmerge`.
- `jobDefinitionId` = internal job ID shown when the job definition is opened in Business 360 Console. The collection's values (`mdm_ingress`, `egress_person`, `demo_match_merge`) are Informatica samples, not his org's jobs.
- Collection's `X-INFA-PROFILE-REQ: true` header on reads is not documented in the reference; keep it optional.

## 3. CDI (Data Integration) - not in the uploads
- Find task: `POST {saas}/public/core/v3/lookup` with `INFA-SESSION-ID`, body `{"objects":[{"path":"Project/Folder/Task","type":"MTT"}]}`.
- Run: `POST {saas}/api/v2/job` with `icSessionId`, body `{"@type":"job","taskId"|"taskFederatedId":"...","taskType":"MTT"}` (also `Workflow` for linear taskflows).
- Status/results: activity monitor / activity log resources in the platform reference (to confirm on the live org before building).

## 4. Open inputs
- His real `jobDefinitionId`s for ingress/egress/match-merge, and which CDI mapping tasks/taskflows to expose (names or paths).
- The sample .htm files.
