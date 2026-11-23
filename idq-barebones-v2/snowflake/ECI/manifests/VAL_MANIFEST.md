# VAL - m_Tgt_C_S_ECI_Pty_Validation (bare-bones)

Workflow: wf_ECI_Stage_Load. Driver: `sp_snow_main_m_Tgt_C_S_ECI_Pty_Validation`.

Driver signature: `sp_snow_main_m_Tgt_C_S_ECI_Pty_Validation((none))` - returns VARCHAR (the summary string).

Flow: step 5 drops the mapping's work tables; steps run unconditionally in order; publish branches run inside one transaction in order; the driver RETURNs `l_summary`. Work tables are left standing at the end of a run.

## Steps

| Step | Step name | Procedure | Produces | Consumes |
| --- | --- | --- | --- | --- |
| 10 | SRC_DELTA_PARTIES | `sp_snow_step_ECI_VAL_S10_SRC` | WRK_ECI_VAL_S10_SRC | STG_ECI_D_CHILD, STG_ECI_D_FAMILY |
| 20 | ENRICHED_STD_NAMES | `sp_snow_step_ECI_VAL_S20_ENRICHED` | WRK_ECI_VAL_S20_ENRICHED | WRK_ECI_VAL_S10_SRC |
| 30 | ROUTED_GROUPS | `sp_snow_step_ECI_VAL_S30_ROUTED` | WRK_ECI_VAL_S30_ROUTED | WRK_ECI_VAL_S20_ENRICHED |

## Publish branches (one transaction, in order)

| Step | Branch name | Procedure | Target | Keeps P_RUN_TS |
| --- | --- | --- | --- | --- |
| 40 | PUBLISH_EXC_STG_BAD_REC_MEMB | `sp_snow_pub_ECI_VAL_EXC_STG_BAD_REC_MEMB` | EXC_STG_BAD_REC_MEMB | N |
| 50 | PUBLISH_STG_ECI_PTY_INACTIVE_LOG_DEACTIVATION | `sp_snow_pub_ECI_VAL_STG_ECI_PTY_INACTIVE_LOG_DEACTIVATION` | STG_ECI_PTY_INACTIVE_LOG | N |
| 60 | PUBLISH_STG_ECI_PTY_INACTIVE_STS | `sp_snow_pub_ECI_VAL_STG_ECI_PTY_INACTIVE_STS` | STG_ECI_PTY_INACTIVE_STS | N |
| 70 | PUBLISH_STG_ECI_PTY_INACTIVE_LOG_REACTIVATION | `sp_snow_pub_ECI_VAL_STG_ECI_PTY_INACTIVE_LOG_REACTIVATION` | STG_ECI_PTY_INACTIVE_LOG | N |

## Summary flow

Each step appends one `fn_snow_helper36_common` line to `l_summary`; each publish branch appends one line the same way (branch counts are captured into `l_rows` and formatted immediately, inside the transaction - no separate per-branch variables). The driver RETURNs `l_summary`; the workflow runner concatenates the nine drivers' summaries under per-mapping headers.
