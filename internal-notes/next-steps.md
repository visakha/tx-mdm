# Next steps (in order)

Each item becomes a change proposal under `changes/` before any code is written (see
`methodology/sdd-lifecycle.md`).

1. **First live read-only check against the org** (needs Vamsi's credentials in `backend/.env` and his go-ahead):
   - log in
   - list the CDI tasks and the MDM job definitions
   - record the results in `api-facts.md`

   This promotes the login, list and header facts to LIVE. Do not start any job as part of
   this check.
2. **Settle the MDM job-id source.** Find out whether the export package, FRS documents or a
   live job search is the reliable source of `jobDefinitionId` and job type. Then replace or
   confirm `JobSearchResolver`, and record the egress `jobType` string the org actually returns.
3. **First live run, one job, chosen by Vamsi.** Watch it end to end on the results screen.
   Then confirm the activity-log state mapping (CDI) and the `_meta.state` / `jobLevelMetrics`
   fields (MDM).
4. **Advanced taskflows.** Confirm that `INFA-SESSION-ID` works on `/active-bpel/rt/`, the
   run-id field in the response, and the API-name default.
5. **Real-browser test drive** of the UI and the `window.txmdm` actions, with an agent driving it.
6. **Persist runs** (optional, only if asked). `RunRegistry` is in memory today.
7. **Link CDI tasks to the barebones-v2 tables** (only if asked). See
   `barebones-v2-and-cdi.md`, "Not linked yet".
