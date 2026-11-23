# RFM — m_Tgt_Stg_ECI_Pty_Reactivation_D_Medicaid (bare-bones)

Workflow: wf_ECI_Stage_Load. Driver: `sp_snow_main_m_Tgt_Stg_ECI_Pty_Reactivation_D_Medicaid`.

Driver signature: `sp_snow_main_m_Tgt_Stg_ECI_Pty_Reactivation_D_Medicaid(P_TEST_LOOKUP_RESULT VARCHAR DEFAULT 'N')` — returns VARCHAR (the summary string).

Flow: step 5 drops the mapping's work tables; steps run unconditionally in order; publish branches run inside one transaction in order; the driver RETURNs `l_summary`. Work tables are left standing at the end of a run.

## Steps

| Step | Step name | Procedure | Produces | Consumes |
| --- | --- | --- | --- | --- |
| 10 | LATEST_HISTORY_ROWS | `sp_snow_step_ECI_RFM_S10_LATEST` | WRK_ECI_RFM_S10_LATEST | STG_ECI_D_MEDICAID, STG_ECI_H_MEDICAID, STG_ECI_SN_CASE, V_ECI_ETL_LU_REACTIVATED_ID |
| 20 | KEEP_NEW_ONLY | `sp_snow_step_ECI_RFM_S20_KEEPNEW` | WRK_ECI_RFM_S20_KEEPNEW | WRK_ECI_RFM_S10_LATEST |

## Publish branches (one transaction, in order)

| Step | Branch name | Procedure | Target | Keeps P_RUN_TS |
| --- | --- | --- | --- | --- |
| 30 | PUBLISH_STG_ECI_D_MEDICAID | `sp_snow_pub_ECI_RFM_STG_ECI_D_MEDICAID` | STG_ECI_D_MEDICAID | N |

## Summary flow

Each step appends one `fn_snow_helper36_common` line to `l_summary`; each publish branch appends one line the same way (branch counts are captured into `l_rows` and formatted immediately, inside the transaction — no separate per-branch variables). The driver RETURNs `l_summary`; the workflow runner concatenates the nine drivers' summaries under per-mapping headers.
