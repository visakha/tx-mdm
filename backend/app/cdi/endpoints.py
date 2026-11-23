"""CDI endpoint paths. Source: IICS REST API Reference, November 2025 (see docs/API_NOTES.md)."""

# v3 (header INFA-SESSION-ID), relative to the platform baseApiUrl (.../saas)
OBJECTS = "/public/core/v3/objects"

# v2 (header icSessionId), relative to the platform serverUrl (.../saas)
JOB_RUN = "/api/v2/job"
ACTIVITY_MONITOR = "/api/v2/activity/activityMonitor"
ACTIVITY_LOG = "/api/v2/activity/activityLog"

# Advanced taskflows, relative to the pod host (baseApiUrl without /saas)
TASKFLOW_RUN = "/active-bpel/rt/{api_name}"
TASKFLOW_STATUS = "/active-bpel/services/tf/status/{run_id}"

V3_HEADERS = ("INFA-SESSION-ID",)
V2_HEADERS = ("icSessionId",)

PAGE_SIZE = 200  # documented maximum for the objects query
