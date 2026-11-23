# PTY Manifest -- m_Tgt_C_S_FSS_Pty, bare-bones step driver (FSS ONLY)

Prefix: `FSS_PTY`. Base dir: `snowflake_all_barebones/FSS/`.

Bare-bones strip of the v2.1 config-driven driver: NO config table, NO checkpoints, NO job-run id, NO seed file. Every step and every publish branch runs unconditionally, in order. Business SQL (step CTAS bodies, publish INSERT bodies) is verbatim from v2.1.

## Driver

File: `drivers/driver_sp_snow_main_m_Tgt_C_S_FSS_Pty.sql`

New driver signature (`P_JOB_RUN_ID` removed; all other parameters unchanged, in order, with their defaults):

```sql
sp_snow_main_m_Tgt_C_S_FSS_Pty (
    P_PTY_BO_CLASS_CD_MEMBER VARCHAR DEFAULT 'Indv',
    P_RLE_BO_CLASS_CD_MEMBER VARCHAR DEFAULT 'Member'
) RETURNS VARCHAR
```

Driver behaviour: step 5 cleanup (bare `DROP TABLE IF EXISTS` for each work table below, no checkpoint) -> unconditional work steps in order -> ONE publish transaction calling the branches in order -> `RETURN l_summary`. Exception block: `ROLLBACK` + `RAISE` only. Work tables are left standing after the run; a restart is simply a new run.

Work tables dropped at step 5: `WRK_FSS_PTY_S1_SRC`, `WRK_FSS_PTY_S2_DQ`, `WRK_FSS_PTY_S3_DQ2`, `WRK_FSS_PTY_S4_ROUTED`.

## Steps

| STEP_NO | Proc | Produces | Consumes | Original params used | Description |
|---|---|---|---|---|---|
| 10 | `sp_snow_step_FSS_PTY_S10_SRC` | `WRK_FSS_PTY_S1_SRC` | `(none)` | none | Source clients, deactivated parties removed |
| 20 | `sp_snow_step_FSS_PTY_S20_DQ` | `WRK_FSS_PTY_S2_DQ` | `WRK_FSS_PTY_S1_SRC` | none | Name standardisation, gender, birth date, ethnicity, race, language, suffix checks |
| 30 | `sp_snow_step_FSS_PTY_S30_DQ2` | `WRK_FSS_PTY_S3_DQ2` | `WRK_FSS_PTY_S2_DQ` | none | Standardised values with exception codes / descriptions / types resolved |
| 40 | `sp_snow_step_FSS_PTY_S40_ROUTED` | `WRK_FSS_PTY_S4_ROUTED` | `WRK_FSS_PTY_S3_DQ2` | `P_PTY_BO_CLASS_CD_MEMBER`, `P_RLE_BO_CLASS_CD_MEMBER` | Party / role keys, exception groups, insert-only guards |

Step proc signatures: the step's used original params (in original order) + `P_RUN_TS`. Every step proc returns `NUMBER` (row count), has no exception block, no transaction, no target write, and no existence check. `P_RUN_TS` carries `DEFAULT NULL` only where a preceding original param carries a default (Snowflake forbids a required parameter after an optional one; drivers pass everything positionally, so behaviour is unchanged).

`sp_snow_step_FSS_PTY_S10_SRC` signature:
```sql
sp_snow_step_FSS_PTY_S10_SRC (
    P_RUN_TS       TIMESTAMP_NTZ
) RETURNS NUMBER
```

`sp_snow_step_FSS_PTY_S20_DQ` signature:
```sql
sp_snow_step_FSS_PTY_S20_DQ (
    P_RUN_TS       TIMESTAMP_NTZ
) RETURNS NUMBER
```

`sp_snow_step_FSS_PTY_S30_DQ2` signature:
```sql
sp_snow_step_FSS_PTY_S30_DQ2 (
    P_RUN_TS       TIMESTAMP_NTZ
) RETURNS NUMBER
```

`sp_snow_step_FSS_PTY_S40_ROUTED` signature:
```sql
sp_snow_step_FSS_PTY_S40_ROUTED (
    P_PTY_BO_CLASS_CD_MEMBER VARCHAR DEFAULT 'Indv',
    P_RLE_BO_CLASS_CD_MEMBER VARCHAR DEFAULT 'Member',
    P_RUN_TS       TIMESTAMP_NTZ DEFAULT NULL
) RETURNS NUMBER
```


## Publish branches

One transaction, branches in the order below. Each branch proc returns `SQLROWCOUNT` as `NUMBER`, with no transaction control and no checkpoint calls.

