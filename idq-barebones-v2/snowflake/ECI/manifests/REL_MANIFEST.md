# REL - m_Tgt_C_S_ECI_Pty_Rle_Rel (bare-bones)

Workflow: wf_ECI_Stage_Load. Driver: `sp_snow_main_m_Tgt_C_S_ECI_Pty_Rle_Rel`.

Driver signature: `sp_snow_main_m_Tgt_C_S_ECI_Pty_Rle_Rel((none))` - returns VARCHAR (the summary string).

Flow: step 5 drops the mapping's work tables; steps run unconditionally in order; publish branches run inside one transaction in order; the driver RETURNs `l_summary`. Work tables are left standing at the end of a run.

## Steps

| Step | Step name | Procedure | Produces | Consumes |
| --- | --- | --- | --- | --- |
| 10 | SRC_BOTH_DIRECTIONS | `sp_snow_step_ECI_REL_S10_SRC` | WRK_ECI_REL_S10_SRC | STG_ECI_D_FAMILY |
| 20 | KEYED_BOTH_ACTIVE | `sp_snow_step_ECI_REL_S20_KEYED` | WRK_ECI_REL_S20_KEYED | WRK_ECI_REL_S10_SRC |
| 30 | CODED_TRANSLATED | `sp_snow_step_ECI_REL_S30_TYPED` | WRK_ECI_REL_S30_TYPED | WRK_ECI_REL_S20_KEYED |
| 40 | READY_TO_PUBLISH | `sp_snow_step_ECI_REL_S40_READY` | WRK_ECI_REL_S40_READY | WRK_ECI_REL_S30_TYPED |

## Publish branches (one transaction, in order)

| Step | Branch name | Procedure | Target | Keeps P_RUN_TS |
| --- | --- | --- | --- | --- |
| 50 | PUBLISH_C_S_ECI_PTY_RLE_REL | `sp_snow_pub_ECI_REL_C_S_ECI_PTY_RLE_REL` | C_S_ECI_PTY_RLE_REL | N |
| 60 | PUBLISH_EXC_STG_BAD_REC_MEMB | `sp_snow_pub_ECI_REL_EXC_STG_BAD_REC_MEMB` | EXC_STG_BAD_REC_MEMB | N |

## Summary flow

Each step appends one `fn_snow_helper36_common` line to `l_summary`; each publish branch appends one line the same way (branch counts are captured into `l_rows` and formatted immediately, inside the transaction - no separate per-branch variables). The driver RETURNs `l_summary`; the workflow runner concatenates the nine drivers' summaries under per-mapping headers.
