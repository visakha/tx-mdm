"""CDI endpoint paths. Source: IICS REST API Reference, November 2025 (see docs/API_NOTES.md)."""

# v3 (header INFA-SESSION-ID), relative to the platform baseApiUrl (.../saas)
OBJECTS = "/public/core/v3/objects"

# v2 (header icSessionId), relative to the platform serverUrl (.../saas)
JOB_RUN = "/api/v2/job"
ACTIVITY_MONITOR = "/api/v2/activity/activityMonitor"
ACTIVITY_LOG = "/api/v2/activity/activityLog"
SESSION_LOG = "/api/v2/activity/activityLog/{log_id}/sessionLog"

# Advanced taskflows, relative to the pod host (baseApiUrl without /saas)
TASKFLOW_RUN = "/active-bpel/rt/{api_name}"
TASKFLOW_STATUS = "/active-bpel/services/tf/status/{run_id}"
# PUT, body {"runid": [...]} (max 200), 204 = terminated, 500 = an invalid id.
# Source: Informatica KB 000216333 "HOW TO: Stop/Terminate Advanced Task flows using API".
TASKFLOW_TERMINATE = "/active-bpel/services/tf/terminate"
TERMINATE_MAX_IDS = 200


PAGE_SIZE = 200  # documented maximum for the objects query
