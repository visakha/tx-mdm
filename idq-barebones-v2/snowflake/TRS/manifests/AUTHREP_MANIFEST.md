# Manifest - m_Tgt_C_S_TRS_Pty_Mng_Attr_Auth_Rep_Ongoing (TRS, bare-bones)

Workflow: `wf_TRS_Stage_Load_1_Ongoing`. Driver file: `drivers/driver_sp_snow_main_m_Tgt_C_S_TRS_Pty_Mng_Attr_Auth_Rep_Ongoing.sql`.

## Driver

New driver signature (v2.1 signature minus the run-id parameter; all
original parameters kept, in order, with their defaults):

```sql
CREATE OR REPLACE PROCEDURE sp_snow_main_m_Tgt_C_S_TRS_Pty_Mng_Attr_Auth_Rep_Ongoing (

    P_ATTR_TP_AUTH_REP VARCHAR DEFAULT 'Auth_Rep_Flag'

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
| 10 | `sp_snow_step_TRS_AUTHREP_S10_PAYEE` | TRANSFORM | PAYEE_CASE_ROWS | `WRK_TRS_MNGAR_S10_PAYEE` | (base tables only) | none |
| 20 | `sp_snow_step_TRS_AUTHREP_S20_SRC` | TRANSFORM | VALID_SRC | `WRK_TRS_MNGAR_S20_SRC` | WRK_TRS_MNGAR_S10_PAYEE | none |
| 30 | `sp_snow_step_TRS_AUTHREP_S30_KEYED` | TRANSFORM | KEYED | `WRK_TRS_MNGAR_S30_KEYED` | WRK_TRS_MNGAR_S20_SRC | P_ATTR_TP_AUTH_REP |
| 40 | `sp_snow_step_TRS_AUTHREP_S40_AGG` | TRANSFORM | AGG_DEDUP | `WRK_TRS_MNGAR_S40_AGG` | WRK_TRS_MNGAR_S30_KEYED | none |

Step proc signatures: the step's used original params (in original order)
+ `P_RUN_TS TIMESTAMP_NTZ DEFAULT NULL`. Every step proc returns `NUMBER`
(row count), has no exception block, no transaction, no target write.

Step files: `steps/sp_snow_step_*.sql` (same file names as v2.1).

## Publish branches

| STEP_NO | Proc | Kind | Step name | Target | Consumes | Keeps P_RUN_TS |
|---|---|---|---|---|---|---|
| 50 | `sp_snow_pub_TRS_AUTHREP_C_S_TRS_PTY_MNG_ATTR` | SPINE | PUBLISH_C_S_TRS_PTY_MNG_ATTR | `C_S_TRS_PTY_MNG_ATTR` | WRK_TRS_MNGAR_S40_AGG | Y |

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
