# Manifest — m_Tgt_C_S_TRS_Pty_Rle_Pln (TRS, bare-bones)

Workflow: `wf_TRS_Stage_Load_1_Ongoing`. Driver file: `drivers/driver_sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Pln.sql`.

## Driver

New driver signature (v2.1 signature minus the run-id parameter; all
original parameters kept, in order, with their defaults):

```sql
CREATE OR REPLACE PROCEDURE sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Pln (
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
| 10 | `sp_snow_step_TRS_PLN_S10_SRC` | TRANSFORM | MANAGED_CARE_SRC | `WRK_TRS_PLN_S10_SRC` | (base tables only) | none |
| 20 | `sp_snow_step_TRS_PLN_S20_PLANNED` | TRANSFORM | PLAN_TRANSLATED | `WRK_TRS_PLN_S20_PLANNED` | WRK_TRS_PLN_S10_SRC | none |
| 30 | `sp_snow_step_TRS_PLN_S30_RANKED` | TRANSFORM | RANKED | `WRK_TRS_PLN_S30_RANKED` | WRK_TRS_PLN_S20_PLANNED | none |

Step proc signatures: the step's used original params (in original order)
+ `P_RUN_TS TIMESTAMP_NTZ DEFAULT NULL`. Every step proc returns `NUMBER`
(row count), has no exception block, no transaction, no target write.

Step files: `steps/sp_snow_step_*.sql` (same file names as v2.1).

## Publish branches

| STEP_NO | Proc | Kind | Step name | Target | Consumes | Keeps P_RUN_TS |
|---|---|---|---|---|---|---|
| 40 | `sp_snow_pub_TRS_PLN_C_S_TRS_PTY_RLE_PLN` | SPINE | PUBLISH_C_S_TRS_PTY_RLE_PLN | `C_S_TRS_PTY_RLE_PLN` | WRK_TRS_PLN_S30_RANKED | N |
| 50 | `sp_snow_pub_TRS_PLN_EXC_STG_BAD_REC_MEMB` | EXCEPTION | PUBLISH_EXC_STG_BAD_REC_MEMB | `EXC_STG_BAD_REC_MEMB` | WRK_TRS_PLN_S30_RANKED | N |

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
