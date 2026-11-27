"""MDM (Business 360) endpoint paths.

Sources: Business 360 REST API Reference (Oct 2026) and the B360 Postman collection Vamsi supplied;
the job-definition list call is from the IDMC REST API Reference (July 2026, "Finding an asset").
"""

# Platform host (baseApiUrl .../saas), header INFA-SESSION-ID
OBJECTS = "/public/core/v3/objects"
JOB_DEFINITION_ASSET_TYPE = "MDM_JOB_DEFINITION"

# MDM host (usw1-mdm...), header IDS-SESSION-ID
JOB_SEARCH = "/job/public/api/v1/search"
JOB_INSTANCE_RUN = (
    "/job/public/api/v1/jobInstance/{kind}"  # Ingress | Egress | MatchMerge | publish (config)
)
JOB_INSTANCE_READ = "/job/public/api/v1/jobInstance/{instance_id}"

PAGE_SIZE = 200
JOB_SEARCH_PAGE_SIZE = 100
JOB_SEARCH_MAX_PAGES = 10

# Documented jobTypes. The egress jobType is NOT documented anywhere we found, so egress is
# recognised by the word "egress" in whatever jobType the org returns (see resolver.py).
JOB_TYPE_INGRESS = "c360.ingress.load"
JOB_TYPE_MATCH_MERGE = "c360.be.matchmerge"
# 0.10.1: publish business events. jobType VERIFIED live 2026-11-27 (job search in his org,
# job mdm_zlv_guest_pub_evts_001, Job Process Type "Publish Business Events"). The run path
# {kind} for publish is NOT in the Oct 2026 reference: it comes from settings, see config.py.
JOB_TYPE_PUBLISH_EVENTS = "b360.businessevents.publish"
CONSOLE_FILE_IMPORT_JOB = "internal.c360.ingress.fileImportJob"  # console upload, not runnable
