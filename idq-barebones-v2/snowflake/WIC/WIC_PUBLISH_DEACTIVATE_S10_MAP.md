# WIC PUBLISH_DEACTIVATE S10-only map

S10-only twins: ONLY the first (source) step is inlined as a CTE;
later steps and the WHERE gate are dropped. Each target column is
aliased from a first-step column, a literal, or a parameter. A
column the first step does not carry is NULL (recorded below).
A literal producer anywhere in the chain is kept (e.g. the
action label 'Deactivation' / 'Reactivation' from the routing
step); the gate that selects which rows get it is still dropped.

Built: 2 twins. Failed: 0.

## Twins

### sp_snow_pub_WIC_VAL_STG_WIC_PTY_INACTIVE_LOG_DEACTIVATION.sql -> STG_WIC_PTY_INACTIVE_LOG

- Kept steps: `s10_enriched`. P_RUN_TS: YES.
- WHERE gate dropped: `WHERE name_missing`.
- Column map:
  - `SRC_KEY` <- `PTY_SRC_KEY` (via s30_routed; was `PTY_SRC_KEY`)
  - `ROWID_SYSTEM` <- `'WIC'` (via s30_routed; was `src_sys`)
  - `ACTION` <- `'Deactivation'` (via s30_routed; was `action_deactivation`)
  - `ACTION_DT` <- `:P_RUN_TS` (via s30_routed; was `run_ts`)

### sp_snow_pub_WIC_VAL_STG_WIC_PTY_INACTIVE_STS.sql -> STG_WIC_PTY_INACTIVE_STS

- Kept steps: `s10_enriched`. P_RUN_TS: YES.
- WHERE gate dropped: `WHERE name_missing AND deactivation_sts IS NULL`.
- Column map:
  - `SRC_KEY` <- `PTY_SRC_KEY` (via s30_routed; was `PTY_SRC_KEY`)
  - `ROWID_SYSTEM` <- `'WIC'` (via s30_routed; was `src_sys`)
  - `DEACTIVATION_STS` <- `HUB_STATE_IND` (via s30_routed; was `new_deactivation_sts`)
  - `DEACTIVATION_DT` <- `:P_RUN_TS` (via s30_routed; was `run_ts`)

