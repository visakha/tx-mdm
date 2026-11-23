# PHN Manifest -- m_Tgt_C_S_FSS_Pty_Rle_Phn_And_EAddr, bare-bones step driver (FSS ONLY)

Prefix: `FSS_PHN`. Base dir: `snowflake_all_barebones/FSS/`.

Bare-bones strip of the v2.1 config-driven driver: NO config table, NO checkpoints, NO job-run id, NO seed file. Every step and every publish branch runs unconditionally, in order. Business SQL (step CTAS bodies, publish INSERT bodies) is verbatim from v2.1.

## Driver

File: `drivers/driver_sp_snow_main_m_Tgt_C_S_FSS_Pty_Rle_Phn_And_EAddr.sql`

New driver signature (`P_JOB_RUN_ID` removed; all other parameters unchanged, in order, with their defaults):

```sql
sp_snow_main_m_Tgt_C_S_FSS_Pty_Rle_Phn_And_EAddr () RETURNS VARCHAR
```

Driver behaviour: step 5 cleanup (bare `DROP TABLE IF EXISTS` for each work table below, no checkpoint) -> unconditional work steps in order -> ONE publish transaction calling the branches in order -> `RETURN l_summary`. Exception block: `ROLLBACK` + `RAISE` only. Work tables are left standing after the run; a restart is simply a new run.

Work tables dropped at step 5: `WRK_FSS_PHN_S1_SRC`, `WRK_FSS_PHN_S2_DQ`, `WRK_FSS_PHN_S3_CHECKED`, `WRK_FSS_PHN_S4_ROUTED`.

## Steps

| STEP_NO | Proc | Produces | Consumes | Original params used | Description |
|---|---|---|---|---|---|
| 10 | `sp_snow_step_FSS_PHN_S10_SRC` | `WRK_FSS_PHN_S1_SRC` | `(none)` | none | Source rows with role, e-mail and phone keys built, deactivated parties removed |
| 20 | `sp_snow_step_FSS_PHN_S20_DQ` | `WRK_FSS_PHN_S2_DQ` | `WRK_FSS_PHN_S1_SRC` | none | E-mail validation, phone standardisation, extension check |
| 30 | `sp_snow_step_FSS_PHN_S30_CHECKED` | `WRK_FSS_PHN_S3_CHECKED` | `WRK_FSS_PHN_S2_DQ` | none | Standardised e-mail, phone exception code (area-code lookup), standardised extension + its exception code |
| 40 | `sp_snow_step_FSS_PHN_S40_ROUTED` | `WRK_FSS_PHN_S4_ROUTED` | `WRK_FSS_PHN_S3_CHECKED` | none | Exception details, good / bad groups for e-mail, phone and extension, insert-only guards |

Step proc signatures: the step's used original params (in original order) + `P_RUN_TS`. Every step proc returns `NUMBER` (row count), has no exception block, no transaction, no target write, and no existence check. `P_RUN_TS` carries `DEFAULT NULL` only where a preceding original param carries a default (Snowflake forbids a required parameter after an optional one; drivers pass everything positionally, so behaviour is unchanged).

`sp_snow_step_FSS_PHN_S10_SRC` signature:
```sql
sp_snow_step_FSS_PHN_S10_SRC (
    P_RUN_TS       TIMESTAMP_NTZ
) RETURNS NUMBER
```

`sp_snow_step_FSS_PHN_S20_DQ` signature:
```sql
sp_snow_step_FSS_PHN_S20_DQ (
    P_RUN_TS       TIMESTAMP_NTZ
) RETURNS NUMBER
```

`sp_snow_step_FSS_PHN_S30_CHECKED` signature:
```sql
sp_snow_step_FSS_PHN_S30_CHECKED (
    P_RUN_TS       TIMESTAMP_NTZ
) RETURNS NUMBER
```

`sp_snow_step_FSS_PHN_S40_ROUTED` signature:
```sql
sp_snow_step_FSS_PHN_S40_ROUTED (
    P_RUN_TS       TIMESTAMP_NTZ
) RETURNS NUMBER
```


## Publish branches

One transaction, branches in the order below. Each branch proc returns `SQLROWCOUNT` as `NUMBER`, with no transaction control and no checkpoint calls.

