# PHN - m_Tgt_C_S_ECI_Pty_Rle_Phn_And_EAddr (bare-bones)

Workflow: wf_ECI_Stage_Load. Driver: `sp_snow_main_m_Tgt_C_S_ECI_Pty_Rle_Phn_And_EAddr`.

Driver signature: `sp_snow_main_m_Tgt_C_S_ECI_Pty_Rle_Phn_And_EAddr((none))` - returns VARCHAR (the summary string).

Flow: step 5 drops the mapping's work tables; steps run unconditionally in order; publish branches run inside one transaction in order; the driver RETURNs `l_summary`. Work tables are left standing at the end of a run.

## Steps

| Step | Step name | Procedure | Produces | Consumes |
| --- | --- | --- | --- | --- |
| 10 | SRC_PHN_EADDR | `sp_snow_step_ECI_PHN_S10_SRC` | WRK_ECI_PHN_S10_SRC | V_ECI_ETL_SRC_FAMILY_PHONE |
| 20 | ACTIVE_PHN_EADDR | `sp_snow_step_ECI_PHN_S20_ACTIVE` | WRK_ECI_PHN_S20_ACTIVE | WRK_ECI_PHN_S10_SRC |
| 30 | DQ_CLEAN_VALIDATE | `sp_snow_step_ECI_PHN_S30_DQ` | WRK_ECI_PHN_S30_DQ | WRK_ECI_PHN_S20_ACTIVE |
| 40 | ROUTED_GROUPS | `sp_snow_step_ECI_PHN_S40_ROUTED` | WRK_ECI_PHN_S40_ROUTED | WRK_ECI_PHN_S30_DQ |
| 50 | READY_TO_PUBLISH | `sp_snow_step_ECI_PHN_S50_READY` | WRK_ECI_PHN_S50_READY | WRK_ECI_PHN_S40_ROUTED |

## Publish branches (one transaction, in order)

| Step | Branch name | Procedure | Target | Keeps P_RUN_TS |
| --- | --- | --- | --- | --- |
| 60 | PUBLISH_C_S_ECI_PTY_RLE_PHN | `sp_snow_pub_ECI_PHN_C_S_ECI_PTY_RLE_PHN` | C_S_ECI_PTY_RLE_PHN | N |
| 70 | PUBLISH_EXC_STG_BAD_REC_MEMB_PHONE | `sp_snow_pub_ECI_PHN_EXC_STG_BAD_REC_MEMB_PHONE` | EXC_STG_BAD_REC_MEMB | N |
| 80 | PUBLISH_C_S_ECI_PTY_RLE_EADDR | `sp_snow_pub_ECI_PHN_C_S_ECI_PTY_RLE_EADDR` | C_S_ECI_PTY_RLE_EADDR | N |
| 90 | PUBLISH_EXC_STG_BAD_REC_MEMB_EMAIL | `sp_snow_pub_ECI_PHN_EXC_STG_BAD_REC_MEMB_EMAIL` | EXC_STG_BAD_REC_MEMB | N |

## Summary flow

Each step appends one `fn_snow_helper36_common` line to `l_summary`; each publish branch appends one line the same way (branch counts are captured into `l_rows` and formatted immediately, inside the transaction - no separate per-branch variables). The driver RETURNs `l_summary`; the workflow runner concatenates the nine drivers' summaries under per-mapping headers.
