# ALT Manifest — m_Tgt_C_S_WIC_Pty_Rle_Alt_Id, bare-bones step-driver variant (WIC ONLY)
Workflow: `wf_WIC_Stage_Load`. Base dir: `snowflake_all_barebones/WIC/`.
Install schema is `WIC_ETL_WRK` in database `MDM_ETL_WIC`; all table names are unqualified.

## Driver

```sql
sp_snow_main_m_Tgt_C_S_WIC_Pty_Rle_Alt_Id (
) RETURNS VARCHAR
```
File: `drivers/driver_sp_snow_main_m_Tgt_C_S_WIC_Pty_Rle_Alt_Id.sql`

Driver behaviour: step 5 cleanup (bare `DROP TABLE IF EXISTS`, no framework calls); step calls in order, unconditional; ONE publish transaction calling the branch procs in order, then `COMMIT`; summary lines appended per step and per branch via `fn_snow_helper36_common`; the driver RETURNs `l_summary`. Work tables are left standing at the end; the next run's step 5 drops them. Exception block: `ROLLBACK` + `RAISE` only.

## Steps

| STEP_NO | Proc | Produces | Consumes |
|---|---|---|---|
| 10 | `sp_snow_step_WIC_ALT_S10_KEYS` | `WRK_WIC_ALT_S10_KEYS` — Party-role key, id type (020 or 021), alternate-id key. Only step that reads V_WIC_ETL_SRC. | (base tables — no work-table input) |
| 20 | `sp_snow_step_WIC_ALT_S20_READY` | `WRK_WIC_ALT_S20_READY` — Deactivation filter applied, keys already in the target skipped, one row per alternate-id key (latest DATEKEY wins). Guard evaluated here, before publish, as in the original single query. | `WRK_WIC_ALT_S10_KEYS` |

Step proc signatures: the step's used original params (in original order) + `P_RUN_TS`. Where an original param carries a default, `P_RUN_TS` carries `DEFAULT NULL` (Snowflake forbids a required parameter after an optional one; drivers pass all parameters positionally, so behaviour is unchanged). Each step runs its CTAS verbatim and RETURNs its row count. Step files live in `steps/` under their v2.1 names.

## Publish branches

| STEP_NO | Proc | Kind | Target | Consumes | Keeps run-ts |
|---|---|---|---|---|---|
| 30 | `sp_snow_pub_WIC_ALT_C_S_WIC_PTY_RLE_ALT_ID` | SPINE | `C_S_WIC_PTY_RLE_ALT_ID` (one alternate id per active party) | `WRK_WIC_ALT_S20_READY` | Y |

Branch proc signatures: original params the INSERT actually uses + `P_RUN_TS` ONLY where the INSERT references the run-timestamp parameter directly (a `run_ts` column read from a step table does not count). Every other branch takes no parameters. Each branch RETURNs `SQLROWCOUNT` as `NUMBER`, with no transaction control. Branch files live in `publish/` under their v2.1 names.

## Summary flow

- The driver RETURNs `l_summary`: one line per step (row count via `fn_snow_helper36_common`), then one line per publish branch in branch order.
- The workflow runner calls all five drivers with zero arguments and concatenates their summaries under per-mapping header lines into one string, which it RETURNs.

## Preserved notes (business logic preserved, not fixed)

- Thin split, flagged in the multisource step map: this original has no CTE chain, it is a single query (an inner derived table plus an outer SELECT). Step 10 builds the keys (the original inner derived table) and step 20 applies the deactivation filter, the already-loaded guard and the one-row-per-key rank (the original outer SELECT). No business expression was changed.
- Insert-only: IDQ truncate of C_S_WIC_PTY_RLE_ALT_ID is not performed.
- HUB_STATE_IND is not linked (left to the column default).
- VERSION_SEQ = 1; PERIOD_START_DATE = DATEKEY; no validation rule runs in this mapping.
- The publish INSERT uses the run timestamp directly (not a materialised run_ts column), so this publish proc is the one WIC publish proc in which P_RUN_TS is actually used in the body.
