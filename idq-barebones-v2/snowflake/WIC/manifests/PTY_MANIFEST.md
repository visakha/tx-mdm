# PTY Manifest — m_Tgt_C_S_WIC_Pty, bare-bones step-driver variant (WIC ONLY)
Workflow: `wf_WIC_Stage_Load`. Base dir: `snowflake_all_barebones/WIC/`.
Install schema is `WIC_ETL_WRK` in database `MDM_ETL_WIC`; all table names are unqualified.

## Driver

```sql
sp_snow_main_m_Tgt_C_S_WIC_Pty (
    P_PTY_BO_CLASS_CD_MEMBER VARCHAR DEFAULT 'Indv',  -- $PTY_BO_CLASS_CD_Member
    P_RLE_BO_CLASS_CD_MEMBER VARCHAR DEFAULT 'Member'  -- $RLE_BO_CLASS_CD_Member
) RETURNS VARCHAR
```
File: `drivers/driver_sp_snow_main_m_Tgt_C_S_WIC_Pty.sql`

Driver behaviour: step 5 cleanup (bare `DROP TABLE IF EXISTS`, no framework calls); step calls in order, unconditional; ONE publish transaction calling the branch procs in order, then `COMMIT`; summary lines appended per step and per branch via `fn_snow_helper36_common`; the driver RETURNs `l_summary`. Work tables are left standing at the end; the next run's step 5 drops them. Exception block: `ROLLBACK` + `RAISE` only.

## Steps

| STEP_NO | Proc | Produces | Consumes |
|---|---|---|---|
| 10 | `sp_snow_step_WIC_PTY_S10_ACTIVE` | `WRK_WIC_PTY_S10_ACTIVE` — Active source parties only (parties with a deactivation status removed). Only step that reads V_WIC_ETL_SRC. | (base tables — no work-table input) |
| 20 | `sp_snow_step_WIC_PTY_S20_DQ` | `WRK_WIC_PTY_S20_DQ` — Name standardisation, gender, birth date, ethnicity, race indicators, language. | `WRK_WIC_PTY_S10_ACTIVE` |
| 30 | `sp_snow_step_WIC_PTY_S30_DQ2` | `WRK_WIC_PTY_S30_DQ2` — Standardised values pulled out; every exception description and type resolved from the exception lookup; birth-date value used downstream is NULL when the birth date raised an exception. | `WRK_WIC_PTY_S20_DQ` |
| 40 | `sp_snow_step_WIC_PTY_S40_ROUTED` | `WRK_WIC_PTY_S40_ROUTED` — Party and role keys, exception routing groups, run constants, birth weight in grams, and the insert-only guards (uq_pty, uq_rle, uq_gender, uq_birth, uq_ethnicity, uq_race, uq_language). Guards evaluated here, before publish, as in the original single query. | `WRK_WIC_PTY_S30_DQ2` |

Step proc signatures: the step's used original params (in original order) + `P_RUN_TS`. Where an original param carries a default, `P_RUN_TS` carries `DEFAULT NULL` (Snowflake forbids a required parameter after an optional one; drivers pass all parameters positionally, so behaviour is unchanged). Each step runs its CTAS verbatim and RETURNs its row count. Step files live in `steps/` under their v2.1 names.

## Publish branches

| STEP_NO | Proc | Kind | Target | Consumes | Keeps run-ts |
|---|---|---|---|---|---|
| 50 | `sp_snow_pub_WIC_PTY_C_S_WIC_PTY` | SPINE | `C_S_WIC_PTY` (valid parties) | `WRK_WIC_PTY_S40_ROUTED` | N |
| 60 | `sp_snow_pub_WIC_PTY_C_S_WIC_PTY_RLE` | SPINE | `C_S_WIC_PTY_RLE` (valid roles) | `WRK_WIC_PTY_S40_ROUTED` | N |
| 70 | `sp_snow_pub_WIC_PTY_EXC_STG_BAD_REC_MEMB_GENDER` | EXCEPTION | `EXC_STG_BAD_REC_MEMB` (invalid-gender exceptions) | `WRK_WIC_PTY_S40_ROUTED` | N |
| 80 | `sp_snow_pub_WIC_PTY_EXC_STG_BAD_REC_MEMB_BIRTH` | EXCEPTION | `EXC_STG_BAD_REC_MEMB` (invalid-birth-date exceptions) | `WRK_WIC_PTY_S40_ROUTED` | N |
| 90 | `sp_snow_pub_WIC_PTY_EXC_STG_BAD_REC_MEMB_ETHNICITY` | EXCEPTION | `EXC_STG_BAD_REC_MEMB` (invalid-ethnicity exceptions) | `WRK_WIC_PTY_S40_ROUTED` | N |
| 100 | `sp_snow_pub_WIC_PTY_EXC_STG_BAD_REC_MEMB_RACE` | EXCEPTION | `EXC_STG_BAD_REC_MEMB` (invalid-race exceptions) | `WRK_WIC_PTY_S40_ROUTED` | N |
| 110 | `sp_snow_pub_WIC_PTY_EXC_STG_BAD_REC_MEMB_LANGUAGE` | EXCEPTION | `EXC_STG_BAD_REC_MEMB` (invalid-language exceptions) | `WRK_WIC_PTY_S40_ROUTED` | N |

Branch proc signatures: original params the INSERT actually uses + `P_RUN_TS` ONLY where the INSERT references the run-timestamp parameter directly (a `run_ts` column read from a step table does not count). Every other branch takes no parameters. Each branch RETURNs `SQLROWCOUNT` as `NUMBER`, with no transaction control. Branch files live in `publish/` under their v2.1 names.

## Summary flow

- The driver RETURNs `l_summary`: one line per step (row count via `fn_snow_helper36_common`), then one line per publish branch in branch order.
- The workflow runner calls all five drivers with zero arguments and concatenates their summaries under per-mapping header lines into one string, which it RETURNs.

## Preserved notes (business logic preserved, not fixed)

- Insert-only: IDQ truncates of C_S_WIC_PTY and C_S_WIC_PTY_RLE are not performed; keys already present are skipped by the uq_pty and uq_rle guards.
- Party birth date is the source DOB, while the language exception row writes the mapplet birth date (NULL for a future one).
- Birth weight in grams is BIRTH_WT_OZ * 28.35 (ounces only).
- VERSION_SEQ hard-coded to 1; PERIOD_START_DATE = DATEKEY; HUB_STATE_IND hard-coded to 1.
