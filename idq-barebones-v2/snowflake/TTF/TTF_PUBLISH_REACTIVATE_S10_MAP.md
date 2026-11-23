# TTF PUBLISH_REACTIVATE S10-only map

S10-only twins: ONLY the first (source) step is inlined as a CTE;
later steps and the WHERE gate are dropped. Each target column is
aliased from a first-step column, a literal, or a parameter. A
column the first step does not carry is NULL (recorded below).
A literal producer anywhere in the chain is kept (e.g. the
action label 'Deactivation' / 'Reactivation' from the routing
step); the gate that selects which rows get it is still dropped.

Built: 1 twins. Failed: 0.

## Twins

### sp_snow_pub_TTF_VAL_STG_TTF_PTY_INACTIVE_LOG_REACTIVATION.sql -> STG_TTF_PTY_INACTIVE_LOG

- Kept steps: `s1_enriched`. P_RUN_TS: YES.
- WHERE gate dropped: `WHERE grp_reactivation`.
- Column map:
  - `SRC_KEY` <- `PKEY_SRC_OBJECT` (via s3_routed; was `pkey_src_object`)
  - `ROWID_SYSTEM` <- `'TTF'` (via s3_routed; was `src_sys`)
  - `ACTION` <- `'Reactivation'` (via s3_routed; was `action_reactivation`)
  - `ACTION_DT` <- `:P_RUN_TS` (via s3_routed; was `run_ts`)

