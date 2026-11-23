# REL Manifest -- m_Tgt_C_S_FSS_Pty_Rle_Rel, bare-bones step driver (FSS ONLY)

Prefix: `FSS_REL`. Base dir: `snowflake_all_barebones/FSS/`.

Bare-bones strip of the v2.1 config-driven driver: NO config table, NO checkpoints, NO job-run id, NO seed file. Every step and every publish branch runs unconditionally, in order. Business SQL (step CTAS bodies, publish INSERT bodies) is verbatim from v2.1.

## Driver

File: `drivers/driver_sp_snow_main_m_Tgt_C_S_FSS_Pty_Rle_Rel.sql`

New driver signature (`P_JOB_RUN_ID` removed; all other parameters unchanged, in order, with their defaults):

```sql
sp_snow_main_m_Tgt_C_S_FSS_Pty_Rle_Rel () RETURNS VARCHAR
```

Driver behaviour: step 5 cleanup (bare `DROP TABLE IF EXISTS` for each work table below, no checkpoint) -> unconditional work steps in order -> ONE publish transaction calling the branches in order -> `RETURN l_summary`. Exception block: `ROLLBACK` + `RAISE` only. Work tables are left standing after the run; a restart is simply a new run.

Work tables dropped at step 5: `WRK_FSS_REL_S1_SRC`, `WRK_FSS_REL_S2_CODED`, `WRK_FSS_REL_S3_TYPED`, `WRK_FSS_REL_S4_FINAL`.

## Steps

| STEP_NO | Proc | Produces | Consumes | Original params used | Description |
|---|---|---|---|---|---|
| 10 | `sp_snow_step_FSS_REL_S10_SRC` | `WRK_FSS_REL_S1_SRC` | `(none)` | none | Source relationships, both parties off the deactivation list |
| 20 | `sp_snow_step_FSS_REL_S20_CODED` | `WRK_FSS_REL_S2_CODED` | `WRK_FSS_REL_S1_SRC` | none | Relationship code built (missing code defaults to CAREGIVER), direction code type, output gender, both role keys |
| 30 | `sp_snow_step_FSS_REL_S30_TYPED` | `WRK_FSS_REL_S3_TYPED` | `WRK_FSS_REL_S2_CODED` | none | Relationship code translated through the code-value lookup |
| 40 | `sp_snow_step_FSS_REL_S40_FINAL` | `WRK_FSS_REL_S4_FINAL` | `WRK_FSS_REL_S3_TYPED` | none | Relationship key, constants, exception details, insert-only guards |

Step proc signatures: the step's used original params (in original order) + `P_RUN_TS`. Every step proc returns `NUMBER` (row count), has no exception block, no transaction, no target write, and no existence check. `P_RUN_TS` carries `DEFAULT NULL` only where a preceding original param carries a default (Snowflake forbids a required parameter after an optional one; drivers pass everything positionally, so behaviour is unchanged).

`sp_snow_step_FSS_REL_S10_SRC` signature:
```sql
sp_snow_step_FSS_REL_S10_SRC (
    P_RUN_TS       TIMESTAMP_NTZ
) RETURNS NUMBER
```

`sp_snow_step_FSS_REL_S20_CODED` signature:
```sql
sp_snow_step_FSS_REL_S20_CODED (
    P_RUN_TS       TIMESTAMP_NTZ
) RETURNS NUMBER
```

`sp_snow_step_FSS_REL_S30_TYPED` signature:
```sql
sp_snow_step_FSS_REL_S30_TYPED (
    P_RUN_TS       TIMESTAMP_NTZ
) RETURNS NUMBER
```

`sp_snow_step_FSS_REL_S40_FINAL` signature:
```sql
sp_snow_step_FSS_REL_S40_FINAL (
    P_RUN_TS       TIMESTAMP_NTZ
) RETURNS NUMBER
```


## Publish branches

One transaction, branches in the order below. Each branch proc returns `SQLROWCOUNT` as `NUMBER`, with no transaction control and no checkpoint calls.

| STEP_NO | Proc | Kind | Target | Consumes | Keeps P_RUN_TS | Description |
|---|---|---|---|---|---|---|
| 50 | `sp_snow_pub_FSS_REL_C_S_FSS_PTY_RLE_REL` | SPINE | `C_S_FSS_PTY_RLE_REL` | `WRK_FSS_REL_S4_FINAL` | N | Valid relationships |
| 60 | `sp_snow_pub_FSS_REL_EXC_STG_BAD_REC_MEMB` | EXCEPTION | `EXC_STG_BAD_REC_MEMB` | `WRK_FSS_REL_S4_FINAL` | N | Untranslated relationships |

Branch proc signatures: `P_RUN_TS` is kept ONLY where the INSERT body references `:P_RUN_TS`; every other branch takes no arguments. A `run_ts` / `exc_mapping` COLUMN read from a step table does NOT count as a `:P_RUN_TS` reference.

`sp_snow_pub_FSS_REL_C_S_FSS_PTY_RLE_REL` signature:
```sql
sp_snow_pub_FSS_REL_C_S_FSS_PTY_RLE_REL () RETURNS NUMBER
```

`sp_snow_pub_FSS_REL_EXC_STG_BAD_REC_MEMB` signature:
```sql
sp_snow_pub_FSS_REL_EXC_STG_BAD_REC_MEMB () RETURNS NUMBER
```


## Summary flow

The driver appends one `fn_snow_helper36_common` line per step and per publish branch, in order, to `l_summary`, and `RETURN`s `l_summary` (no job-run-id prefix). The workflow runner `sp_etl_run_wf_FSS_Stage_Load` (called with zero arguments) concatenates each mapping driver's returned summary under a `== <mapping> ==` header line, in run order, and returns the one combined string.


## Files

- Driver: `drivers/driver_sp_snow_main_m_Tgt_C_S_FSS_Pty_Rle_Rel.sql`

- Step: `steps/sp_snow_step_FSS_REL_S10_SRC.sql`

- Step: `steps/sp_snow_step_FSS_REL_S20_CODED.sql`

- Step: `steps/sp_snow_step_FSS_REL_S30_TYPED.sql`

- Step: `steps/sp_snow_step_FSS_REL_S40_FINAL.sql`

- Branch: `publish/sp_snow_pub_FSS_REL_C_S_FSS_PTY_RLE_REL.sql`

- Branch: `publish/sp_snow_pub_FSS_REL_EXC_STG_BAD_REC_MEMB.sql`
