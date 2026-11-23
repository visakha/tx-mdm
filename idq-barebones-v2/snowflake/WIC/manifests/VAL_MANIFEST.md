# VAL Manifest — m_Tgt_C_S_WIC_Pty_Validation, bare-bones step-driver variant (WIC ONLY)
Workflow: `wf_WIC_Stage_Load`. Base dir: `snowflake_all_barebones/WIC/`.
Install schema is `WIC_ETL_WRK` in database `MDM_ETL_WIC`; all table names are unqualified.

## Driver

```sql
sp_snow_main_m_Tgt_C_S_WIC_Pty_Validation (
) RETURNS VARCHAR
```
File: `drivers/driver_sp_snow_main_m_Tgt_C_S_WIC_Pty_Validation.sql`

Driver behaviour: step 5 cleanup (bare `DROP TABLE IF EXISTS`, no framework calls); step calls in order, unconditional; ONE publish transaction calling the branch procs in order, then `COMMIT`; summary lines appended per step and per branch via `fn_snow_helper36_common`; the driver RETURNs `l_summary`. Work tables are left standing at the end; the next run's step 5 drops them. Exception block: `ROLLBACK` + `RAISE` only.

## Steps

| STEP_NO | Proc | Produces | Consumes |
|---|---|---|---|
| 10 | `sp_snow_step_WIC_VAL_S10_ENRICHED` | `WRK_WIC_VAL_S10_ENRICHED` — Source parties joined to the current deactivation status (latest row per source key) and the cross-reference hub state, with standardised names computed. The status and cross-reference lookups stay inline here because they are reference lookups, not data stages. Only step that reads V_WIC_ETL_SRC. | (base tables — no work-table input) |
| 20 | `sp_snow_step_WIC_VAL_S20_NAMED` | `WRK_WIC_VAL_S20_NAMED` — Standardised first, middle and last names pulled out; the blank-name test applied (name_missing). | `WRK_WIC_VAL_S10_ENRICHED` |
| 30 | `sp_snow_step_WIC_VAL_S30_ROUTED` | `WRK_WIC_VAL_S30_ROUTED` — Exception code, attribute name and value, new deactivation status from hub state, looked-up exception description and type, run constants, and the first-row-per-exception-key flag (uq_exc_name). Computed before publish, so routing sees the pre-run status. | `WRK_WIC_VAL_S20_NAMED` |

Step proc signatures: the step's used original params (in original order) + `P_RUN_TS`. Where an original param carries a default, `P_RUN_TS` carries `DEFAULT NULL` (Snowflake forbids a required parameter after an optional one; drivers pass all parameters positionally, so behaviour is unchanged). Each step runs its CTAS verbatim and RETURNs its row count. Step files live in `steps/` under their v2.1 names.

## Publish branches

| STEP_NO | Proc | Kind | Target | Consumes | Keeps run-ts |
|---|---|---|---|---|---|
| 40 | `sp_snow_pub_WIC_VAL_EXC_STG_BAD_REC_MEMB` | EXCEPTION | `EXC_STG_BAD_REC_MEMB` (invalid-name exceptions) | `WRK_WIC_VAL_S30_ROUTED` | N |
| 50 | `sp_snow_pub_WIC_VAL_STG_WIC_PTY_INACTIVE_LOG_DEACTIVATION` | STATUS | `STG_WIC_PTY_INACTIVE_LOG` (deactivation log rows) | `WRK_WIC_VAL_S30_ROUTED` | N |
| 60 | `sp_snow_pub_WIC_VAL_STG_WIC_PTY_INACTIVE_STS` | STATUS | `STG_WIC_PTY_INACTIVE_STS` (new deactivation-status rows) | `WRK_WIC_VAL_S30_ROUTED` | N |
| 70 | `sp_snow_pub_WIC_VAL_STG_WIC_PTY_INACTIVE_LOG_REACTIVATION` | STATUS | `STG_WIC_PTY_INACTIVE_LOG` (reactivation log rows) | `WRK_WIC_VAL_S30_ROUTED` | N |

Branch proc signatures: original params the INSERT actually uses + `P_RUN_TS` ONLY where the INSERT references the run-timestamp parameter directly (a `run_ts` column read from a step table does not count). Every other branch takes no parameters. Each branch RETURNs `SQLROWCOUNT` as `NUMBER`, with no transaction control. Branch files live in `publish/` under their v2.1 names.

## Summary flow

- The driver RETURNs `l_summary`: one line per step (row count via `fn_snow_helper36_common`), then one line per publish branch in branch order.
- The workflow runner calls all five drivers with zero arguments and concatenates their summaries under per-mapping header lines into one string, which it RETURNs.

## Preserved notes (business logic preserved, not fixed)

- Insert-only: the IDQ delete of STG_WIC_PTY_INACTIVE_STS is NOT performed. A reactivation therefore only writes a log row; the status row stays, so the party stays excluded by the downstream NOT EXISTS filters until something else removes the status row. This is the Snowflake Yes/No reactivation verdict for WIC (IDQ re-admits via Upd_Delete_Inactive, which the Snowflake code does not perform).
- Deactivation detection is pure ETL interpretation: no source deactivation flag is read. Only the blank-standardised-name test (name_missing) drives deactivation and reactivation.
- The cross-reference lookup filters on TRIM(ROWID_SYSTEM) = WIC.
- No timeline handling in this mapping (no VERSION_SEQ).
- Step 30 (and therefore the publish) is computed before any publish INSERT runs, so all routing sees the pre-run deactivation status, as in the original single INSERT ALL.
