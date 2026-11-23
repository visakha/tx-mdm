# Manifest — m_Tgt_C_S_TRS_Pty_Deactivation_1 (TRS, bare-bones)

Workflow: `wf_TRS_Stage_Load_1_Ongoing`. Driver file: `drivers/driver_sp_snow_main_m_Tgt_C_S_TRS_Pty_Deactivation_1.sql`.

## Driver

New driver signature (v2.1 signature minus the run-id parameter; all
original parameters kept, in order, with their defaults):

```sql
CREATE OR REPLACE PROCEDURE sp_snow_main_m_Tgt_C_S_TRS_Pty_Deactivation_1 (
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
| 10 | `sp_snow_step_TRS_PTYDEACT_S10_DEACTV` | TRANSFORM | DEACTIVATED_INDIVIDUALS | `WRK_TRS_DEACT1_S10_DEACTV` | (base tables only) | none |
| 20 | `sp_snow_step_TRS_PTYDEACT_S20_DEACTV_ID` | TRANSFORM | DEACTIVATED_PER_INDIVIDUAL | `WRK_TRS_DEACT1_S20_DEACTV_ID` | WRK_TRS_DEACT1_S10_DEACTV | none |
| 30 | `sp_snow_step_TRS_PTYDEACT_S30_READY` | TRANSFORM | READY_TO_PUBLISH | `WRK_TRS_DEACT1_S30_READY` | WRK_TRS_DEACT1_S20_DEACTV_ID | none |
| 50 | `sp_snow_step_TRS_PTYDEACT_S50_NOTPERFORMED` | STATUS | DELETE_VALID_STAGE_NOT_PERFORMED | (no table; no data written) | (none) | none |

Step proc signatures: the step's used original params (in original order)
+ `P_RUN_TS TIMESTAMP_NTZ DEFAULT NULL`. Every step proc returns `NUMBER`
(row count), has no exception block, no transaction, no target write.

Step files: `steps/sp_snow_step_*.sql` (same file names as v2.1).

## Publish branches

| STEP_NO | Proc | Kind | Step name | Target | Consumes | Keeps P_RUN_TS |
|---|---|---|---|---|---|---|
| 40 | `sp_snow_pub_TRS_PTYDEACT_STG_TRS_DEACTIVED_MEMBERS` | STATUS | PUBLISH_STG_TRS_DEACTIVED_MEMBERS | `STG_TRS_DEACTIVED_MEMBERS` | WRK_TRS_DEACT1_S30_READY | N |

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

## Step 50 note (party deactivation only)

Step 50 (`DELETE_VALID_STAGE_NOT_PERFORMED`) writes NO data. In v2.1 its
only action was a completion record; in this bare-bones variant the
proc just returns 0 and the driver appends the plain-text line
`step 50 DELETE_VALID_STAGE_NOT_PERFORMED: recorded, no data written
(deliberate, see manifest)` to the summary. The IDQ behaviour it
stands for (Delete_Valid_Stage, DD_DELETE of deactivated members from
STG_TRS_VALID_MEMBERS) is deliberately NOT performed: this code base
never deletes, truncates or drops target rows (rows are only inserted).
Re-adding the delete is a business decision, not a silent fix.
