# ECI PUBLISH_DEACTIVATE S10-only map

S10-only twins: ONLY the first (source) step is inlined as a CTE;
later steps and the WHERE gate are dropped. Each target column is
aliased from a first-step column, a literal, or a parameter. A
column the first step does not carry is NULL (recorded below).
A literal producer anywhere in the chain is kept (e.g. the
action label 'Deactivation' / 'Reactivation' from the routing
step); the gate that selects which rows get it is still dropped.

Built: 2 twins. Failed: 0.

## Twins

### sp_snow_pub_ECI_VAL_STG_ECI_PTY_INACTIVE_LOG_DEACTIVATION.sql -> STG_ECI_PTY_INACTIVE_LOG

- Kept steps: `s10_src`. P_RUN_TS: YES.
- WHERE gate dropped: `WHERE grp_deactivation`.
- Column map:
  - `SRC_KEY` <- `PKEY_SRC_OBJECT` (via s30_routed; was `pkey_src_object`)
  - `ROWID_SYSTEM` <- `SRC_SYSTEM` (via s30_routed; was `src_system`)
  - `ACTION` <- `'Deactivation'` (via s30_routed; was `action_deactivation`)
  - `ACTION_DT` <- `:P_RUN_TS` (via s30_routed; was `run_ts`)

### sp_snow_pub_ECI_VAL_STG_ECI_PTY_INACTIVE_STS.sql -> STG_ECI_PTY_INACTIVE_STS

- Kept steps: `s10_src`. P_RUN_TS: YES.
- WHERE gate dropped: `WHERE grp_deactivation AND deactivation_sts IS NULL`.
- Columns set to NULL (no first-step source): DEACTIVATION_STS (via s30_routed).
- Column map:
  - `SRC_KEY` <- `PKEY_SRC_OBJECT` (via s30_routed; was `pkey_src_object`)
  - `ROWID_SYSTEM` <- `SRC_SYSTEM` (via s30_routed; was `src_system`)
  - `DEACTIVATION_STS` <- `NULL` (via s30_routed; was `new_deactivation_sts`)
  - `DEACTIVATION_DT` <- `:P_RUN_TS` (via s30_routed; was `run_ts`)

