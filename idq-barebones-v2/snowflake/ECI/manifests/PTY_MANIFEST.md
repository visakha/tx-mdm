# PTY - m_Tgt_C_S_ECI_Pty (bare-bones)

Workflow: wf_ECI_Stage_Load. Driver: `sp_snow_main_m_Tgt_C_S_ECI_Pty`.

Driver signature: `sp_snow_main_m_Tgt_C_S_ECI_Pty(P_PTY_BO_CLASS_CD_MEMBER VARCHAR DEFAULT 'Indv', P_RLE_BO_CLASS_CD_MEMBER VARCHAR DEFAULT 'Member')` - returns VARCHAR (the summary string).

Flow: step 5 drops the mapping's work tables; steps run unconditionally in order; publish branches run inside one transaction in order; the driver RETURNs `l_summary`. Work tables are left standing at the end of a run.

## Steps

| Step | Step name | Procedure | Produces | Consumes |
| --- | --- | --- | --- | --- |
| 10 | SRC_DELTA_PARTIES | `sp_snow_step_ECI_PTY_S10_SRC` | WRK_ECI_PTY_S10_SRC | STG_ECI_D_CHILD, STG_ECI_D_FAMILY |
| 20 | ACTIVE_PARTIES | `sp_snow_step_ECI_PTY_S20_ACTIVE` | WRK_ECI_PTY_S20_ACTIVE | WRK_ECI_PTY_S10_SRC |
| 30 | DQ_RULES | `sp_snow_step_ECI_PTY_S30_DQ` | WRK_ECI_PTY_S30_DQ | WRK_ECI_PTY_S20_ACTIVE |
| 40 | DQ_EXCEPTIONS_RESOLVED | `sp_snow_step_ECI_PTY_S40_DQ2` | WRK_ECI_PTY_S40_DQ2 | WRK_ECI_PTY_S30_DQ |
| 50 | ROUTED_READY | `sp_snow_step_ECI_PTY_S50_READY` | WRK_ECI_PTY_S50_READY | WRK_ECI_PTY_S40_DQ2 |

## Publish branches (one transaction, in order)

| Step | Branch name | Procedure | Target | Keeps P_RUN_TS |
| --- | --- | --- | --- | --- |
| 60 | PUBLISH_C_S_ECI_PTY | `sp_snow_pub_ECI_PTY_C_S_ECI_PTY` | C_S_ECI_PTY | N |
| 70 | PUBLISH_C_S_ECI_PTY_RLE | `sp_snow_pub_ECI_PTY_C_S_ECI_PTY_RLE` | C_S_ECI_PTY_RLE | N |
| 80 | PUBLISH_EXC_GENDER | `sp_snow_pub_ECI_PTY_EXC_STG_BAD_REC_MEMB_GENDER` | EXC_STG_BAD_REC_MEMB | N |
| 90 | PUBLISH_EXC_BIRTH | `sp_snow_pub_ECI_PTY_EXC_STG_BAD_REC_MEMB_BIRTH` | EXC_STG_BAD_REC_MEMB | N |
| 100 | PUBLISH_EXC_ETHNICITY | `sp_snow_pub_ECI_PTY_EXC_STG_BAD_REC_MEMB_ETHNICITY` | EXC_STG_BAD_REC_MEMB | N |
| 110 | PUBLISH_EXC_RACE | `sp_snow_pub_ECI_PTY_EXC_STG_BAD_REC_MEMB_RACE` | EXC_STG_BAD_REC_MEMB | N |
| 120 | PUBLISH_EXC_LANGUAGE | `sp_snow_pub_ECI_PTY_EXC_STG_BAD_REC_MEMB_LANGUAGE` | EXC_STG_BAD_REC_MEMB | N |

## Summary flow

Each step appends one `fn_snow_helper36_common` line to `l_summary`; each publish branch appends one line the same way (branch counts are captured into `l_rows` and formatted immediately, inside the transaction - no separate per-branch variables). The driver RETURNs `l_summary`; the workflow runner concatenates the nine drivers' summaries under per-mapping headers.
