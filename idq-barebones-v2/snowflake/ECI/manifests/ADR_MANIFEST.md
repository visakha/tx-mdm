# ADR — m_Tgt_C_S_ECI_Pty_Addr (bare-bones)

Workflow: wf_ECI_Stage_Load. Driver: `sp_snow_main_m_Tgt_C_S_ECI_Pty_Addr`.

Driver signature: `sp_snow_main_m_Tgt_C_S_ECI_Pty_Addr(P_MEMBER_HIERARCHY_CODE VARCHAR DEFAULT 'Member', P_MEMBER_HM_REL_TP_CD VARCHAR DEFAULT 'Member Addr')` — returns VARCHAR (the summary string).

Flow: step 5 drops the mapping's work tables; steps run unconditionally in order; publish branches run inside one transaction in order; the driver RETURNs `l_summary`. Work tables are left standing at the end of a run.

## Steps

| Step | Step name | Procedure | Produces | Consumes |
| --- | --- | --- | --- | --- |
| 10 | SRC_ADDRESSES | `sp_snow_step_ECI_ADR_S10_SRC` | WRK_ECI_ADR_S10_SRC | V_ECI_ETL_SRC_FAMILY_ADDRESS |
| 20 | KEYED_ACTIVE | `sp_snow_step_ECI_ADR_S20_KEYED` | WRK_ECI_ADR_S20_KEYED | WRK_ECI_ADR_S10_SRC |
| 30 | ADDR_VALIDATION | `sp_snow_step_ECI_ADR_S30_VALIDATED` | WRK_ECI_ADR_S30_VALIDATED | WRK_ECI_ADR_S20_KEYED |
| 40 | FLAT_VALIDATION | `sp_snow_step_ECI_ADR_S40_FLAT` | WRK_ECI_ADR_S40_FLAT | WRK_ECI_ADR_S30_VALIDATED |
| 50 | SCORED_READY | `sp_snow_step_ECI_ADR_S50_READY` | WRK_ECI_ADR_S50_READY | WRK_ECI_ADR_S40_FLAT |

## Publish branches (one transaction, in order)

| Step | Branch name | Procedure | Target | Keeps P_RUN_TS |
| --- | --- | --- | --- | --- |
| 60 | PUBLISH_DQM_ADDRESS | `sp_snow_pub_ECI_ADR_DQM_ADDRESS` | DQM_ADDRESS | N |
| 70 | PUBLISH_C_S_ECI_PTY_RLE_ADDR | `sp_snow_pub_ECI_ADR_C_S_ECI_PTY_RLE_ADDR` | C_S_ECI_PTY_RLE_ADDR | N |
| 80 | PUBLISH_EXC_STG_BAD_REC_MEMB | `sp_snow_pub_ECI_ADR_EXC_STG_BAD_REC_MEMB` | EXC_STG_BAD_REC_MEMB | N |

## Summary flow

Each step appends one `fn_snow_helper36_common` line to `l_summary`; each publish branch appends one line the same way (branch counts are captured into `l_rows` and formatted immediately, inside the transaction — no separate per-branch variables). The driver RETURNs `l_summary`; the workflow runner concatenates the nine drivers' summaries under per-mapping headers.
