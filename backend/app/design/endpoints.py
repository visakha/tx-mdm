"""CDI design (asset metadata) endpoint paths, read-only. 0.9.15 Design notebook.

Source: IICS REST API Reference, November 2025 (docs.informatica.com PDF; page numbers are the
PDF's own). All relative to the platform baseApiUrl (.../saas).
"""

# v3 (header INFA-SESSION-ID). Finding asset dependencies, pp. 211-212.
OBJECT_REFERENCES = "/public/core/v3/objects/{object_id}/references"
REFERENCES_PAGE_SIZE = 50  # documented maximum for the references query

# v2 (header icSessionId).
MTTASK_BY_FRS = "/api/v2/mttask/frs/{federated_id}"  # Mapping tasks, p. 442 (v3 object id)
MTTASK_BY_ID = "/api/v2/mttask/{task_id}"  # Mapping tasks, p. 442 (v2 id = appContextId)
MAPPING_BY_ID = "/api/v2/mapping/{mapping_id}"  # Mappings, p. 438 (v2 id, e.g. mtTask.mappingId)
MAPPING_SEARCH = "/api/v2/mapping/search"  # Mappings, p. 438 (?name=)
RUNTIME_ENVIRONMENTS = "/api/v2/runtimeEnvironment"  # Runtime environments, pp. 79-83
CONNECTIONS = "/api/v2/connection"  # Connections, pp. 319-324
CONNECTION_BY_ID = "/api/v2/connection/{connection_id}"  # Connections, pp. 319-324

MAX_CHILD_DETAILS = 25  # v2 detail calls per taskflow "uses" list, keeps one click modest
