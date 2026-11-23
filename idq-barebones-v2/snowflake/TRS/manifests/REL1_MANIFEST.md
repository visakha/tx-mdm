# Manifest - m_Tgt_C_S_TRS_Pty_Rle_Rel_1_Mem_To_Mem (TRS, bare-bones)

Workflow: `wf_TRS_Stage_Load_1_Ongoing`. Driver file: `drivers/driver_sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Rel_1_Mem_To_Mem.sql`.

## Driver

New driver signature (v2.1 signature minus the run-id parameter; all
original parameters kept, in order, with their defaults):

```sql
CREATE OR REPLACE PROCEDURE sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Rel_1_Mem_To_Mem (

    P_INDV_ID_ALT_ID_TP VARCHAR DEFAULT '007' -- $INDV_ID_ALT_ID_TP (substituted into the source SQL)

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
| 10 | `sp_snow_step_TRS_REL1_S10_SRC` | TRANSFORM | SRC_RELATIONSHIPS | `WRK_TRS_REL1_S1_SRC` | (base tables only) | P_INDV_ID_ALT_ID_TP |
| 20 | `sp_snow_step_TRS_REL1_S20_KEYED` | TRANSFORM | KEYED | `WRK_TRS_REL1_S2_KEYED` | WRK_TRS_REL1_S1_SRC | none |
| 30 | `sp_snow_step_TRS_REL1_S30_ROUTER` | TRANSFORM | ROUTER_EXCEPTIONS | `WRK_TRS_REL1_S3_ROUTER` | WRK_TRS_REL1_S2_KEYED | none |
| 40 | `sp_snow_step_TRS_REL1_S40_CONSOL` | TRANSFORM | CONSOLIDATED | `WRK_TRS_REL1_S4_CONSOL` | WRK_TRS_REL1_S2_KEYED | none |
| 50 | `sp_snow_step_TRS_REL1_S50_PREP` | TRANSFORM | PREPARED | `WRK_TRS_REL1_S5_PREP` | WRK_TRS_REL1_S4_CONSOL | none |
| 60 | `sp_snow_step_TRS_REL1_S60_TIMELINE` | TRANSFORM | TIMELINE | `WRK_TRS_REL1_S6_TIMELINE` | WRK_TRS_REL1_S5_PREP | none |

Step proc signatures: the step's used original params (in original order)
+ `P_RUN_TS TIMESTAMP_NTZ DEFAULT NULL`. Every step proc returns `NUMBER`
(row count), has no exception block, no transaction, no target write.

Step files: `steps/sp_snow_step_*.sql` (same file names as v2.1).

## Publish branches

| STEP_NO | Proc | Kind | Step name | Target | Consumes | Keeps P_RUN_TS |
|---|---|---|---|---|---|---|
| 70 | `sp_snow_pub_TRS_REL1_EXC_STG_BAD_REC_MEMB_MAIN_ALT_ID` | EXCEPTION | PUBLISH_EXC_MAIN_ALT_ID | `EXC_STG_BAD_REC_MEMB` | WRK_TRS_REL1_S3_ROUTER | Y |
| 80 | `sp_snow_pub_TRS_REL1_EXC_STG_BAD_REC_MEMB_REF_ALT_ID` | EXCEPTION | PUBLISH_EXC_REF_ALT_ID | `EXC_STG_BAD_REC_MEMB` | WRK_TRS_REL1_S3_ROUTER | Y |
| 90 | `sp_snow_pub_TRS_REL1_EXC_STG_BAD_REC_MEMB_LOOKUP` | EXCEPTION | PUBLISH_EXC_LOOKUP | `EXC_STG_BAD_REC_MEMB` | WRK_TRS_REL1_S3_ROUTER | Y |
| 100 | `sp_snow_pub_TRS_REL1_EXC_STG_BAD_REC_MEMB_DATES` | EXCEPTION | PUBLISH_EXC_DATES | `EXC_STG_BAD_REC_MEMB` | WRK_TRS_REL1_S3_ROUTER | Y |
| 110 | `sp_snow_pub_TRS_REL1_C_S_TRS_PTY_RLE_REL` | SPINE | PUBLISH_C_S_TRS_PTY_RLE_REL | `C_S_TRS_PTY_RLE_REL` | WRK_TRS_REL1_S6_TIMELINE | Y |

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
