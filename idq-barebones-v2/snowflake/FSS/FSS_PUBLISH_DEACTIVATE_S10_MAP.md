# FSS PUBLISH_DEACTIVATE S10-only map

S10-only twins: ONLY the first (source) step is inlined as a CTE;
later steps and the WHERE gate are dropped. Each target column is
aliased from a first-step column, a literal, or a parameter. A
column the first step does not carry is NULL (recorded below).
A literal producer anywhere in the chain is kept (e.g. the
action label 'Deactivation' / 'Reactivation' from the routing
step); the gate that selects which rows get it is still dropped.

Built: 2 twins. Failed: 0.

## Twins

### sp_snow_pub_FSS_VAL_STG_FSS_PTY_INACTIVE_LOG.sql -> STG_FSS_PTY_INACTIVE_LOG

- Kept steps: `s1_src`. P_RUN_TS: YES.
- WHERE gate dropped: `WHERE grp_deactivation`.
- Column map:
  - `SRC_KEY` <- `PTY_SRC_KEY` (via s3_routed; was `PTY_SRC_KEY`)
  - `ROWID_SYSTEM` <- `'FSS'` (via s3_routed; was `src_sys`)
  - `ACTION` <- `'Deactivation'` (via s3_routed; was `action_deactivation`)
  - `ACTION_DT` <- `:P_RUN_TS` (via s3_routed; was `run_ts`)

### sp_snow_pub_FSS_VAL_STG_FSS_PTY_INACTIVE_STS_NEW.sql -> STG_FSS_PTY_INACTIVE_STS

- Kept steps: `s1_src`. P_RUN_TS: YES.
- WHERE gate dropped: `WHERE grp_deactivation AND deactivation_sts IS NULL`.
- Columns set to NULL (no first-step source): DEACTIVATION_STS (via s3_routed).
- Column map:
  - `SRC_KEY` <- `PTY_SRC_KEY` (via s3_routed; was `PTY_SRC_KEY`)
  - `ROWID_SYSTEM` <- `'FSS'` (via s3_routed; was `src_sys`)
  - `DEACTIVATION_STS` <- `NULL` (via s3_routed; was `new_deactivation_sts`)
  - `DEACTIVATION_DT` <- `:P_RUN_TS` (via s3_routed; was `run_ts`)

