# ADR Manifest — m_Tgt_C_S_WIC_Pty_Addr, bare-bones step-driver variant (WIC ONLY)
Workflow: `wf_WIC_Stage_Load`. Base dir: `snowflake_all_barebones/WIC/`.
Install schema is `WIC_ETL_WRK` in database `MDM_ETL_WIC`; all table names are unqualified.

## Driver

```sql
sp_snow_main_m_Tgt_C_S_WIC_Pty_Addr (
    P_MEMBER_HIERARCHY_CODE VARCHAR DEFAULT 'Member',  -- $Member_Hierarchy_Code
    P_MEMBER_HM_REL_TP_CD   VARCHAR DEFAULT 'Member Addr'  -- $Member_HM_REL_TP_CD
) RETURNS VARCHAR
```
File: `drivers/driver_sp_snow_main_m_Tgt_C_S_WIC_Pty_Addr.sql`

Driver behaviour: step 5 cleanup (bare `DROP TABLE IF EXISTS`, no framework calls); step calls in order, unconditional; ONE publish transaction calling the branch procs in order, then `COMMIT`; summary lines appended per step and per branch via `fn_snow_helper36_common`; the driver RETURNs `l_summary`. Work tables are left standing at the end; the next run's step 5 drops them. Exception block: `ROLLBACK` + `RAISE` only.

## Steps

| STEP_NO | Proc | Produces | Consumes |
|---|---|---|---|
| 10 | `sp_snow_step_WIC_ADR_S10_ACTIVE` | `WRK_WIC_ADDR_S10_ACTIVE` — Active source addresses only (deactivation-status filter) plus the address key. Only step that reads V_WIC_ETL_SRC. | (base tables — no work-table input) |
| 20 | `sp_snow_step_WIC_ADR_S20_VALIDATED` | `WRK_WIC_ADDR_S20_VALIDATED` — Address validation with state TX, country US, zip only; state code resolved from the state lookup. | `WRK_WIC_ADDR_S10_ACTIVE` |
| 30 | `sp_snow_step_WIC_ADR_S30_FLAT` | `WRK_WIC_ADDR_S30_FLAT` — Validation result pulled out into flat columns; match-code description resolved. | `WRK_WIC_ADDR_S20_VALIDATED` |
| 40 | `sp_snow_step_WIC_ADR_S40_SCORED` | `WRK_WIC_ADDR_S40_SCORED` — Score (100 or 40), exception detail, held address lines, run constants, and the insert-only guards (uq_addr, uq_addr_exc). Target guard evaluated here, before publish, as in the original single query. | `WRK_WIC_ADDR_S30_FLAT` |

Step proc signatures: the step's used original params (in original order) + `P_RUN_TS`. Where an original param carries a default, `P_RUN_TS` carries `DEFAULT NULL` (Snowflake forbids a required parameter after an optional one; drivers pass all parameters positionally, so behaviour is unchanged). Each step runs its CTAS verbatim and RETURNs its row count. Step files live in `steps/` under their v2.1 names.

## Publish branches

| STEP_NO | Proc | Kind | Target | Consumes | Keeps run-ts |
|---|---|---|---|---|---|
| 50 | `sp_snow_pub_WIC_ADR_DQM_ADDRESS` | VALIDATION | `DQM_ADDRESS` (every active address (address-quality table) | `WRK_WIC_ADDR_S40_SCORED` | N |
| 60 | `sp_snow_pub_WIC_ADR_C_S_WIC_PTY_RLE_ADDR` | SPINE | `C_S_WIC_PTY_RLE_ADDR` (good addresses) | `WRK_WIC_ADDR_S40_SCORED` | N |
| 70 | `sp_snow_pub_WIC_ADR_EXC_STG_BAD_REC_MEMB` | EXCEPTION | `EXC_STG_BAD_REC_MEMB` (exception addresses) | `WRK_WIC_ADDR_S40_SCORED` | N |

Branch proc signatures: original params the INSERT actually uses + `P_RUN_TS` ONLY where the INSERT references the run-timestamp parameter directly (a `run_ts` column read from a step table does not count). Every other branch takes no parameters. Each branch RETURNs `SQLROWCOUNT` as `NUMBER`, with no transaction control. Branch files live in `publish/` under their v2.1 names.

## Summary flow

- The driver RETURNs `l_summary`: one line per step (row count via `fn_snow_helper36_common`), then one line per publish branch in branch order.
- The workflow runner calls all five drivers with zero arguments and concatenates their summaries under per-mapping header lines into one string, which it RETURNs.

## Preserved notes (business logic preserved, not fixed)

- Insert-only: IDQ truncate of C_S_WIC_PTY_RLE_ADDR is not performed.
- Address type is the constant 002, so with the pass-through validator every address scores 100; exception addresses are logged only (Invalid Address per Address Doctor, Bad Value).
- Unfed ports are written as NULL, including SRC_STATE, even though TX goes to the validator.
- DQM_ADDRESS.PTY_SRC_KEY is LPAD(ID, 10, 0); the ECI-only F suffix never applies.
- VERSION_SEQ = 1; PERIOD_START_DATE and EFF_STRT_DT = DATE_ADDRESS_VALID_FROM; EFF_END_DT and PERIOD_REFERENCE_TIME are NULL.