| STEP_NO | Proc | Kind | Target | Consumes | Keeps P_RUN_TS | Description |
|---|---|---|---|---|---|---|
| 50 | `sp_snow_pub_FSS_PHN_C_S_FSS_PTY_RLE_EADDR` | SPINE | `C_S_FSS_PTY_RLE_EADDR` | `WRK_FSS_PHN_S4_ROUTED` | N | Valid e-mails |
| 60 | `sp_snow_pub_FSS_PHN_EXC_STG_BAD_REC_MEMB_EMAIL` | EXCEPTION | `EXC_STG_BAD_REC_MEMB` | `WRK_FSS_PHN_S4_ROUTED` | N | Bad e-mails |
| 70 | `sp_snow_pub_FSS_PHN_C_S_FSS_PTY_RLE_PHN` | SPINE | `C_S_FSS_PTY_RLE_PHN` | `WRK_FSS_PHN_S4_ROUTED` | N | Valid phones |
| 80 | `sp_snow_pub_FSS_PHN_EXC_STG_BAD_REC_MEMB_PHONE` | EXCEPTION | `EXC_STG_BAD_REC_MEMB` | `WRK_FSS_PHN_S4_ROUTED` | N | Bad phones |
| 90 | `sp_snow_pub_FSS_PHN_EXC_STG_BAD_REC_MEMB_EXTENSION` | EXCEPTION | `EXC_STG_BAD_REC_MEMB` | `WRK_FSS_PHN_S4_ROUTED` | N | Bad extensions |

Branch proc signatures: `P_RUN_TS` is kept ONLY where the INSERT body references `:P_RUN_TS`; every other branch takes no arguments. A `run_ts` / `exc_mapping` COLUMN read from a step table does NOT count as a `:P_RUN_TS` reference.

`sp_snow_pub_FSS_PHN_C_S_FSS_PTY_RLE_EADDR` signature:
```sql
sp_snow_pub_FSS_PHN_C_S_FSS_PTY_RLE_EADDR () RETURNS NUMBER
```

`sp_snow_pub_FSS_PHN_EXC_STG_BAD_REC_MEMB_EMAIL` signature:
```sql
sp_snow_pub_FSS_PHN_EXC_STG_BAD_REC_MEMB_EMAIL () RETURNS NUMBER
```

`sp_snow_pub_FSS_PHN_C_S_FSS_PTY_RLE_PHN` signature:
```sql
sp_snow_pub_FSS_PHN_C_S_FSS_PTY_RLE_PHN () RETURNS NUMBER
```

`sp_snow_pub_FSS_PHN_EXC_STG_BAD_REC_MEMB_PHONE` signature:
```sql
sp_snow_pub_FSS_PHN_EXC_STG_BAD_REC_MEMB_PHONE () RETURNS NUMBER
```

`sp_snow_pub_FSS_PHN_EXC_STG_BAD_REC_MEMB_EXTENSION` signature:
```sql
sp_snow_pub_FSS_PHN_EXC_STG_BAD_REC_MEMB_EXTENSION () RETURNS NUMBER
```


## Summary flow

The driver appends one `fn_snow_helper36_common` line per step and per publish branch, in order, to `l_summary`, and `RETURN`s `l_summary` (no job-run-id prefix). The workflow runner `sp_etl_run_wf_FSS_Stage_Load` (called with zero arguments) concatenates each mapping driver's returned summary under a `== <mapping> ==` header line, in run order, and returns the one combined string.


## Files

- Driver: `drivers/driver_sp_snow_main_m_Tgt_C_S_FSS_Pty_Rle_Phn_And_EAddr.sql`

- Step: `steps/sp_snow_step_FSS_PHN_S10_SRC.sql`

- Step: `steps/sp_snow_step_FSS_PHN_S20_DQ.sql`

- Step: `steps/sp_snow_step_FSS_PHN_S30_CHECKED.sql`

- Step: `steps/sp_snow_step_FSS_PHN_S40_ROUTED.sql`

- Branch: `publish/sp_snow_pub_FSS_PHN_C_S_FSS_PTY_RLE_EADDR.sql`

- Branch: `publish/sp_snow_pub_FSS_PHN_EXC_STG_BAD_REC_MEMB_EMAIL.sql`

- Branch: `publish/sp_snow_pub_FSS_PHN_C_S_FSS_PTY_RLE_PHN.sql`

- Branch: `publish/sp_snow_pub_FSS_PHN_EXC_STG_BAD_REC_MEMB_PHONE.sql`

- Branch: `publish/sp_snow_pub_FSS_PHN_EXC_STG_BAD_REC_MEMB_EXTENSION.sql`