| STEP_NO | Proc | Kind | Target | Consumes | Keeps P_RUN_TS | Description |
|---|---|---|---|---|---|---|
| 50 | `sp_snow_pub_FSS_PTY_C_S_FSS_PTY` | SPINE | `C_S_FSS_PTY` | `WRK_FSS_PTY_S4_ROUTED` | N | Valid parties |
| 60 | `sp_snow_pub_FSS_PTY_C_S_FSS_PTY_RLE` | SPINE | `C_S_FSS_PTY_RLE` | `WRK_FSS_PTY_S4_ROUTED` | N | Valid roles |
| 70 | `sp_snow_pub_FSS_PTY_EXC_STG_BAD_REC_MEMB_GENDER` | EXCEPTION | `EXC_STG_BAD_REC_MEMB` | `WRK_FSS_PTY_S4_ROUTED` | N | Invalid gender |
| 80 | `sp_snow_pub_FSS_PTY_EXC_STG_BAD_REC_MEMB_BIRTH` | EXCEPTION | `EXC_STG_BAD_REC_MEMB` | `WRK_FSS_PTY_S4_ROUTED` | N | Invalid birth date |
| 90 | `sp_snow_pub_FSS_PTY_EXC_STG_BAD_REC_MEMB_ETHNICITY` | EXCEPTION | `EXC_STG_BAD_REC_MEMB` | `WRK_FSS_PTY_S4_ROUTED` | N | Invalid ethnicity |
| 100 | `sp_snow_pub_FSS_PTY_EXC_STG_BAD_REC_MEMB_RACE` | EXCEPTION | `EXC_STG_BAD_REC_MEMB` | `WRK_FSS_PTY_S4_ROUTED` | N | Invalid race |
| 110 | `sp_snow_pub_FSS_PTY_EXC_STG_BAD_REC_MEMB_LANGUAGE` | EXCEPTION | `EXC_STG_BAD_REC_MEMB` | `WRK_FSS_PTY_S4_ROUTED` | N | Invalid language |
| 120 | `sp_snow_pub_FSS_PTY_EXC_STG_BAD_REC_MEMB_SUFFIX` | EXCEPTION | `EXC_STG_BAD_REC_MEMB` | `WRK_FSS_PTY_S4_ROUTED` | N | Invalid suffix |

Branch proc signatures: `P_RUN_TS` is kept ONLY where the INSERT body references `:P_RUN_TS`; every other branch takes no arguments. A `run_ts` / `exc_mapping` COLUMN read from a step table does NOT count as a `:P_RUN_TS` reference.

`sp_snow_pub_FSS_PTY_C_S_FSS_PTY` signature:
```sql
sp_snow_pub_FSS_PTY_C_S_FSS_PTY () RETURNS NUMBER
```

`sp_snow_pub_FSS_PTY_C_S_FSS_PTY_RLE` signature:
```sql
sp_snow_pub_FSS_PTY_C_S_FSS_PTY_RLE () RETURNS NUMBER
```

`sp_snow_pub_FSS_PTY_EXC_STG_BAD_REC_MEMB_GENDER` signature:
```sql
sp_snow_pub_FSS_PTY_EXC_STG_BAD_REC_MEMB_GENDER () RETURNS NUMBER
```

`sp_snow_pub_FSS_PTY_EXC_STG_BAD_REC_MEMB_BIRTH` signature:
```sql
sp_snow_pub_FSS_PTY_EXC_STG_BAD_REC_MEMB_BIRTH () RETURNS NUMBER
```

`sp_snow_pub_FSS_PTY_EXC_STG_BAD_REC_MEMB_ETHNICITY` signature:
```sql
sp_snow_pub_FSS_PTY_EXC_STG_BAD_REC_MEMB_ETHNICITY () RETURNS NUMBER
```

`sp_snow_pub_FSS_PTY_EXC_STG_BAD_REC_MEMB_RACE` signature:
```sql
sp_snow_pub_FSS_PTY_EXC_STG_BAD_REC_MEMB_RACE () RETURNS NUMBER
```

`sp_snow_pub_FSS_PTY_EXC_STG_BAD_REC_MEMB_LANGUAGE` signature:
```sql
sp_snow_pub_FSS_PTY_EXC_STG_BAD_REC_MEMB_LANGUAGE () RETURNS NUMBER
```

`sp_snow_pub_FSS_PTY_EXC_STG_BAD_REC_MEMB_SUFFIX` signature:
```sql
sp_snow_pub_FSS_PTY_EXC_STG_BAD_REC_MEMB_SUFFIX () RETURNS NUMBER
```


## Summary flow

The driver appends one `fn_snow_helper36_common` line per step and per publish branch, in order, to `l_summary`, and `RETURN`s `l_summary` (no job-run-id prefix). The workflow runner `sp_etl_run_wf_FSS_Stage_Load` (called with zero arguments) concatenates each mapping driver's returned summary under a `== <mapping> ==` header line, in run order, and returns the one combined string.


## Files

- Driver: `drivers/driver_sp_snow_main_m_Tgt_C_S_FSS_Pty.sql`

- Step: `steps/sp_snow_step_FSS_PTY_S10_SRC.sql`

- Step: `steps/sp_snow_step_FSS_PTY_S20_DQ.sql`

- Step: `steps/sp_snow_step_FSS_PTY_S30_DQ2.sql`

- Step: `steps/sp_snow_step_FSS_PTY_S40_ROUTED.sql`

- Branch: `publish/sp_snow_pub_FSS_PTY_C_S_FSS_PTY.sql`

- Branch: `publish/sp_snow_pub_FSS_PTY_C_S_FSS_PTY_RLE.sql`

- Branch: `publish/sp_snow_pub_FSS_PTY_EXC_STG_BAD_REC_MEMB_GENDER.sql`

- Branch: `publish/sp_snow_pub_FSS_PTY_EXC_STG_BAD_REC_MEMB_BIRTH.sql`

- Branch: `publish/sp_snow_pub_FSS_PTY_EXC_STG_BAD_REC_MEMB_ETHNICITY.sql`

- Branch: `publish/sp_snow_pub_FSS_PTY_EXC_STG_BAD_REC_MEMB_RACE.sql`

- Branch: `publish/sp_snow_pub_FSS_PTY_EXC_STG_BAD_REC_MEMB_LANGUAGE.sql`

- Branch: `publish/sp_snow_pub_FSS_PTY_EXC_STG_BAD_REC_MEMB_SUFFIX.sql`
