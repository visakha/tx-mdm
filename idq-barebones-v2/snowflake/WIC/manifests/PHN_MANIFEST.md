# PHN Manifest — m_Tgt_C_S_WIC_Pty_Rle_Phn_And_EAddr, bare-bones step-driver variant (WIC ONLY)
Workflow: `wf_WIC_Stage_Load`. Base dir: `snowflake_all_barebones/WIC/`.
Install schema is `WIC_ETL_WRK` in database `MDM_ETL_WIC`; all table names are unqualified.

## Driver

```sql
sp_snow_main_m_Tgt_C_S_WIC_Pty_Rle_Phn_And_EAddr (
) RETURNS VARCHAR
```
File: `drivers/driver_sp_snow_main_m_Tgt_C_S_WIC_Pty_Rle_Phn_And_EAddr.sql`

Driver behaviour: step 5 cleanup (bare `DROP TABLE IF EXISTS`, no framework calls); step calls in order, unconditional; ONE publish transaction calling the branch procs in order, then `COMMIT`; summary lines appended per step and per branch via `fn_snow_helper36_common`; the driver RETURNs `l_summary`. Work tables are left standing at the end; the next run's step 5 drops them. Exception block: `ROLLBACK` + `RAISE` only.

## Steps

| STEP_NO | Proc | Produces | Consumes |
|---|---|---|---|
| 10 | `sp_snow_step_WIC_PHN_S10_SRC` | `WRK_WIC_PHN_S10_SRC` — Active source rows only (deactivation-status filter) plus party-role, phone and e-mail keys, standardised phone, and the e-mail validation object (NULL when e-mail is null). Only step that reads V_WIC_ETL_SRC. | (base tables — no work-table input) |
| 20 | `sp_snow_step_WIC_PHN_S20_CHECKED` | `WRK_WIC_PHN_S20_CHECKED` — Phone exception code from the area-code lookup (usage 001); standardised e-mail pulled out. | `WRK_WIC_PHN_S10_SRC` |
| 30 | `sp_snow_step_WIC_PHN_S30_ROUTED` | `WRK_WIC_PHN_S30_ROUTED` — Phone and e-mail exception descriptions, codes and types resolved; good and bad routing groups for phones and e-mails. | `WRK_WIC_PHN_S20_CHECKED` |
| 40 | `sp_snow_step_WIC_PHN_S40_READY` | `WRK_WIC_PHN_S40_READY` — Run constants (phone type Telephone, usage 001, preference Primary, e-mail type 001, status Active, valid Y) and the insert-only guards (uq_phn, uq_eaddr, uq_phone_exc, uq_email_exc). Target guards evaluated here, before publish, as in the original single query. | `WRK_WIC_PHN_S30_ROUTED` |

Step proc signatures: the step's used original params (in original order) + `P_RUN_TS`. Where an original param carries a default, `P_RUN_TS` carries `DEFAULT NULL` (Snowflake forbids a required parameter after an optional one; drivers pass all parameters positionally, so behaviour is unchanged). Each step runs its CTAS verbatim and RETURNs its row count. Step files live in `steps/` under their v2.1 names.

## Publish branches

| STEP_NO | Proc | Kind | Target | Consumes | Keeps run-ts |
|---|---|---|---|---|---|
| 50 | `sp_snow_pub_WIC_PHN_C_S_WIC_PTY_RLE_PHN` | SPINE | `C_S_WIC_PTY_RLE_PHN` (good phones) | `WRK_WIC_PHN_S40_READY` | N |
| 60 | `sp_snow_pub_WIC_PHN_EXC_STG_BAD_REC_MEMB_PHONE` | EXCEPTION | `EXC_STG_BAD_REC_MEMB` (bad-phone exceptions) | `WRK_WIC_PHN_S40_READY` | N |
| 70 | `sp_snow_pub_WIC_PHN_C_S_WIC_PTY_RLE_EADDR` | SPINE | `C_S_WIC_PTY_RLE_EADDR` (valid e-mails) | `WRK_WIC_PHN_S40_READY` | N |
| 80 | `sp_snow_pub_WIC_PHN_EXC_STG_BAD_REC_MEMB_EMAIL` | EXCEPTION | `EXC_STG_BAD_REC_MEMB` (bad-e-mail exceptions) | `WRK_WIC_PHN_S40_READY` | N |

Branch proc signatures: original params the INSERT actually uses + `P_RUN_TS` ONLY where the INSERT references the run-timestamp parameter directly (a `run_ts` column read from a step table does not count). Every other branch takes no parameters. Each branch RETURNs `SQLROWCOUNT` as `NUMBER`, with no transaction control. Branch files live in `publish/` under their v2.1 names.

## Summary flow

- The driver RETURNs `l_summary`: one line per step (row count via `fn_snow_helper36_common`), then one line per publish branch in branch order.
- The workflow runner calls all five drivers with zero arguments and concatenates their summaries under per-mapping header lines into one string, which it RETURNs.

## Preserved notes (business logic preserved, not fixed)

- Insert-only: IDQ truncates of the phone and e-mail targets are not performed.
- No null-phone filter: a party without a phone is validated and logged as an invalid phone.
- The e-mail key uses the e-mail as read (no trim).
- The phone routing groups overlap by construction: a Missing_AreaCode code counts as both good and bad, so the original INSERT ALL would write such a row to both the phone table and the exception table, and the publish INSERTs keep the same WHEN conditions (the original header notes Missing_AreaCode only exists for ECI, so WIC never gets it in practice).
- VERSION_SEQ is 1 on both targets; PERIOD_START_DATE = DATEKEY.
