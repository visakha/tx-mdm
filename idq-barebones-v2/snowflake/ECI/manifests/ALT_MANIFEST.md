# ALT — m_Tgt_C_S_ECI_Pty_Rle_Alt_Id (bare-bones)

Workflow: wf_ECI_Stage_Load. Driver: `sp_snow_main_m_Tgt_C_S_ECI_Pty_Rle_Alt_Id`.

Driver signature: `sp_snow_main_m_Tgt_C_S_ECI_Pty_Rle_Alt_Id((none))` — returns VARCHAR (the summary string).

Flow: step 5 drops the mapping's work tables; steps run unconditionally in order; publish branches run inside one transaction in order; the driver RETURNs `l_summary`. Work tables are left standing at the end of a run.

## Steps

| Step | Step name | Procedure | Produces | Consumes |
| --- | --- | --- | --- | --- |
| 10 | SRC_ALT_IDS | `sp_snow_step_ECI_ALT_S10_SRC` | WRK_ECI_ALT_S10_SRC | STG_ECI_D_CHILD, STG_ECI_D_FAMILY, STG_ECI_D_MEDICAID, STG_ECI_SN_CASE |
| 20 | ACTIVE_ALT_IDS | `sp_snow_step_ECI_ALT_S20_ACTIVE` | WRK_ECI_ALT_S20_ACTIVE | WRK_ECI_ALT_S10_SRC |
| 30 | VALIDATED_ROUTED | `sp_snow_step_ECI_ALT_S30_ROUTED` | WRK_ECI_ALT_S30_ROUTED | WRK_ECI_ALT_S20_ACTIVE |
| 40 | READY_TO_PUBLISH | `sp_snow_step_ECI_ALT_S40_READY` | WRK_ECI_ALT_S40_READY | WRK_ECI_ALT_S30_ROUTED |

## Publish branches (one transaction, in order)

| Step | Branch name | Procedure | Target | Keeps P_RUN_TS |
| --- | --- | --- | --- | --- |
| 50 | PUBLISH_C_S_ECI_PTY_RLE_ALT_ID | `sp_snow_pub_ECI_ALT_C_S_ECI_PTY_RLE_ALT_ID` | C_S_ECI_PTY_RLE_ALT_ID | N |
| 60 | PUBLISH_EXC_STG_BAD_REC_MEMB_SSN | `sp_snow_pub_ECI_ALT_EXC_STG_BAD_REC_MEMB_SSN` | EXC_STG_BAD_REC_MEMB | N |
| 70 | PUBLISH_EXC_STG_BAD_REC_MEMB_MEDICAID | `sp_snow_pub_ECI_ALT_EXC_STG_BAD_REC_MEMB_MEDICAID` | EXC_STG_BAD_REC_MEMB | N |

## Summary flow

Each step appends one `fn_snow_helper36_common` line to `l_summary`; each publish branch appends one line the same way (branch counts are captured into `l_rows` and formatted immediately, inside the transaction — no separate per-branch variables). The driver RETURNs `l_summary`; the workflow runner concatenates the nine drivers' summaries under per-mapping headers.
