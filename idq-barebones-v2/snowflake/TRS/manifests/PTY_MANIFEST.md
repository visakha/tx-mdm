# Manifest - m_Tgt_C_S_TRS_Pty_OnGoing (TRS, bare-bones)

Workflow: `wf_TRS_Stage_Load_1_Ongoing`. Driver file: `drivers/driver_sp_snow_main_m_Tgt_C_S_TRS_Pty_OnGoing.sql`.

## Driver

New driver signature (v2.1 signature minus the run-id parameter; all
original parameters kept, in order, with their defaults):

```sql
CREATE OR REPLACE PROCEDURE sp_snow_main_m_Tgt_C_S_TRS_Pty_OnGoing (

    P_PTY_BO_CLASS_CD_MEMBER VARCHAR DEFAULT 'Indv',
    P_RLE_BO_CLASS_CD_MEMBER VARCHAR DEFAULT 'Member',
    P_DC_INDV_TBL_SRC        VARCHAR DEFAULT 'DC_INDV',
    P_MCI_TBL_SRC            VARCHAR DEFAULT 'MCI'

) RETURNS VARCHAR
```

Driver behaviour: step 5 drops the mapping work tables (bare `DROP TABLE
IF EXISTS`, no completion record); every step runs unconditionally, in
order; ONE publish transaction calls all branch procs in order, then
COMMIT; on error the exception block does ROLLBACK + RAISE only. Work
tables are NOT dropped at the end of a run. The driver RETURNs
`l_summary`.

## Steps

| STEP_NO | Proc | Kind | Step name | Produces | Consumes | Original params used |
|---|---|---|---|---|---|---|
| 10 | `sp_snow_step_TRS_PTY_S10_SRC` | TRANSFORM | SRC_VALID_LIST | `WRK_TRS_PTY_S1_SRC` | (base tables only) | P_DC_INDV_TBL_SRC, P_MCI_TBL_SRC |
| 20 | `sp_snow_step_TRS_PTY_S20_DQ` | TRANSFORM | DQ_STANDARDISE_VALIDATE | `WRK_TRS_PTY_S2_DQ` | WRK_TRS_PTY_S1_SRC | P_DC_INDV_TBL_SRC |
| 30 | `sp_snow_step_TRS_PTY_S30_ROUTER` | TRANSFORM | ROUTER_EXCEPTIONS | `WRK_TRS_PTY_S3_ROUTER` | WRK_TRS_PTY_S2_DQ | none |
| 40 | `sp_snow_step_TRS_PTY_S40_DEDUP` | TRANSFORM | DEDUP_VALID | `WRK_TRS_PTY_S4_DEDUP` | WRK_TRS_PTY_S2_DQ | P_RLE_BO_CLASS_CD_MEMBER |

Step proc signatures: the step's used original params (in original order)
+ `P_RUN_TS TIMESTAMP_NTZ DEFAULT NULL`. Every step proc returns `NUMBER`
(row count), has no exception block, no transaction, no target write.

Step files: `steps/sp_snow_step_*.sql` (same file names as v2.1).

## Publish branches

| STEP_NO | Proc | Kind | Step name | Target | Consumes | Keeps P_RUN_TS |
|---|---|---|---|---|---|---|
| 50 | `sp_snow_pub_TRS_PTY_EXC_STG_BAD_REC_MEMB_NAME` | EXCEPTION | PUBLISH_EXC_NAME | `EXC_STG_BAD_REC_MEMB` | WRK_TRS_PTY_S3_ROUTER | Y |
| 60 | `sp_snow_pub_TRS_PTY_EXC_STG_BAD_REC_MEMB_GENDER` | EXCEPTION | PUBLISH_EXC_GENDER | `EXC_STG_BAD_REC_MEMB` | WRK_TRS_PTY_S3_ROUTER | Y |
| 70 | `sp_snow_pub_TRS_PTY_EXC_STG_BAD_REC_MEMB_DEATH` | EXCEPTION | PUBLISH_EXC_DEATH | `EXC_STG_BAD_REC_MEMB` | WRK_TRS_PTY_S3_ROUTER | Y |
| 80 | `sp_snow_pub_TRS_PTY_EXC_STG_BAD_REC_MEMB_BIRTH` | EXCEPTION | PUBLISH_EXC_BIRTH | `EXC_STG_BAD_REC_MEMB` | WRK_TRS_PTY_S3_ROUTER | Y |
| 90 | `sp_snow_pub_TRS_PTY_C_S_TRS_PTY` | SPINE | PUBLISH_C_S_TRS_PTY | `C_S_TRS_PTY` | WRK_TRS_PTY_S4_DEDUP | Y |
| 100 | `sp_snow_pub_TRS_PTY_C_S_TRS_PTY_RLE` | SPINE | PUBLISH_C_S_TRS_PTY_RLE | `C_S_TRS_PTY_RLE` | WRK_TRS_PTY_S4_DEDUP | Y |
| 110 | `sp_snow_pub_TRS_PTY_STG_TRS_VALID_MEMBERS` | SPINE | PUBLISH_STG_TRS_VALID_MEMBERS | `STG_TRS_VALID_MEMBERS` | WRK_TRS_PTY_S4_DEDUP | Y |
| 120 | `sp_snow_pub_TRS_PTY_EXC_STG_BAD_REC_MEMB_RACE` | EXCEPTION | PUBLISH_EXC_RACE | `EXC_STG_BAD_REC_MEMB` | WRK_TRS_PTY_S4_DEDUP | Y |
| 130 | `sp_snow_pub_TRS_PTY_EXC_STG_BAD_REC_MEMB_ETHNICITY` | EXCEPTION | PUBLISH_EXC_ETHNICITY | `EXC_STG_BAD_REC_MEMB` | WRK_TRS_PTY_S4_DEDUP | Y |

Branch proc signatures: the branch's used original params (in original
order) + `P_RUN_TS TIMESTAMP_NTZ DEFAULT NULL` ONLY where the INSERT body
references the run-timestamp parameter (Keeps P_RUN_TS = Y above). Branch
procs contain no transaction control and return `SQLROWCOUNT`; the driver
calls them inside ONE publish transaction.

Branch files: `publish/sp_snow_pub_*.sql` (same file names as v2.1).

## Summary flow

The driver RETURNs `l_summary`. Each step appends one line via
`fn_snow_helper36_common` (mapping, step label, row count); each publish
branch appends its line the same way, reusing `l_rows`, inside the publish
transaction. The workflow runner calls each driver with ZERO arguments,
captures each RETURN string, and concatenates them with one per-mapping
header line plus newlines into one big summary string, which it RETURNs.
