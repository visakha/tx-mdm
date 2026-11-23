# STEP_MAP — bare-bones step maps (all sources)

Step maps for all 40 mappings, same maps as v2.1 minus checkpoint/config columns. Assembled from the per-source fragments (content unchanged).

---

# STEP_MAP_TRS — TRS bare-bones step-driver maps (all 15 mappings)

Bare-bones fragment for coordinator assembly. Same step maps as the v2.1
TRS step map, minus completion-record and run-config columns. No run-config
table, no job-control calls, no flags: every step runs unconditionally.

## Notes (apply to every mapping below)

- **Step 5:** `CLEANUP_PREVIOUS_RUN` — bare `DROP TABLE IF EXISTS` for
  that mapping's own work tables only. Every run rebuilds all steps from
  scratch; there is no step-level resume.
- **Publish:** the only step that writes to final targets and the only
  step inside an explicit transaction (one transaction, all branches,
  or nothing). First branch takes the current publish step number,
  +10 per branch. Work tables are TRANSIENT, are NOT dropped at the end
  of a run, and are left standing until the next run of the same mapping
  cleans them up at its step 5. No cursors, no cleanup procedure, no
  end-of-run drops.
- **PTYDEACT step 50** (`DELETE_VALID_STAGE_NOT_PERFORMED`) is a
  no-data record step, called after publish: it writes NO data (see its
  manifest). It is the only non-CTAS, non-publish unit.
- **Summary:** the driver RETURNs one summary string; the workflow runner
  concatenates the per-mapping summaries with header lines.

## All units

| Mapping | Workflow | STEP_NO | Step name | Proc | Kind | Target / work table | Consumes |
|---|---|---|---|---|---|---|---|
| m_Tgt_C_S_TRS_Pty_OnGoing | wf_TRS_Stage_Load_1_Ongoing | 10 | SRC_VALID_LIST | `sp_snow_step_TRS_PTY_S10_SRC` | TRANSFORM | `WRK_TRS_PTY_S1_SRC` | (base tables only) |
| m_Tgt_C_S_TRS_Pty_OnGoing | wf_TRS_Stage_Load_1_Ongoing | 20 | DQ_STANDARDISE_VALIDATE | `sp_snow_step_TRS_PTY_S20_DQ` | TRANSFORM | `WRK_TRS_PTY_S2_DQ` | WRK_TRS_PTY_S1_SRC |
| m_Tgt_C_S_TRS_Pty_OnGoing | wf_TRS_Stage_Load_1_Ongoing | 30 | ROUTER_EXCEPTIONS | `sp_snow_step_TRS_PTY_S30_ROUTER` | TRANSFORM | `WRK_TRS_PTY_S3_ROUTER` | WRK_TRS_PTY_S2_DQ |
| m_Tgt_C_S_TRS_Pty_OnGoing | wf_TRS_Stage_Load_1_Ongoing | 40 | DEDUP_VALID | `sp_snow_step_TRS_PTY_S40_DEDUP` | TRANSFORM | `WRK_TRS_PTY_S4_DEDUP` | WRK_TRS_PTY_S2_DQ |
| m_Tgt_C_S_TRS_Pty_OnGoing | wf_TRS_Stage_Load_1_Ongoing | 50 | PUBLISH_EXC_NAME | `sp_snow_pub_TRS_PTY_EXC_STG_BAD_REC_MEMB_NAME` | EXCEPTION | `EXC_STG_BAD_REC_MEMB` | WRK_TRS_PTY_S3_ROUTER |
| m_Tgt_C_S_TRS_Pty_OnGoing | wf_TRS_Stage_Load_1_Ongoing | 60 | PUBLISH_EXC_GENDER | `sp_snow_pub_TRS_PTY_EXC_STG_BAD_REC_MEMB_GENDER` | EXCEPTION | `EXC_STG_BAD_REC_MEMB` | WRK_TRS_PTY_S3_ROUTER |
| m_Tgt_C_S_TRS_Pty_OnGoing | wf_TRS_Stage_Load_1_Ongoing | 70 | PUBLISH_EXC_DEATH | `sp_snow_pub_TRS_PTY_EXC_STG_BAD_REC_MEMB_DEATH` | EXCEPTION | `EXC_STG_BAD_REC_MEMB` | WRK_TRS_PTY_S3_ROUTER |
| m_Tgt_C_S_TRS_Pty_OnGoing | wf_TRS_Stage_Load_1_Ongoing | 80 | PUBLISH_EXC_BIRTH | `sp_snow_pub_TRS_PTY_EXC_STG_BAD_REC_MEMB_BIRTH` | EXCEPTION | `EXC_STG_BAD_REC_MEMB` | WRK_TRS_PTY_S3_ROUTER |
| m_Tgt_C_S_TRS_Pty_OnGoing | wf_TRS_Stage_Load_1_Ongoing | 90 | PUBLISH_C_S_TRS_PTY | `sp_snow_pub_TRS_PTY_C_S_TRS_PTY` | SPINE | `C_S_TRS_PTY` | WRK_TRS_PTY_S4_DEDUP |
| m_Tgt_C_S_TRS_Pty_OnGoing | wf_TRS_Stage_Load_1_Ongoing | 100 | PUBLISH_C_S_TRS_PTY_RLE | `sp_snow_pub_TRS_PTY_C_S_TRS_PTY_RLE` | SPINE | `C_S_TRS_PTY_RLE` | WRK_TRS_PTY_S4_DEDUP |
| m_Tgt_C_S_TRS_Pty_OnGoing | wf_TRS_Stage_Load_1_Ongoing | 110 | PUBLISH_STG_TRS_VALID_MEMBERS | `sp_snow_pub_TRS_PTY_STG_TRS_VALID_MEMBERS` | SPINE | `STG_TRS_VALID_MEMBERS` | WRK_TRS_PTY_S4_DEDUP |
| m_Tgt_C_S_TRS_Pty_OnGoing | wf_TRS_Stage_Load_1_Ongoing | 120 | PUBLISH_EXC_RACE | `sp_snow_pub_TRS_PTY_EXC_STG_BAD_REC_MEMB_RACE` | EXCEPTION | `EXC_STG_BAD_REC_MEMB` | WRK_TRS_PTY_S4_DEDUP |
| m_Tgt_C_S_TRS_Pty_OnGoing | wf_TRS_Stage_Load_1_Ongoing | 130 | PUBLISH_EXC_ETHNICITY | `sp_snow_pub_TRS_PTY_EXC_STG_BAD_REC_MEMB_ETHNICITY` | EXCEPTION | `EXC_STG_BAD_REC_MEMB` | WRK_TRS_PTY_S4_DEDUP |
| m_Tgt_C_S_TRS_Pty_Deactivation_1 | wf_TRS_Stage_Load_1_Ongoing | 10 | DEACTIVATED_INDIVIDUALS | `sp_snow_step_TRS_PTYDEACT_S10_DEACTV` | TRANSFORM | `WRK_TRS_DEACT1_S10_DEACTV` | (base tables only) |
| m_Tgt_C_S_TRS_Pty_Deactivation_1 | wf_TRS_Stage_Load_1_Ongoing | 20 | DEACTIVATED_PER_INDIVIDUAL | `sp_snow_step_TRS_PTYDEACT_S20_DEACTV_ID` | TRANSFORM | `WRK_TRS_DEACT1_S20_DEACTV_ID` | WRK_TRS_DEACT1_S10_DEACTV |
| m_Tgt_C_S_TRS_Pty_Deactivation_1 | wf_TRS_Stage_Load_1_Ongoing | 30 | READY_TO_PUBLISH | `sp_snow_step_TRS_PTYDEACT_S30_READY` | TRANSFORM | `WRK_TRS_DEACT1_S30_READY` | WRK_TRS_DEACT1_S20_DEACTV_ID |
| m_Tgt_C_S_TRS_Pty_Deactivation_1 | wf_TRS_Stage_Load_1_Ongoing | 40 | PUBLISH_STG_TRS_DEACTIVED_MEMBERS | `sp_snow_pub_TRS_PTYDEACT_STG_TRS_DEACTIVED_MEMBERS` | STATUS | `STG_TRS_DEACTIVED_MEMBERS` | WRK_TRS_DEACT1_S30_READY |
| m_Tgt_C_S_TRS_Pty_Deactivation_1 | wf_TRS_Stage_Load_1_Ongoing | 50 | DELETE_VALID_STAGE_NOT_PERFORMED | `sp_snow_step_TRS_PTYDEACT_S50_NOTPERFORMED` | STATUS | (no table; no data written) | (none) |
| m_Tgt_C_S_TRS_Pty_Rle_TOA | wf_TRS_Stage_Load_1_Ongoing | 10 | TOA_SRC_RANKED | `sp_snow_step_TRS_TOA_S10_RAW` | TRANSFORM | `WRK_TRS_TOA_S10_RAW` | (base tables only) |
| m_Tgt_C_S_TRS_Pty_Rle_TOA | wf_TRS_Stage_Load_1_Ongoing | 20 | TOA_LATEST | `sp_snow_step_TRS_TOA_S20_LATEST` | TRANSFORM | `WRK_TRS_TOA_S20_SRC` | WRK_TRS_TOA_S10_RAW |
| m_Tgt_C_S_TRS_Pty_Rle_TOA | wf_TRS_Stage_Load_1_Ongoing | 30 | TOA_KEYED | `sp_snow_step_TRS_TOA_S30_KEYED` | TRANSFORM | `WRK_TRS_TOA_S30_KEYED` | WRK_TRS_TOA_S20_SRC |
| m_Tgt_C_S_TRS_Pty_Rle_TOA | wf_TRS_Stage_Load_1_Ongoing | 40 | TOA_RANKED | `sp_snow_step_TRS_TOA_S40_RANKED` | TRANSFORM | `WRK_TRS_TOA_S40_RANKED` | WRK_TRS_TOA_S30_KEYED |
| m_Tgt_C_S_TRS_Pty_Rle_TOA | wf_TRS_Stage_Load_1_Ongoing | 50 | PUBLISH_EXC_BAD_VALUE | `sp_snow_pub_TRS_TOA_EXC_STG_BAD_REC_MEMB_BAD_VALUE` | EXCEPTION | `EXC_STG_BAD_REC_MEMB` | WRK_TRS_TOA_S40_RANKED |
| m_Tgt_C_S_TRS_Pty_Rle_TOA | wf_TRS_Stage_Load_1_Ongoing | 60 | PUBLISH_EXC_DATES | `sp_snow_pub_TRS_TOA_EXC_STG_BAD_REC_MEMB_DATES` | EXCEPTION | `EXC_STG_BAD_REC_MEMB` | WRK_TRS_TOA_S40_RANKED |
| m_Tgt_C_S_TRS_Pty_Rle_TOA | wf_TRS_Stage_Load_1_Ongoing | 70 | PUBLISH_C_S_TRS_PTY_RLE_TOA | `sp_snow_pub_TRS_TOA_C_S_TRS_PTY_RLE_TOA` | SPINE | `C_S_TRS_PTY_RLE_TOA` | WRK_TRS_TOA_S40_RANKED |
| m_Tgt_C_S_TRS_Pty_Rle_Rel_1_Mem_To_Mem | wf_TRS_Stage_Load_1_Ongoing | 10 | SRC_RELATIONSHIPS | `sp_snow_step_TRS_REL1_S10_SRC` | TRANSFORM | `WRK_TRS_REL1_S1_SRC` | (base tables only) |
| m_Tgt_C_S_TRS_Pty_Rle_Rel_1_Mem_To_Mem | wf_TRS_Stage_Load_1_Ongoing | 20 | KEYED | `sp_snow_step_TRS_REL1_S20_KEYED` | TRANSFORM | `WRK_TRS_REL1_S2_KEYED` | WRK_TRS_REL1_S1_SRC |
| m_Tgt_C_S_TRS_Pty_Rle_Rel_1_Mem_To_Mem | wf_TRS_Stage_Load_1_Ongoing | 30 | ROUTER_EXCEPTIONS | `sp_snow_step_TRS_REL1_S30_ROUTER` | TRANSFORM | `WRK_TRS_REL1_S3_ROUTER` | WRK_TRS_REL1_S2_KEYED |
| m_Tgt_C_S_TRS_Pty_Rle_Rel_1_Mem_To_Mem | wf_TRS_Stage_Load_1_Ongoing | 40 | CONSOLIDATED | `sp_snow_step_TRS_REL1_S40_CONSOL` | TRANSFORM | `WRK_TRS_REL1_S4_CONSOL` | WRK_TRS_REL1_S2_KEYED |
| m_Tgt_C_S_TRS_Pty_Rle_Rel_1_Mem_To_Mem | wf_TRS_Stage_Load_1_Ongoing | 50 | PREPARED | `sp_snow_step_TRS_REL1_S50_PREP` | TRANSFORM | `WRK_TRS_REL1_S5_PREP` | WRK_TRS_REL1_S4_CONSOL |
| m_Tgt_C_S_TRS_Pty_Rle_Rel_1_Mem_To_Mem | wf_TRS_Stage_Load_1_Ongoing | 60 | TIMELINE | `sp_snow_step_TRS_REL1_S60_TIMELINE` | TRANSFORM | `WRK_TRS_REL1_S6_TIMELINE` | WRK_TRS_REL1_S5_PREP |
| m_Tgt_C_S_TRS_Pty_Rle_Rel_1_Mem_To_Mem | wf_TRS_Stage_Load_1_Ongoing | 70 | PUBLISH_EXC_MAIN_ALT_ID | `sp_snow_pub_TRS_REL1_EXC_STG_BAD_REC_MEMB_MAIN_ALT_ID` | EXCEPTION | `EXC_STG_BAD_REC_MEMB` | WRK_TRS_REL1_S3_ROUTER |
| m_Tgt_C_S_TRS_Pty_Rle_Rel_1_Mem_To_Mem | wf_TRS_Stage_Load_1_Ongoing | 80 | PUBLISH_EXC_REF_ALT_ID | `sp_snow_pub_TRS_REL1_EXC_STG_BAD_REC_MEMB_REF_ALT_ID` | EXCEPTION | `EXC_STG_BAD_REC_MEMB` | WRK_TRS_REL1_S3_ROUTER |
| m_Tgt_C_S_TRS_Pty_Rle_Rel_1_Mem_To_Mem | wf_TRS_Stage_Load_1_Ongoing | 90 | PUBLISH_EXC_LOOKUP | `sp_snow_pub_TRS_REL1_EXC_STG_BAD_REC_MEMB_LOOKUP` | EXCEPTION | `EXC_STG_BAD_REC_MEMB` | WRK_TRS_REL1_S3_ROUTER |
| m_Tgt_C_S_TRS_Pty_Rle_Rel_1_Mem_To_Mem | wf_TRS_Stage_Load_1_Ongoing | 100 | PUBLISH_EXC_DATES | `sp_snow_pub_TRS_REL1_EXC_STG_BAD_REC_MEMB_DATES` | EXCEPTION | `EXC_STG_BAD_REC_MEMB` | WRK_TRS_REL1_S3_ROUTER |
| m_Tgt_C_S_TRS_Pty_Rle_Rel_1_Mem_To_Mem | wf_TRS_Stage_Load_1_Ongoing | 110 | PUBLISH_C_S_TRS_PTY_RLE_REL | `sp_snow_pub_TRS_REL1_C_S_TRS_PTY_RLE_REL` | SPINE | `C_S_TRS_PTY_RLE_REL` | WRK_TRS_REL1_S6_TIMELINE |
| m_Tgt_C_S_TRS_Pty_Rle_Rel_DeActivation_1 | wf_TRS_Stage_Load_1_Ongoing | 10 | MIN_PK | `sp_snow_step_TRS_RELDEACT_S10_MINPK` | TRANSFORM | `WRK_TRS_RELDEACT_S10_MINPK` | (base tables only) |
| m_Tgt_C_S_TRS_Pty_Rle_Rel_DeActivation_1 | wf_TRS_Stage_Load_1_Ongoing | 20 | REL_SRC | `sp_snow_step_TRS_RELDEACT_S20_SRC` | TRANSFORM | `WRK_TRS_RELDEACT_S20_SRC` | WRK_TRS_RELDEACT_S10_MINPK |
| m_Tgt_C_S_TRS_Pty_Rle_Rel_DeActivation_1 | wf_TRS_Stage_Load_1_Ongoing | 30 | KEYED_REL | `sp_snow_step_TRS_RELDEACT_S30_KEYED` | TRANSFORM | `WRK_TRS_RELDEACT_S30_KEYED` | WRK_TRS_RELDEACT_S20_SRC |
| m_Tgt_C_S_TRS_Pty_Rle_Rel_DeActivation_1 | wf_TRS_Stage_Load_1_Ongoing | 40 | XREF_ONE | `sp_snow_step_TRS_RELDEACT_S40_XREF` | TRANSFORM | `WRK_TRS_RELDEACT_S40_XREF` | (base tables only) |
| m_Tgt_C_S_TRS_Pty_Rle_Rel_DeActivation_1 | wf_TRS_Stage_Load_1_Ongoing | 50 | READY_TO_PUBLISH | `sp_snow_step_TRS_RELDEACT_S50_READY` | TRANSFORM | `WRK_TRS_RELDEACT_S50_READY` | WRK_TRS_RELDEACT_S30_KEYED|WRK_TRS_RELDEACT_S40_XREF |
| m_Tgt_C_S_TRS_Pty_Rle_Rel_DeActivation_1 | wf_TRS_Stage_Load_1_Ongoing | 60 | PUBLISH_STG_TRS_DEACTIVATED_RELATIONSHIPS | `sp_snow_pub_TRS_RELDEACT_STG_TRS_DEACTIVATED_RELATIONSHIPS` | STATUS | `STG_TRS_DEACTIVATED_RELATIONSHIPS` | WRK_TRS_RELDEACT_S50_READY |
| m_Tgt_C_S_TRS_Pty_Rle_Rel_2_Mem_To_PCP | wf_TRS_Stage_Load_1_Ongoing | 10 | SRC_MANAGED_CARE | `sp_snow_step_TRS_REL2_S10_SRC` | TRANSFORM | `WRK_TRS_REL2_S1_SRC` | (base tables only) |
| m_Tgt_C_S_TRS_Pty_Rle_Rel_2_Mem_To_PCP | wf_TRS_Stage_Load_1_Ongoing | 20 | KEYED | `sp_snow_step_TRS_REL2_S20_KEYED` | TRANSFORM | `WRK_TRS_REL2_S2_KEYED` | WRK_TRS_REL2_S1_SRC |
| m_Tgt_C_S_TRS_Pty_Rle_Rel_2_Mem_To_PCP | wf_TRS_Stage_Load_1_Ongoing | 30 | ROUTER_EXCEPTIONS | `sp_snow_step_TRS_REL2_S30_ROUTER` | TRANSFORM | `WRK_TRS_REL2_S3_ROUTER` | WRK_TRS_REL2_S2_KEYED |
| m_Tgt_C_S_TRS_Pty_Rle_Rel_2_Mem_To_PCP | wf_TRS_Stage_Load_1_Ongoing | 40 | CONSOLIDATED | `sp_snow_step_TRS_REL2_S40_CONSOL` | TRANSFORM | `WRK_TRS_REL2_S4_CONSOL` | WRK_TRS_REL2_S2_KEYED |
| m_Tgt_C_S_TRS_Pty_Rle_Rel_2_Mem_To_PCP | wf_TRS_Stage_Load_1_Ongoing | 50 | PREPARED | `sp_snow_step_TRS_REL2_S50_PREP` | TRANSFORM | `WRK_TRS_REL2_S5_PREP` | WRK_TRS_REL2_S4_CONSOL |
| m_Tgt_C_S_TRS_Pty_Rle_Rel_2_Mem_To_PCP | wf_TRS_Stage_Load_1_Ongoing | 60 | TIMELINE | `sp_snow_step_TRS_REL2_S60_TIMELINE` | TRANSFORM | `WRK_TRS_REL2_S6_TIMELINE` | WRK_TRS_REL2_S5_PREP |
| m_Tgt_C_S_TRS_Pty_Rle_Rel_2_Mem_To_PCP | wf_TRS_Stage_Load_1_Ongoing | 70 | PUBLISH_EXC_DATES | `sp_snow_pub_TRS_REL2_EXC_STG_BAD_REC_MEMB_DATES` | EXCEPTION | `EXC_STG_BAD_REC_MEMB` | WRK_TRS_REL2_S3_ROUTER |
| m_Tgt_C_S_TRS_Pty_Rle_Rel_2_Mem_To_PCP | wf_TRS_Stage_Load_1_Ongoing | 80 | PUBLISH_EXC_DEFAULT | `sp_snow_pub_TRS_REL2_EXC_STG_BAD_REC_MEMB_DEFAULT` | EXCEPTION | `EXC_STG_BAD_REC_MEMB` | WRK_TRS_REL2_S3_ROUTER |
| m_Tgt_C_S_TRS_Pty_Rle_Rel_2_Mem_To_PCP | wf_TRS_Stage_Load_1_Ongoing | 90 | PUBLISH_C_S_TRS_PTY_RLE_REL_PROV | `sp_snow_pub_TRS_REL2_C_S_TRS_PTY_RLE_REL_PROV` | SPINE | `C_S_TRS_PTY_RLE_REL_PROV` | WRK_TRS_REL2_S6_TIMELINE |
| m_Tgt_C_S_TRS_Pty_Rle_Phn_And_EAddr | wf_TRS_Stage_Load_1_Ongoing | 10 | SRC_CASE_DELTA | `sp_snow_step_TRS_PHN_S10_SRC` | TRANSFORM | `WRK_TRS_PHN_S1_SRC` | (base tables only) |
| m_Tgt_C_S_TRS_Pty_Rle_Phn_And_EAddr | wf_TRS_Stage_Load_1_Ongoing | 20 | PHONE_SLOTS | `sp_snow_step_TRS_PHN_S20_SLOTS` | TRANSFORM | `WRK_TRS_PHN_S2_SLOTS` | WRK_TRS_PHN_S1_SRC |
| m_Tgt_C_S_TRS_Pty_Rle_Phn_And_EAddr | wf_TRS_Stage_Load_1_Ongoing | 30 | PHONES_CHECKED | `sp_snow_step_TRS_PHN_S30_CHECKED` | TRANSFORM | `WRK_TRS_PHN_S3_CHECKED` | WRK_TRS_PHN_S2_SLOTS |
| m_Tgt_C_S_TRS_Pty_Rle_Phn_And_EAddr | wf_TRS_Stage_Load_1_Ongoing | 40 | PHONES | `sp_snow_step_TRS_PHN_S40_PHONES` | TRANSFORM | `WRK_TRS_PHN_S4_PHONES` | WRK_TRS_PHN_S3_CHECKED |
| m_Tgt_C_S_TRS_Pty_Rle_Phn_And_EAddr | wf_TRS_Stage_Load_1_Ongoing | 50 | PHN_VERSIONS | `sp_snow_step_TRS_PHN_S50_VERSIONS` | TRANSFORM | `WRK_TRS_PHN_S5_VERSIONS` | WRK_TRS_PHN_S4_PHONES |
| m_Tgt_C_S_TRS_Pty_Rle_Phn_And_EAddr | wf_TRS_Stage_Load_1_Ongoing | 60 | EMAILS_CHECKED | `sp_snow_step_TRS_PHN_S60_EMAILS` | TRANSFORM | `WRK_TRS_PHN_S6_EMAILS` | WRK_TRS_PHN_S1_SRC |
| m_Tgt_C_S_TRS_Pty_Rle_Phn_And_EAddr | wf_TRS_Stage_Load_1_Ongoing | 70 | EADDR_VERSIONS | `sp_snow_step_TRS_PHN_S70_EADDR` | TRANSFORM | `WRK_TRS_PHN_S7_VERSIONS` | WRK_TRS_PHN_S6_EMAILS |
| m_Tgt_C_S_TRS_Pty_Rle_Phn_And_EAddr | wf_TRS_Stage_Load_1_Ongoing | 80 | PUBLISH_C_S_TRS_PTY_RLE_PHN | `sp_snow_pub_TRS_PHN_C_S_TRS_PTY_RLE_PHN` | SPINE | `C_S_TRS_PTY_RLE_PHN` | WRK_TRS_PHN_S5_VERSIONS |
| m_Tgt_C_S_TRS_Pty_Rle_Phn_And_EAddr | wf_TRS_Stage_Load_1_Ongoing | 90 | PUBLISH_EXC_PHONE | `sp_snow_pub_TRS_PHN_EXC_STG_BAD_REC_MEMB_PHONE` | EXCEPTION | `EXC_STG_BAD_REC_MEMB` | WRK_TRS_PHN_S4_PHONES |
| m_Tgt_C_S_TRS_Pty_Rle_Phn_And_EAddr | wf_TRS_Stage_Load_1_Ongoing | 100 | PUBLISH_C_S_TRS_PTY_RLE_EADDR | `sp_snow_pub_TRS_PHN_C_S_TRS_PTY_RLE_EADDR` | SPINE | `C_S_TRS_PTY_RLE_EADDR` | WRK_TRS_PHN_S7_VERSIONS |
| m_Tgt_C_S_TRS_Pty_Rle_Phn_And_EAddr | wf_TRS_Stage_Load_1_Ongoing | 110 | PUBLISH_EXC_EMAIL | `sp_snow_pub_TRS_PHN_EXC_STG_BAD_REC_MEMB_EMAIL` | EXCEPTION | `EXC_STG_BAD_REC_MEMB` | WRK_TRS_PHN_S6_EMAILS |
| m_Tgt_C_S_TRS_Pty_Mng_Attr_Sw | wf_TRS_Stage_Load_1_Ongoing | 10 | DAILY_INDV | `sp_snow_step_TRS_MNGSW_S10_DAILY` | TRANSFORM | `WRK_TRS_MNGSW_S10_DAILY` | (base tables only) |
| m_Tgt_C_S_TRS_Pty_Mng_Attr_Sw | wf_TRS_Stage_Load_1_Ongoing | 20 | VALID_SRC | `sp_snow_step_TRS_MNGSW_S20_SRC` | TRANSFORM | `WRK_TRS_MNGSW_S20_SRC` | WRK_TRS_MNGSW_S10_DAILY |
| m_Tgt_C_S_TRS_Pty_Mng_Attr_Sw | wf_TRS_Stage_Load_1_Ongoing | 30 | UNPIVOT_SWITCHES | `sp_snow_step_TRS_MNGSW_S30_NORM` | TRANSFORM | `WRK_TRS_MNGSW_S30_NORM` | WRK_TRS_MNGSW_S20_SRC |
| m_Tgt_C_S_TRS_Pty_Mng_Attr_Sw | wf_TRS_Stage_Load_1_Ongoing | 40 | FILTERED_ATTRS | `sp_snow_step_TRS_MNGSW_S40_ATTRS` | TRANSFORM | `WRK_TRS_MNGSW_S40_ATTRS` | WRK_TRS_MNGSW_S30_NORM |
| m_Tgt_C_S_TRS_Pty_Mng_Attr_Sw | wf_TRS_Stage_Load_1_Ongoing | 50 | PUBLISH_C_S_TRS_PTY_MNG_ATTR | `sp_snow_pub_TRS_MNGSW_C_S_TRS_PTY_MNG_ATTR` | SPINE | `C_S_TRS_PTY_MNG_ATTR` | WRK_TRS_MNGSW_S40_ATTRS |
| m_Tgt_C_S_TRS_Pty_Mng_Attr_Auth_Rep_Ongoing | wf_TRS_Stage_Load_1_Ongoing | 10 | PAYEE_CASE_ROWS | `sp_snow_step_TRS_AUTHREP_S10_PAYEE` | TRANSFORM | `WRK_TRS_MNGAR_S10_PAYEE` | (base tables only) |
| m_Tgt_C_S_TRS_Pty_Mng_Attr_Auth_Rep_Ongoing | wf_TRS_Stage_Load_1_Ongoing | 20 | VALID_SRC | `sp_snow_step_TRS_AUTHREP_S20_SRC` | TRANSFORM | `WRK_TRS_MNGAR_S20_SRC` | WRK_TRS_MNGAR_S10_PAYEE |
| m_Tgt_C_S_TRS_Pty_Mng_Attr_Auth_Rep_Ongoing | wf_TRS_Stage_Load_1_Ongoing | 30 | KEYED | `sp_snow_step_TRS_AUTHREP_S30_KEYED` | TRANSFORM | `WRK_TRS_MNGAR_S30_KEYED` | WRK_TRS_MNGAR_S20_SRC |
| m_Tgt_C_S_TRS_Pty_Mng_Attr_Auth_Rep_Ongoing | wf_TRS_Stage_Load_1_Ongoing | 40 | AGG_DEDUP | `sp_snow_step_TRS_AUTHREP_S40_AGG` | TRANSFORM | `WRK_TRS_MNGAR_S40_AGG` | WRK_TRS_MNGAR_S30_KEYED |
| m_Tgt_C_S_TRS_Pty_Mng_Attr_Auth_Rep_Ongoing | wf_TRS_Stage_Load_1_Ongoing | 50 | PUBLISH_C_S_TRS_PTY_MNG_ATTR | `sp_snow_pub_TRS_AUTHREP_C_S_TRS_PTY_MNG_ATTR` | SPINE | `C_S_TRS_PTY_MNG_ATTR` | WRK_TRS_MNGAR_S40_AGG |
| m_Tgt_C_S_TRS_Pty_Nm | wf_TRS_Stage_Load_1_Ongoing | 10 | ALIAS_SRC | `sp_snow_step_TRS_NM_S10_SRC` | TRANSFORM | `WRK_TRS_NM_S10_SRC` | (base tables only) |
| m_Tgt_C_S_TRS_Pty_Nm | wf_TRS_Stage_Load_1_Ongoing | 20 | NAMED_FILTERED | `sp_snow_step_TRS_NM_S20_NAMED` | TRANSFORM | `WRK_TRS_NM_S20_NAMED` | WRK_TRS_NM_S10_SRC |
| m_Tgt_C_S_TRS_Pty_Nm | wf_TRS_Stage_Load_1_Ongoing | 30 | STANDARDISED | `sp_snow_step_TRS_NM_S30_STD` | TRANSFORM | `WRK_TRS_NM_S30_STD` | WRK_TRS_NM_S20_NAMED |
| m_Tgt_C_S_TRS_Pty_Nm | wf_TRS_Stage_Load_1_Ongoing | 40 | DEDUP_KEYED | `sp_snow_step_TRS_NM_S40_DEDUP` | TRANSFORM | `WRK_TRS_NM_S40_DEDUP` | WRK_TRS_NM_S30_STD |
| m_Tgt_C_S_TRS_Pty_Nm | wf_TRS_Stage_Load_1_Ongoing | 50 | PUBLISH_C_S_TRS_PTY_NM | `sp_snow_pub_TRS_NM_C_S_TRS_PTY_NM` | SPINE | `C_S_TRS_PTY_NM` | WRK_TRS_NM_S40_DEDUP |
| m_Tgt_C_S_TRS_Pty_Rle_Alt_Id | wf_TRS_Stage_Load_1_Ongoing | 10 | SRC_DEDUP | `sp_snow_step_TRS_ALT_S10_SRC` | TRANSFORM | `WRK_TRS_ALT_S1_SRC` | (base tables only) |
| m_Tgt_C_S_TRS_Pty_Rle_Alt_Id | wf_TRS_Stage_Load_1_Ongoing | 20 | SSN_VALIDATED | `sp_snow_step_TRS_ALT_S20_SSN` | TRANSFORM | `WRK_TRS_ALT_S2_SSN` | WRK_TRS_ALT_S1_SRC |
| m_Tgt_C_S_TRS_Pty_Rle_Alt_Id | wf_TRS_Stage_Load_1_Ongoing | 30 | NORMALIZED | `sp_snow_step_TRS_ALT_S30_NORM` | TRANSFORM | `WRK_TRS_ALT_S3_NORM` | WRK_TRS_ALT_S2_SSN |
| m_Tgt_C_S_TRS_Pty_Rle_Alt_Id | wf_TRS_Stage_Load_1_Ongoing | 40 | ROUTED | `sp_snow_step_TRS_ALT_S40_ROUTED` | TRANSFORM | `WRK_TRS_ALT_S4_ROUTED` | WRK_TRS_ALT_S3_NORM |
| m_Tgt_C_S_TRS_Pty_Rle_Alt_Id | wf_TRS_Stage_Load_1_Ongoing | 50 | PUBLISH_C_S_TRS_PTY_RLE_ALT_ID | `sp_snow_pub_TRS_ALT_C_S_TRS_PTY_RLE_ALT_ID` | SPINE | `C_S_TRS_PTY_RLE_ALT_ID` | WRK_TRS_ALT_S4_ROUTED |
| m_Tgt_C_S_TRS_Pty_Rle_Alt_Id | wf_TRS_Stage_Load_1_Ongoing | 60 | PUBLISH_EXC_STG_BAD_REC_MEMB | `sp_snow_pub_TRS_ALT_EXC_STG_BAD_REC_MEMB` | EXCEPTION | `EXC_STG_BAD_REC_MEMB` | WRK_TRS_ALT_S4_ROUTED |
| m_Tgt_C_S_TRS_Pty_Rle_Pln | wf_TRS_Stage_Load_1_Ongoing | 10 | MANAGED_CARE_SRC | `sp_snow_step_TRS_PLN_S10_SRC` | TRANSFORM | `WRK_TRS_PLN_S10_SRC` | (base tables only) |
| m_Tgt_C_S_TRS_Pty_Rle_Pln | wf_TRS_Stage_Load_1_Ongoing | 20 | PLAN_TRANSLATED | `sp_snow_step_TRS_PLN_S20_PLANNED` | TRANSFORM | `WRK_TRS_PLN_S20_PLANNED` | WRK_TRS_PLN_S10_SRC |
| m_Tgt_C_S_TRS_Pty_Rle_Pln | wf_TRS_Stage_Load_1_Ongoing | 30 | RANKED | `sp_snow_step_TRS_PLN_S30_RANKED` | TRANSFORM | `WRK_TRS_PLN_S30_RANKED` | WRK_TRS_PLN_S20_PLANNED |
| m_Tgt_C_S_TRS_Pty_Rle_Pln | wf_TRS_Stage_Load_1_Ongoing | 40 | PUBLISH_C_S_TRS_PTY_RLE_PLN | `sp_snow_pub_TRS_PLN_C_S_TRS_PTY_RLE_PLN` | SPINE | `C_S_TRS_PTY_RLE_PLN` | WRK_TRS_PLN_S30_RANKED |
| m_Tgt_C_S_TRS_Pty_Rle_Pln | wf_TRS_Stage_Load_1_Ongoing | 50 | PUBLISH_EXC_STG_BAD_REC_MEMB | `sp_snow_pub_TRS_PLN_EXC_STG_BAD_REC_MEMB` | EXCEPTION | `EXC_STG_BAD_REC_MEMB` | WRK_TRS_PLN_S30_RANKED |
| m_Tgt_C_S_TRS_Addr_1 | wf_TRS_Stage_Load_1_Ongoing | 10 | SRC_DISTINCT_ADDR | `sp_snow_step_TRS_ADDR1_S10_SRC` | TRANSFORM | `WRK_TRS_ADDR1_S10_SRC` | (base tables only) |
| m_Tgt_C_S_TRS_Addr_1 | wf_TRS_Stage_Load_1_Ongoing | 20 | DERIVED_ADDR_LINES | `sp_snow_step_TRS_ADDR1_S20_DERIVED` | TRANSFORM | `WRK_TRS_ADDR1_S20_DERIVED` | WRK_TRS_ADDR1_S10_SRC |
| m_Tgt_C_S_TRS_Addr_1 | wf_TRS_Stage_Load_1_Ongoing | 30 | ADDR_VALIDATION | `sp_snow_step_TRS_ADDR1_S30_VALIDATED` | TRANSFORM | `WRK_TRS_ADDR1_S30_VALIDATED` | WRK_TRS_ADDR1_S20_DERIVED |
| m_Tgt_C_S_TRS_Addr_1 | wf_TRS_Stage_Load_1_Ongoing | 40 | READY_TO_PUBLISH | `sp_snow_step_TRS_ADDR1_S40_READY` | TRANSFORM | `WRK_TRS_ADDR1_S40_READY` | WRK_TRS_ADDR1_S30_VALIDATED |
| m_Tgt_C_S_TRS_Addr_1 | wf_TRS_Stage_Load_1_Ongoing | 50 | PUBLISH_STG_TRS_D_UNQ_ADDR | `sp_snow_pub_TRS_ADDR1_STG_TRS_D_UNQ_ADDR` | STATUS | `STG_TRS_D_UNQ_ADDR` | WRK_TRS_ADDR1_S40_READY |
| m_Tgt_C_S_TRS_Addr_2 | wf_TRS_Stage_Load_1_Ongoing | 10 | ADDR_DEDUP | `sp_snow_step_TRS_ADDR2_S10_DEDUP` | TRANSFORM | `WRK_TRS_ADDR2_S10_DEDUP` | (base tables only) |
| m_Tgt_C_S_TRS_Addr_2 | wf_TRS_Stage_Load_1_Ongoing | 20 | SRC_VALIDATED_JOIN | `sp_snow_step_TRS_ADDR2_S20_SRC` | TRANSFORM | `WRK_TRS_ADDR2_S20_SRC` | WRK_TRS_ADDR2_S10_DEDUP |
| m_Tgt_C_S_TRS_Addr_2 | wf_TRS_Stage_Load_1_Ongoing | 30 | KEYED_ADDR | `sp_snow_step_TRS_ADDR2_S30_KEYED` | TRANSFORM | `WRK_TRS_ADDR2_S30_KEYED` | WRK_TRS_ADDR2_S20_SRC |
| m_Tgt_C_S_TRS_Addr_2 | wf_TRS_Stage_Load_1_Ongoing | 40 | SCORED_VERSIONED | `sp_snow_step_TRS_ADDR2_S40_SCORED` | TRANSFORM | `WRK_TRS_ADDR2_S40_SCORED` | WRK_TRS_ADDR2_S30_KEYED |
| m_Tgt_C_S_TRS_Addr_2 | wf_TRS_Stage_Load_1_Ongoing | 50 | READY_TO_PUBLISH | `sp_snow_step_TRS_ADDR2_S50_READY` | TRANSFORM | `WRK_TRS_ADDR2_S50_READY` | WRK_TRS_ADDR2_S40_SCORED |
| m_Tgt_C_S_TRS_Addr_2 | wf_TRS_Stage_Load_1_Ongoing | 60 | PUBLISH_DQM_ADDRESS | `sp_snow_pub_TRS_ADDR2_DQM_ADDRESS` | VALIDATION | `DQM_ADDRESS` | WRK_TRS_ADDR2_S50_READY |
| m_Tgt_C_S_TRS_Addr_2 | wf_TRS_Stage_Load_1_Ongoing | 70 | PUBLISH_C_S_TRS_PTY_RLE_ADDR | `sp_snow_pub_TRS_ADDR2_C_S_TRS_PTY_RLE_ADDR` | SPINE | `C_S_TRS_PTY_RLE_ADDR` | WRK_TRS_ADDR2_S50_READY |
| m_Tgt_C_S_TRS_Addr_2 | wf_TRS_Stage_Load_1_Ongoing | 80 | PUBLISH_EXC_STG_BAD_REC_MEMB | `sp_snow_pub_TRS_ADDR2_EXC_STG_BAD_REC_MEMB` | EXCEPTION | `EXC_STG_BAD_REC_MEMB` | WRK_TRS_ADDR2_S50_READY |
| m_Tgt_C_S_TRS_Stg_TOA | wf_TRS_Stage_Load_TOA | 10 | CATALOGUE_KEYED | `sp_snow_step_TRS_STGTOA_S10_KEYED` | TRANSFORM | `WRK_TRS_LUTOA_S10_KEYED` | (base tables only) |
| m_Tgt_C_S_TRS_Stg_TOA | wf_TRS_Stage_Load_TOA | 20 | SURVIVOR_PER_KEY | `sp_snow_step_TRS_STGTOA_S20_FINAL` | TRANSFORM | `WRK_TRS_LUTOA_S20_FINAL` | WRK_TRS_LUTOA_S10_KEYED |
| m_Tgt_C_S_TRS_Stg_TOA | wf_TRS_Stage_Load_TOA | 30 | PUBLISH_C_S_LU_TOA | `sp_snow_pub_TRS_STGTOA_C_S_LU_TOA` | STATUS | `C_S_LU_TOA` | WRK_TRS_LUTOA_S20_FINAL |

---

# STEP_MAP_ECI — step maps (bare-bones)

Same step maps as the v2.1 manifests, minus gating and checkpoint columns. Step 5 (cleanup) drops the mapping's work tables and is not a data step; work tables are left standing at the end of a run.

## ADR — m_Tgt_C_S_ECI_Pty_Addr — driver `sp_snow_main_m_Tgt_C_S_ECI_Pty_Addr(P_MEMBER_HIERARCHY_CODE VARCHAR DEFAULT 'Member', P_MEMBER_HM_REL_TP_CD VARCHAR DEFAULT 'Member Addr')`

| Step | Step name | Procedure | Target / produces | Consumes |
| --- | --- | --- | --- | --- |
| 5 | CLEANUP_PREVIOUS_RUN | — | (drops: WRK_ECI_ADR_S10_SRC, WRK_ECI_ADR_S20_KEYED, WRK_ECI_ADR_S30_VALIDATED, WRK_ECI_ADR_S40_FLAT, WRK_ECI_ADR_S50_READY) | — |
| 10 | SRC_ADDRESSES | `sp_snow_step_ECI_ADR_S10_SRC` | WRK_ECI_ADR_S10_SRC | V_ECI_ETL_SRC_FAMILY_ADDRESS |
| 20 | KEYED_ACTIVE | `sp_snow_step_ECI_ADR_S20_KEYED` | WRK_ECI_ADR_S20_KEYED | WRK_ECI_ADR_S10_SRC |
| 30 | ADDR_VALIDATION | `sp_snow_step_ECI_ADR_S30_VALIDATED` | WRK_ECI_ADR_S30_VALIDATED | WRK_ECI_ADR_S20_KEYED |
| 40 | FLAT_VALIDATION | `sp_snow_step_ECI_ADR_S40_FLAT` | WRK_ECI_ADR_S40_FLAT | WRK_ECI_ADR_S30_VALIDATED |
| 50 | SCORED_READY | `sp_snow_step_ECI_ADR_S50_READY` | WRK_ECI_ADR_S50_READY | WRK_ECI_ADR_S40_FLAT |
| 60 | PUBLISH_DQM_ADDRESS | `sp_snow_pub_ECI_ADR_DQM_ADDRESS` | DQM_ADDRESS | WRK_ECI_ADR_S50_READY |
| 70 | PUBLISH_C_S_ECI_PTY_RLE_ADDR | `sp_snow_pub_ECI_ADR_C_S_ECI_PTY_RLE_ADDR` | C_S_ECI_PTY_RLE_ADDR | WRK_ECI_ADR_S50_READY |
| 80 | PUBLISH_EXC_STG_BAD_REC_MEMB | `sp_snow_pub_ECI_ADR_EXC_STG_BAD_REC_MEMB` | EXC_STG_BAD_REC_MEMB | WRK_ECI_ADR_S50_READY |

## ALT — m_Tgt_C_S_ECI_Pty_Rle_Alt_Id — driver `sp_snow_main_m_Tgt_C_S_ECI_Pty_Rle_Alt_Id((none))`

| Step | Step name | Procedure | Target / produces | Consumes |
| --- | --- | --- | --- | --- |
| 5 | CLEANUP_PREVIOUS_RUN | — | (drops: WRK_ECI_ALT_S10_SRC, WRK_ECI_ALT_S20_ACTIVE, WRK_ECI_ALT_S30_ROUTED, WRK_ECI_ALT_S40_READY) | — |
| 10 | SRC_ALT_IDS | `sp_snow_step_ECI_ALT_S10_SRC` | WRK_ECI_ALT_S10_SRC | STG_ECI_D_CHILD, STG_ECI_D_FAMILY, STG_ECI_D_MEDICAID, STG_ECI_SN_CASE |
| 20 | ACTIVE_ALT_IDS | `sp_snow_step_ECI_ALT_S20_ACTIVE` | WRK_ECI_ALT_S20_ACTIVE | WRK_ECI_ALT_S10_SRC |
| 30 | VALIDATED_ROUTED | `sp_snow_step_ECI_ALT_S30_ROUTED` | WRK_ECI_ALT_S30_ROUTED | WRK_ECI_ALT_S20_ACTIVE |
| 40 | READY_TO_PUBLISH | `sp_snow_step_ECI_ALT_S40_READY` | WRK_ECI_ALT_S40_READY | WRK_ECI_ALT_S30_ROUTED |
| 50 | PUBLISH_C_S_ECI_PTY_RLE_ALT_ID | `sp_snow_pub_ECI_ALT_C_S_ECI_PTY_RLE_ALT_ID` | C_S_ECI_PTY_RLE_ALT_ID | WRK_ECI_ALT_S40_READY |
| 60 | PUBLISH_EXC_STG_BAD_REC_MEMB_SSN | `sp_snow_pub_ECI_ALT_EXC_STG_BAD_REC_MEMB_SSN` | EXC_STG_BAD_REC_MEMB | WRK_ECI_ALT_S40_READY |
| 70 | PUBLISH_EXC_STG_BAD_REC_MEMB_MEDICAID | `sp_snow_pub_ECI_ALT_EXC_STG_BAD_REC_MEMB_MEDICAID` | EXC_STG_BAD_REC_MEMB | WRK_ECI_ALT_S40_READY |

## PHN — m_Tgt_C_S_ECI_Pty_Rle_Phn_And_EAddr — driver `sp_snow_main_m_Tgt_C_S_ECI_Pty_Rle_Phn_And_EAddr((none))`

| Step | Step name | Procedure | Target / produces | Consumes |
| --- | --- | --- | --- | --- |
| 5 | CLEANUP_PREVIOUS_RUN | — | (drops: WRK_ECI_PHN_S10_SRC, WRK_ECI_PHN_S20_ACTIVE, WRK_ECI_PHN_S30_DQ, WRK_ECI_PHN_S40_ROUTED, WRK_ECI_PHN_S50_READY) | — |
| 10 | SRC_PHN_EADDR | `sp_snow_step_ECI_PHN_S10_SRC` | WRK_ECI_PHN_S10_SRC | V_ECI_ETL_SRC_FAMILY_PHONE |
| 20 | ACTIVE_PHN_EADDR | `sp_snow_step_ECI_PHN_S20_ACTIVE` | WRK_ECI_PHN_S20_ACTIVE | WRK_ECI_PHN_S10_SRC |
| 30 | DQ_CLEAN_VALIDATE | `sp_snow_step_ECI_PHN_S30_DQ` | WRK_ECI_PHN_S30_DQ | WRK_ECI_PHN_S20_ACTIVE |
| 40 | ROUTED_GROUPS | `sp_snow_step_ECI_PHN_S40_ROUTED` | WRK_ECI_PHN_S40_ROUTED | WRK_ECI_PHN_S30_DQ |
| 50 | READY_TO_PUBLISH | `sp_snow_step_ECI_PHN_S50_READY` | WRK_ECI_PHN_S50_READY | WRK_ECI_PHN_S40_ROUTED |
| 60 | PUBLISH_C_S_ECI_PTY_RLE_PHN | `sp_snow_pub_ECI_PHN_C_S_ECI_PTY_RLE_PHN` | C_S_ECI_PTY_RLE_PHN | WRK_ECI_PHN_S50_READY |
| 70 | PUBLISH_EXC_STG_BAD_REC_MEMB_PHONE | `sp_snow_pub_ECI_PHN_EXC_STG_BAD_REC_MEMB_PHONE` | EXC_STG_BAD_REC_MEMB | WRK_ECI_PHN_S50_READY |
| 80 | PUBLISH_C_S_ECI_PTY_RLE_EADDR | `sp_snow_pub_ECI_PHN_C_S_ECI_PTY_RLE_EADDR` | C_S_ECI_PTY_RLE_EADDR | WRK_ECI_PHN_S50_READY |
| 90 | PUBLISH_EXC_STG_BAD_REC_MEMB_EMAIL | `sp_snow_pub_ECI_PHN_EXC_STG_BAD_REC_MEMB_EMAIL` | EXC_STG_BAD_REC_MEMB | WRK_ECI_PHN_S50_READY |

## PTY — m_Tgt_C_S_ECI_Pty — driver `sp_snow_main_m_Tgt_C_S_ECI_Pty(P_PTY_BO_CLASS_CD_MEMBER VARCHAR DEFAULT 'Indv', P_RLE_BO_CLASS_CD_MEMBER VARCHAR DEFAULT 'Member')`

| Step | Step name | Procedure | Target / produces | Consumes |
| --- | --- | --- | --- | --- |
| 5 | CLEANUP_PREVIOUS_RUN | — | (drops: WRK_ECI_PTY_S10_SRC, WRK_ECI_PTY_S20_ACTIVE, WRK_ECI_PTY_S30_DQ, WRK_ECI_PTY_S40_DQ2, WRK_ECI_PTY_S50_READY) | — |
| 10 | SRC_DELTA_PARTIES | `sp_snow_step_ECI_PTY_S10_SRC` | WRK_ECI_PTY_S10_SRC | STG_ECI_D_CHILD, STG_ECI_D_FAMILY |
| 20 | ACTIVE_PARTIES | `sp_snow_step_ECI_PTY_S20_ACTIVE` | WRK_ECI_PTY_S20_ACTIVE | WRK_ECI_PTY_S10_SRC |
| 30 | DQ_RULES | `sp_snow_step_ECI_PTY_S30_DQ` | WRK_ECI_PTY_S30_DQ | WRK_ECI_PTY_S20_ACTIVE |
| 40 | DQ_EXCEPTIONS_RESOLVED | `sp_snow_step_ECI_PTY_S40_DQ2` | WRK_ECI_PTY_S40_DQ2 | WRK_ECI_PTY_S30_DQ |
| 50 | ROUTED_READY | `sp_snow_step_ECI_PTY_S50_READY` | WRK_ECI_PTY_S50_READY | WRK_ECI_PTY_S40_DQ2 |
| 60 | PUBLISH_C_S_ECI_PTY | `sp_snow_pub_ECI_PTY_C_S_ECI_PTY` | C_S_ECI_PTY | WRK_ECI_PTY_S50_READY |
| 70 | PUBLISH_C_S_ECI_PTY_RLE | `sp_snow_pub_ECI_PTY_C_S_ECI_PTY_RLE` | C_S_ECI_PTY_RLE | WRK_ECI_PTY_S50_READY |
| 80 | PUBLISH_EXC_GENDER | `sp_snow_pub_ECI_PTY_EXC_STG_BAD_REC_MEMB_GENDER` | EXC_STG_BAD_REC_MEMB | WRK_ECI_PTY_S50_READY |
| 90 | PUBLISH_EXC_BIRTH | `sp_snow_pub_ECI_PTY_EXC_STG_BAD_REC_MEMB_BIRTH` | EXC_STG_BAD_REC_MEMB | WRK_ECI_PTY_S50_READY |
| 100 | PUBLISH_EXC_ETHNICITY | `sp_snow_pub_ECI_PTY_EXC_STG_BAD_REC_MEMB_ETHNICITY` | EXC_STG_BAD_REC_MEMB | WRK_ECI_PTY_S50_READY |
| 110 | PUBLISH_EXC_RACE | `sp_snow_pub_ECI_PTY_EXC_STG_BAD_REC_MEMB_RACE` | EXC_STG_BAD_REC_MEMB | WRK_ECI_PTY_S50_READY |
| 120 | PUBLISH_EXC_LANGUAGE | `sp_snow_pub_ECI_PTY_EXC_STG_BAD_REC_MEMB_LANGUAGE` | EXC_STG_BAD_REC_MEMB | WRK_ECI_PTY_S50_READY |

## REL — m_Tgt_C_S_ECI_Pty_Rle_Rel — driver `sp_snow_main_m_Tgt_C_S_ECI_Pty_Rle_Rel((none))`

| Step | Step name | Procedure | Target / produces | Consumes |
| --- | --- | --- | --- | --- |
| 5 | CLEANUP_PREVIOUS_RUN | — | (drops: WRK_ECI_REL_S10_SRC, WRK_ECI_REL_S20_KEYED, WRK_ECI_REL_S30_TYPED, WRK_ECI_REL_S40_READY) | — |
| 10 | SRC_BOTH_DIRECTIONS | `sp_snow_step_ECI_REL_S10_SRC` | WRK_ECI_REL_S10_SRC | STG_ECI_D_FAMILY |
| 20 | KEYED_BOTH_ACTIVE | `sp_snow_step_ECI_REL_S20_KEYED` | WRK_ECI_REL_S20_KEYED | WRK_ECI_REL_S10_SRC |
| 30 | CODED_TRANSLATED | `sp_snow_step_ECI_REL_S30_TYPED` | WRK_ECI_REL_S30_TYPED | WRK_ECI_REL_S20_KEYED |
| 40 | READY_TO_PUBLISH | `sp_snow_step_ECI_REL_S40_READY` | WRK_ECI_REL_S40_READY | WRK_ECI_REL_S30_TYPED |
| 50 | PUBLISH_C_S_ECI_PTY_RLE_REL | `sp_snow_pub_ECI_REL_C_S_ECI_PTY_RLE_REL` | C_S_ECI_PTY_RLE_REL | WRK_ECI_REL_S40_READY |
| 60 | PUBLISH_EXC_STG_BAD_REC_MEMB | `sp_snow_pub_ECI_REL_EXC_STG_BAD_REC_MEMB` | EXC_STG_BAD_REC_MEMB | WRK_ECI_REL_S40_READY |

## RFA — m_Tgt_Stg_ECI_Pty_Reactivation_D_Family_Addr — driver `sp_snow_main_m_Tgt_Stg_ECI_Pty_Reactivation_D_Family_Addr((none))`

| Step | Step name | Procedure | Target / produces | Consumes |
| --- | --- | --- | --- | --- |
| 5 | CLEANUP_PREVIOUS_RUN | — | (drops: WRK_ECI_RFA_S10_LATEST, WRK_ECI_RFA_S20_KEEPNEW) | — |
| 10 | LATEST_HISTORY_ROWS | `sp_snow_step_ECI_RFA_S10_LATEST` | WRK_ECI_RFA_S10_LATEST | STG_ECI_H_FAMILY_ADDRESS, V_ECI_ETL_LU_REACTIVATED_ID |
| 20 | KEEP_NEW_ONLY | `sp_snow_step_ECI_RFA_S20_KEEPNEW` | WRK_ECI_RFA_S20_KEEPNEW | WRK_ECI_RFA_S10_LATEST |
| 30 | PUBLISH_STG_ECI_D_FAMILY_ADDRESS | `sp_snow_pub_ECI_RFA_STG_ECI_D_FAMILY_ADDRESS` | STG_ECI_D_FAMILY_ADDRESS | WRK_ECI_RFA_S20_KEEPNEW |

## RFM — m_Tgt_Stg_ECI_Pty_Reactivation_D_Medicaid — driver `sp_snow_main_m_Tgt_Stg_ECI_Pty_Reactivation_D_Medicaid(P_TEST_LOOKUP_RESULT VARCHAR DEFAULT 'N')`

| Step | Step name | Procedure | Target / produces | Consumes |
| --- | --- | --- | --- | --- |
| 5 | CLEANUP_PREVIOUS_RUN | — | (drops: WRK_ECI_RFM_S10_LATEST, WRK_ECI_RFM_S20_KEEPNEW) | — |
| 10 | LATEST_HISTORY_ROWS | `sp_snow_step_ECI_RFM_S10_LATEST` | WRK_ECI_RFM_S10_LATEST | STG_ECI_D_MEDICAID, STG_ECI_H_MEDICAID, STG_ECI_SN_CASE, V_ECI_ETL_LU_REACTIVATED_ID |
| 20 | KEEP_NEW_ONLY | `sp_snow_step_ECI_RFM_S20_KEEPNEW` | WRK_ECI_RFM_S20_KEEPNEW | WRK_ECI_RFM_S10_LATEST |
| 30 | PUBLISH_STG_ECI_D_MEDICAID | `sp_snow_pub_ECI_RFM_STG_ECI_D_MEDICAID` | STG_ECI_D_MEDICAID | WRK_ECI_RFM_S20_KEEPNEW |

## RFP — m_Tgt_Stg_ECI_Pty_Reactivation_D_Family_Phn — driver `sp_snow_main_m_Tgt_Stg_ECI_Pty_Reactivation_D_Family_Phn((none))`

| Step | Step name | Procedure | Target / produces | Consumes |
| --- | --- | --- | --- | --- |
| 5 | CLEANUP_PREVIOUS_RUN | — | (drops: WRK_ECI_RFP_S10_LATEST, WRK_ECI_RFP_S20_KEEPNEW) | — |
| 10 | LATEST_HISTORY_ROWS | `sp_snow_step_ECI_RFP_S10_LATEST` | WRK_ECI_RFP_S10_LATEST | STG_ECI_H_FAMILY_PHONE, V_ECI_ETL_LU_REACTIVATED_ID |
| 20 | KEEP_NEW_ONLY | `sp_snow_step_ECI_RFP_S20_KEEPNEW` | WRK_ECI_RFP_S20_KEEPNEW | WRK_ECI_RFP_S10_LATEST |
| 30 | PUBLISH_STG_ECI_D_FAMILY_PHONE | `sp_snow_pub_ECI_RFP_STG_ECI_D_FAMILY_PHONE` | STG_ECI_D_FAMILY_PHONE | WRK_ECI_RFP_S20_KEEPNEW |

## VAL — m_Tgt_C_S_ECI_Pty_Validation — driver `sp_snow_main_m_Tgt_C_S_ECI_Pty_Validation((none))`

| Step | Step name | Procedure | Target / produces | Consumes |
| --- | --- | --- | --- | --- |
| 5 | CLEANUP_PREVIOUS_RUN | — | (drops: WRK_ECI_VAL_S10_SRC, WRK_ECI_VAL_S20_ENRICHED, WRK_ECI_VAL_S30_ROUTED) | — |
| 10 | SRC_DELTA_PARTIES | `sp_snow_step_ECI_VAL_S10_SRC` | WRK_ECI_VAL_S10_SRC | STG_ECI_D_CHILD, STG_ECI_D_FAMILY |
| 20 | ENRICHED_STD_NAMES | `sp_snow_step_ECI_VAL_S20_ENRICHED` | WRK_ECI_VAL_S20_ENRICHED | WRK_ECI_VAL_S10_SRC |
| 30 | ROUTED_GROUPS | `sp_snow_step_ECI_VAL_S30_ROUTED` | WRK_ECI_VAL_S30_ROUTED | WRK_ECI_VAL_S20_ENRICHED |
| 40 | PUBLISH_EXC_STG_BAD_REC_MEMB | `sp_snow_pub_ECI_VAL_EXC_STG_BAD_REC_MEMB` | EXC_STG_BAD_REC_MEMB | WRK_ECI_VAL_S30_ROUTED |
| 50 | PUBLISH_STG_ECI_PTY_INACTIVE_LOG_DEACTIVATION | `sp_snow_pub_ECI_VAL_STG_ECI_PTY_INACTIVE_LOG_DEACTIVATION` | STG_ECI_PTY_INACTIVE_LOG | WRK_ECI_VAL_S30_ROUTED |
| 60 | PUBLISH_STG_ECI_PTY_INACTIVE_STS | `sp_snow_pub_ECI_VAL_STG_ECI_PTY_INACTIVE_STS` | STG_ECI_PTY_INACTIVE_STS | WRK_ECI_VAL_S30_ROUTED |
| 70 | PUBLISH_STG_ECI_PTY_INACTIVE_LOG_REACTIVATION | `sp_snow_pub_ECI_VAL_STG_ECI_PTY_INACTIVE_LOG_REACTIVATION` | STG_ECI_PTY_INACTIVE_LOG | WRK_ECI_VAL_S30_ROUTED |

---

# WIC Step Map — wf_WIC_Stage_Load (bare-bones variant)
Install location: database `MDM_ETL_WIC`, schema `WIC_ETL_WRK`. All table and procedure names in the bare-bones code are unqualified.
Driver names are as in the v2.1 step-driver package, minus the removed trailing run-id parameter. Run order is unchanged from the multisource runner: Validation, Party, Address, Phone/E-mail, Alt Id.

## Mapping to PREFIX

| Mapping | Driver procedure | PREFIX (unit token) | Short |
|---|---|---|---|
| `m_Tgt_C_S_WIC_Pty_Validation` | `sp_snow_main_m_Tgt_C_S_WIC_Pty_Validation` | `WIC_VAL` | VAL |
| `m_Tgt_C_S_WIC_Pty` | `sp_snow_main_m_Tgt_C_S_WIC_Pty` | `WIC_PTY` | PTY |
| `m_Tgt_C_S_WIC_Pty_Addr` | `sp_snow_main_m_Tgt_C_S_WIC_Pty_Addr` | `WIC_ADR` | ADR |
| `m_Tgt_C_S_WIC_Pty_Rle_Phn_And_EAddr` | `sp_snow_main_m_Tgt_C_S_WIC_Pty_Rle_Phn_And_EAddr` | `WIC_PHN` | PHN |
| `m_Tgt_C_S_WIC_Pty_Rle_Alt_Id` | `sp_snow_main_m_Tgt_C_S_WIC_Pty_Rle_Alt_Id` | `WIC_ALT` | ALT |

## VAL — `m_Tgt_C_S_WIC_Pty_Validation`

Driver: `drivers/driver_sp_snow_main_m_Tgt_C_S_WIC_Pty_Validation.sql`. Manifest: `manifests/VAL_MANIFEST.md`.

| STEP_NO | Proc | Kind | Produces / Target | Consumes |
|---|---|---|---|---|
| 10 | `sp_snow_step_WIC_VAL_S10_ENRICHED` | TRANSFORM | `WRK_WIC_VAL_S10_ENRICHED` | `` |
| 20 | `sp_snow_step_WIC_VAL_S20_NAMED` | TRANSFORM | `WRK_WIC_VAL_S20_NAMED` | `WRK_WIC_VAL_S10_ENRICHED` |
| 30 | `sp_snow_step_WIC_VAL_S30_ROUTED` | TRANSFORM | `WRK_WIC_VAL_S30_ROUTED` | `WRK_WIC_VAL_S20_NAMED` |
| 40 | `sp_snow_pub_WIC_VAL_EXC_STG_BAD_REC_MEMB` | EXCEPTION | `EXC_STG_BAD_REC_MEMB` (invalid-name exceptions) | `WRK_WIC_VAL_S30_ROUTED` |
| 50 | `sp_snow_pub_WIC_VAL_STG_WIC_PTY_INACTIVE_LOG_DEACTIVATION` | STATUS | `STG_WIC_PTY_INACTIVE_LOG` (deactivation log rows) | `WRK_WIC_VAL_S30_ROUTED` |
| 60 | `sp_snow_pub_WIC_VAL_STG_WIC_PTY_INACTIVE_STS` | STATUS | `STG_WIC_PTY_INACTIVE_STS` (new deactivation-status rows) | `WRK_WIC_VAL_S30_ROUTED` |
| 70 | `sp_snow_pub_WIC_VAL_STG_WIC_PTY_INACTIVE_LOG_REACTIVATION` | STATUS | `STG_WIC_PTY_INACTIVE_LOG` (reactivation log rows) | `WRK_WIC_VAL_S30_ROUTED` |

Step 5: drops `WRK_WIC_VAL_S10_ENRICHED`, `WRK_WIC_VAL_S20_NAMED`, `WRK_WIC_VAL_S30_ROUTED` — bare `DROP TABLE IF EXISTS`. Publish branches run inside ONE transaction; the first branch takes step number 40, +10 per branch.

## PTY — `m_Tgt_C_S_WIC_Pty`

Driver: `drivers/driver_sp_snow_main_m_Tgt_C_S_WIC_Pty.sql`. Manifest: `manifests/PTY_MANIFEST.md`.

| STEP_NO | Proc | Kind | Produces / Target | Consumes |
|---|---|---|---|---|
| 10 | `sp_snow_step_WIC_PTY_S10_ACTIVE` | TRANSFORM | `WRK_WIC_PTY_S10_ACTIVE` | `` |
| 20 | `sp_snow_step_WIC_PTY_S20_DQ` | TRANSFORM | `WRK_WIC_PTY_S20_DQ` | `WRK_WIC_PTY_S10_ACTIVE` |
| 30 | `sp_snow_step_WIC_PTY_S30_DQ2` | TRANSFORM | `WRK_WIC_PTY_S30_DQ2` | `WRK_WIC_PTY_S20_DQ` |
| 40 | `sp_snow_step_WIC_PTY_S40_ROUTED` | TRANSFORM | `WRK_WIC_PTY_S40_ROUTED` | `WRK_WIC_PTY_S30_DQ2` |
| 50 | `sp_snow_pub_WIC_PTY_C_S_WIC_PTY` | SPINE | `C_S_WIC_PTY` (valid parties) | `WRK_WIC_PTY_S40_ROUTED` |
| 60 | `sp_snow_pub_WIC_PTY_C_S_WIC_PTY_RLE` | SPINE | `C_S_WIC_PTY_RLE` (valid roles) | `WRK_WIC_PTY_S40_ROUTED` |
| 70 | `sp_snow_pub_WIC_PTY_EXC_STG_BAD_REC_MEMB_GENDER` | EXCEPTION | `EXC_STG_BAD_REC_MEMB` (invalid-gender exceptions) | `WRK_WIC_PTY_S40_ROUTED` |
| 80 | `sp_snow_pub_WIC_PTY_EXC_STG_BAD_REC_MEMB_BIRTH` | EXCEPTION | `EXC_STG_BAD_REC_MEMB` (invalid-birth-date exceptions) | `WRK_WIC_PTY_S40_ROUTED` |
| 90 | `sp_snow_pub_WIC_PTY_EXC_STG_BAD_REC_MEMB_ETHNICITY` | EXCEPTION | `EXC_STG_BAD_REC_MEMB` (invalid-ethnicity exceptions) | `WRK_WIC_PTY_S40_ROUTED` |
| 100 | `sp_snow_pub_WIC_PTY_EXC_STG_BAD_REC_MEMB_RACE` | EXCEPTION | `EXC_STG_BAD_REC_MEMB` (invalid-race exceptions) | `WRK_WIC_PTY_S40_ROUTED` |
| 110 | `sp_snow_pub_WIC_PTY_EXC_STG_BAD_REC_MEMB_LANGUAGE` | EXCEPTION | `EXC_STG_BAD_REC_MEMB` (invalid-language exceptions) | `WRK_WIC_PTY_S40_ROUTED` |

Step 5: drops `WRK_WIC_PTY_S10_ACTIVE`, `WRK_WIC_PTY_S20_DQ`, `WRK_WIC_PTY_S30_DQ2`, `WRK_WIC_PTY_S40_ROUTED` — bare `DROP TABLE IF EXISTS`. Publish branches run inside ONE transaction; the first branch takes step number 50, +10 per branch.

## ADR — `m_Tgt_C_S_WIC_Pty_Addr`

Driver: `drivers/driver_sp_snow_main_m_Tgt_C_S_WIC_Pty_Addr.sql`. Manifest: `manifests/ADR_MANIFEST.md`.

| STEP_NO | Proc | Kind | Produces / Target | Consumes |
|---|---|---|---|---|
| 10 | `sp_snow_step_WIC_ADR_S10_ACTIVE` | TRANSFORM | `WRK_WIC_ADDR_S10_ACTIVE` | `` |
| 20 | `sp_snow_step_WIC_ADR_S20_VALIDATED` | TRANSFORM | `WRK_WIC_ADDR_S20_VALIDATED` | `WRK_WIC_ADDR_S10_ACTIVE` |
| 30 | `sp_snow_step_WIC_ADR_S30_FLAT` | TRANSFORM | `WRK_WIC_ADDR_S30_FLAT` | `WRK_WIC_ADDR_S20_VALIDATED` |
| 40 | `sp_snow_step_WIC_ADR_S40_SCORED` | TRANSFORM | `WRK_WIC_ADDR_S40_SCORED` | `WRK_WIC_ADDR_S30_FLAT` |
| 50 | `sp_snow_pub_WIC_ADR_DQM_ADDRESS` | VALIDATION | `DQM_ADDRESS` (every active address (address-quality table) | `WRK_WIC_ADDR_S40_SCORED` |
| 60 | `sp_snow_pub_WIC_ADR_C_S_WIC_PTY_RLE_ADDR` | SPINE | `C_S_WIC_PTY_RLE_ADDR` (good addresses) | `WRK_WIC_ADDR_S40_SCORED` |
| 70 | `sp_snow_pub_WIC_ADR_EXC_STG_BAD_REC_MEMB` | EXCEPTION | `EXC_STG_BAD_REC_MEMB` (exception addresses) | `WRK_WIC_ADDR_S40_SCORED` |

Step 5: drops `WRK_WIC_ADDR_S10_ACTIVE`, `WRK_WIC_ADDR_S20_VALIDATED`, `WRK_WIC_ADDR_S30_FLAT`, `WRK_WIC_ADDR_S40_SCORED` — bare `DROP TABLE IF EXISTS`. Publish branches run inside ONE transaction; the first branch takes step number 50, +10 per branch.

## PHN — `m_Tgt_C_S_WIC_Pty_Rle_Phn_And_EAddr`

Driver: `drivers/driver_sp_snow_main_m_Tgt_C_S_WIC_Pty_Rle_Phn_And_EAddr.sql`. Manifest: `manifests/PHN_MANIFEST.md`.

| STEP_NO | Proc | Kind | Produces / Target | Consumes |
|---|---|---|---|---|
| 10 | `sp_snow_step_WIC_PHN_S10_SRC` | TRANSFORM | `WRK_WIC_PHN_S10_SRC` | `` |
| 20 | `sp_snow_step_WIC_PHN_S20_CHECKED` | TRANSFORM | `WRK_WIC_PHN_S20_CHECKED` | `WRK_WIC_PHN_S10_SRC` |
| 30 | `sp_snow_step_WIC_PHN_S30_ROUTED` | TRANSFORM | `WRK_WIC_PHN_S30_ROUTED` | `WRK_WIC_PHN_S20_CHECKED` |
| 40 | `sp_snow_step_WIC_PHN_S40_READY` | TRANSFORM | `WRK_WIC_PHN_S40_READY` | `WRK_WIC_PHN_S30_ROUTED` |
| 50 | `sp_snow_pub_WIC_PHN_C_S_WIC_PTY_RLE_PHN` | SPINE | `C_S_WIC_PTY_RLE_PHN` (good phones) | `WRK_WIC_PHN_S40_READY` |
| 60 | `sp_snow_pub_WIC_PHN_EXC_STG_BAD_REC_MEMB_PHONE` | EXCEPTION | `EXC_STG_BAD_REC_MEMB` (bad-phone exceptions) | `WRK_WIC_PHN_S40_READY` |
| 70 | `sp_snow_pub_WIC_PHN_C_S_WIC_PTY_RLE_EADDR` | SPINE | `C_S_WIC_PTY_RLE_EADDR` (valid e-mails) | `WRK_WIC_PHN_S40_READY` |
| 80 | `sp_snow_pub_WIC_PHN_EXC_STG_BAD_REC_MEMB_EMAIL` | EXCEPTION | `EXC_STG_BAD_REC_MEMB` (bad-e-mail exceptions) | `WRK_WIC_PHN_S40_READY` |

Step 5: drops `WRK_WIC_PHN_S10_SRC`, `WRK_WIC_PHN_S20_CHECKED`, `WRK_WIC_PHN_S30_ROUTED`, `WRK_WIC_PHN_S40_READY` — bare `DROP TABLE IF EXISTS`. Publish branches run inside ONE transaction; the first branch takes step number 50, +10 per branch.

## ALT — `m_Tgt_C_S_WIC_Pty_Rle_Alt_Id`

Driver: `drivers/driver_sp_snow_main_m_Tgt_C_S_WIC_Pty_Rle_Alt_Id.sql`. Manifest: `manifests/ALT_MANIFEST.md`.

| STEP_NO | Proc | Kind | Produces / Target | Consumes |
|---|---|---|---|---|
| 10 | `sp_snow_step_WIC_ALT_S10_KEYS` | TRANSFORM | `WRK_WIC_ALT_S10_KEYS` | `` |
| 20 | `sp_snow_step_WIC_ALT_S20_READY` | TRANSFORM | `WRK_WIC_ALT_S20_READY` | `WRK_WIC_ALT_S10_KEYS` |
| 30 | `sp_snow_pub_WIC_ALT_C_S_WIC_PTY_RLE_ALT_ID` | SPINE | `C_S_WIC_PTY_RLE_ALT_ID` (one alternate id per active party) | `WRK_WIC_ALT_S20_READY` |

Step 5: drops `WRK_WIC_ALT_S10_KEYS`, `WRK_WIC_ALT_S20_READY` — bare `DROP TABLE IF EXISTS`. Publish branches run inside ONE transaction; the first branch takes step number 30, +10 per branch.

---

# TTF Step Map (bare-bones variant)

Same step maps as v2.1, minus checkpoint and config columns. Step 5 in
every mapping is the bare work-table cleanup (DROP TABLE IF EXISTS for
that mapping's work tables, no other action). Publish branches run in
one transaction, in the order listed.

## m_Tgt_C_S_TTF_Pty_Validation

Driver: `sp_snow_main_m_Tgt_C_S_TTF_Pty_Validation`

| Step | Proc | Produces | Consumes |
|---|---|---|---|
| 10 | `sp_snow_step_TTF_VAL_S10_ENRICHED` | `WRK_TTF_VAL_S1_ENRICHED` | `(base source tables)` |
| 20 | `sp_snow_step_TTF_VAL_S20_NAMED` | `WRK_TTF_VAL_S2_NAMED` | `WRK_TTF_VAL_S1_ENRICHED` |
| 30 | `sp_snow_step_TTF_VAL_S30_ROUTED` | `WRK_TTF_VAL_S3_ROUTED` | `WRK_TTF_VAL_S2_NAMED` |

| Branch step | Proc | Target | Consumes | Keeps P_RUN_TS |
|---|---|---|---|---|
| 40 | `sp_snow_pub_TTF_VAL_EXC_STG_BAD_REC_MEMB` | `EXC_STG_BAD_REC_MEMB` | `WRK_TTF_VAL_S3_ROUTED` | N |
| 50 | `sp_snow_pub_TTF_VAL_STG_TTF_PTY_INACTIVE_LOG_DEACTIVATION` | `STG_TTF_PTY_INACTIVE_LOG` | `WRK_TTF_VAL_S3_ROUTED` | N |
| 60 | `sp_snow_pub_TTF_VAL_STG_TTF_PTY_INACTIVE_STS` | `STG_TTF_PTY_INACTIVE_STS` | `WRK_TTF_VAL_S3_ROUTED` | N |
| 70 | `sp_snow_pub_TTF_VAL_STG_TTF_PTY_INACTIVE_LOG_REACTIVATION` | `STG_TTF_PTY_INACTIVE_LOG` | `WRK_TTF_VAL_S3_ROUTED` | N |

## m_Tgt_C_S_TTF_Pty

Driver: `sp_snow_main_m_Tgt_C_S_TTF_Pty`

| Step | Proc | Produces | Consumes |
|---|---|---|---|
| 10 | `sp_snow_step_TTF_PTY_S10_ACTIVE` | `WRK_TTF_PTY_S1_ACTIVE` | `(base source tables)` |
| 20 | `sp_snow_step_TTF_PTY_S20_DQ` | `WRK_TTF_PTY_S2_DQ` | `WRK_TTF_PTY_S1_ACTIVE` |
| 30 | `sp_snow_step_TTF_PTY_S30_DQ2` | `WRK_TTF_PTY_S3_DQ2` | `WRK_TTF_PTY_S2_DQ` |
| 40 | `sp_snow_step_TTF_PTY_S40_ROUTED` | `WRK_TTF_PTY_S4_ROUTED` | `WRK_TTF_PTY_S3_DQ2` |

| Branch step | Proc | Target | Consumes | Keeps P_RUN_TS |
|---|---|---|---|---|
| 50 | `sp_snow_pub_TTF_PTY_C_S_TTF_PTY` | `C_S_TTF_PTY` | `WRK_TTF_PTY_S4_ROUTED` | N |
| 60 | `sp_snow_pub_TTF_PTY_C_S_TTF_PTY_RLE` | `C_S_TTF_PTY_RLE` | `WRK_TTF_PTY_S4_ROUTED` | N |
| 70 | `sp_snow_pub_TTF_PTY_EXC_STG_BAD_REC_MEMB_GENDER` | `EXC_STG_BAD_REC_MEMB` | `WRK_TTF_PTY_S4_ROUTED` | N |
| 80 | `sp_snow_pub_TTF_PTY_EXC_STG_BAD_REC_MEMB_BIRTH` | `EXC_STG_BAD_REC_MEMB` | `WRK_TTF_PTY_S4_ROUTED` | N |
| 90 | `sp_snow_pub_TTF_PTY_EXC_STG_BAD_REC_MEMB_ETHNICITY` | `EXC_STG_BAD_REC_MEMB` | `WRK_TTF_PTY_S4_ROUTED` | N |
| 100 | `sp_snow_pub_TTF_PTY_EXC_STG_BAD_REC_MEMB_RACE` | `EXC_STG_BAD_REC_MEMB` | `WRK_TTF_PTY_S4_ROUTED` | N |

## m_Tgt_C_S_TTF_Pty_Rle_Alt_Id

Driver: `sp_snow_main_m_Tgt_C_S_TTF_Pty_Rle_Alt_Id`

| Step | Proc | Produces | Consumes |
|---|---|---|---|
| 10 | `sp_snow_step_TTF_ALT_S10_KEYS` | `WRK_TTF_ALT_S1_KEYS` | `(base source tables)` |
| 20 | `sp_snow_step_TTF_ALT_S20_DEDUP` | `WRK_TTF_ALT_S2_DEDUP` | `WRK_TTF_ALT_S1_KEYS` |

| Branch step | Proc | Target | Consumes | Keeps P_RUN_TS |
|---|---|---|---|---|
| 30 | `sp_snow_pub_TTF_ALT_C_S_TTF_PTY_RLE_ALT_ID` | `C_S_TTF_PTY_RLE_ALT_ID` | `WRK_TTF_ALT_S2_DEDUP` | Y |

## m_Tgt_C_S_TTF_Pty_Rle_Phn

Driver: `sp_snow_main_m_Tgt_C_S_TTF_Pty_Rle_Phn`

| Step | Proc | Produces | Consumes |
|---|---|---|---|
| 10 | `sp_snow_step_TTF_PHN_S10_SRC` | `WRK_TTF_PHN_S1_SRC` | `(base source tables)` |
| 20 | `sp_snow_step_TTF_PHN_S20_CHECKED` | `WRK_TTF_PHN_S2_CHECKED` | `WRK_TTF_PHN_S1_SRC` |
| 30 | `sp_snow_step_TTF_PHN_S30_ROUTED` | `WRK_TTF_PHN_S3_ROUTED` | `WRK_TTF_PHN_S2_CHECKED` |

| Branch step | Proc | Target | Consumes | Keeps P_RUN_TS |
|---|---|---|---|---|
| 40 | `sp_snow_pub_TTF_PHN_C_S_TTF_PTY_RLE_PHN` | `C_S_TTF_PTY_RLE_PHN` | `WRK_TTF_PHN_S3_ROUTED` | N |
| 50 | `sp_snow_pub_TTF_PHN_EXC_STG_BAD_REC_MEMB` | `EXC_STG_BAD_REC_MEMB` | `WRK_TTF_PHN_S3_ROUTED` | N |

---

# FSS step map -- bare-bones step driver (wf_FSS_Stage_Load)

Install schema is `FSS_ETL_WRK` in database `MDM_ETL_FSS`. All table names in the procedures are unqualified. Driver names are identical to the v2.1 drivers; driver signatures are the v2.1 signatures minus `P_JOB_RUN_ID`. Step signatures are the step's used original params + `P_RUN_TS`. Branch signatures are `P_RUN_TS` only where the INSERT references `:P_RUN_TS`, otherwise no arguments. There is no config table, no checkpoint table, and no seed file.

Workflow run order (unchanged from `run_wf_FSS_Stage_Load.sql`):

1. `m_Tgt_C_S_FSS_Pty_Validation` (maintains STG_FSS_PTY_INACTIVE_STS, the deactivation list every later mapping reads)
2. `m_Tgt_C_S_FSS_Pty`
3. `m_Tgt_C_S_FSS_Pty_Addr`
4. `m_Tgt_C_S_FSS_Pty_Rle_Alt_Id`
5. `m_Tgt_C_S_FSS_Pty_Rle_Phn_And_EAddr`
6. `m_Tgt_C_S_FSS_Pty_Rle_Rel`

Every mapping: step 5 cleanup (bare DROPs, no checkpoint) -> unconditional work steps -> ONE publish transaction across all branches -> `RETURN l_summary`. Work tables are left standing after the run. There is no step-level restart -- a restart is simply a new run.

## Mapping -> PREFIX

| Mapping | PREFIX | Driver |
|---|---|---|
| `m_Tgt_C_S_FSS_Pty_Validation` | `FSS_VAL` | `sp_snow_main_m_Tgt_C_S_FSS_Pty_Validation` |
| `m_Tgt_C_S_FSS_Pty` | `FSS_PTY` | `sp_snow_main_m_Tgt_C_S_FSS_Pty` |
| `m_Tgt_C_S_FSS_Pty_Addr` | `FSS_ADR` | `sp_snow_main_m_Tgt_C_S_FSS_Pty_Addr` |
| `m_Tgt_C_S_FSS_Pty_Rle_Alt_Id` | `FSS_ALT` | `sp_snow_main_m_Tgt_C_S_FSS_Pty_Rle_Alt_Id` |
| `m_Tgt_C_S_FSS_Pty_Rle_Phn_And_EAddr` | `FSS_PHN` | `sp_snow_main_m_Tgt_C_S_FSS_Pty_Rle_Phn_And_EAddr` |
| `m_Tgt_C_S_FSS_Pty_Rle_Rel` | `FSS_REL` | `sp_snow_main_m_Tgt_C_S_FSS_Pty_Rle_Rel` |

## Steps and branches

### m_Tgt_C_S_FSS_Pty_Validation (FSS_VAL)

| STEP_NO | Proc | Kind | Target / work table |
|---|---|---|---|
| 10 | `sp_snow_step_FSS_VAL_S10_SRC` | TRANSFORM | `WRK_FSS_VAL_S1_SRC` |
| 20 | `sp_snow_step_FSS_VAL_S20_ENRICHED` | TRANSFORM | `WRK_FSS_VAL_S2_ENRICHED` |
| 30 | `sp_snow_step_FSS_VAL_S30_ROUTED` | TRANSFORM | `WRK_FSS_VAL_S3_ROUTED` |
| 50 | `sp_snow_pub_FSS_VAL_EXC_STG_BAD_REC_MEMB` | EXCEPTION | `EXC_STG_BAD_REC_MEMB` |
| 60 | `sp_snow_pub_FSS_VAL_STG_FSS_PTY_INACTIVE_LOG` | STATUS | `STG_FSS_PTY_INACTIVE_LOG` |
| 70 | `sp_snow_pub_FSS_VAL_STG_FSS_PTY_INACTIVE_STS_NEW` | STATUS | `STG_FSS_PTY_INACTIVE_STS` |
| 80 | `sp_snow_pub_FSS_VAL_STG_FSS_PTY_INACTIVE_STS_REACTIVATION` | STATUS | `STG_FSS_PTY_INACTIVE_STS` |

### m_Tgt_C_S_FSS_Pty (FSS_PTY)

| STEP_NO | Proc | Kind | Target / work table |
|---|---|---|---|
| 10 | `sp_snow_step_FSS_PTY_S10_SRC` | TRANSFORM | `WRK_FSS_PTY_S1_SRC` |
| 20 | `sp_snow_step_FSS_PTY_S20_DQ` | TRANSFORM | `WRK_FSS_PTY_S2_DQ` |
| 30 | `sp_snow_step_FSS_PTY_S30_DQ2` | TRANSFORM | `WRK_FSS_PTY_S3_DQ2` |
| 40 | `sp_snow_step_FSS_PTY_S40_ROUTED` | TRANSFORM | `WRK_FSS_PTY_S4_ROUTED` |
| 50 | `sp_snow_pub_FSS_PTY_C_S_FSS_PTY` | SPINE | `C_S_FSS_PTY` |
| 60 | `sp_snow_pub_FSS_PTY_C_S_FSS_PTY_RLE` | SPINE | `C_S_FSS_PTY_RLE` |
| 70 | `sp_snow_pub_FSS_PTY_EXC_STG_BAD_REC_MEMB_GENDER` | EXCEPTION | `EXC_STG_BAD_REC_MEMB` |
| 80 | `sp_snow_pub_FSS_PTY_EXC_STG_BAD_REC_MEMB_BIRTH` | EXCEPTION | `EXC_STG_BAD_REC_MEMB` |
| 90 | `sp_snow_pub_FSS_PTY_EXC_STG_BAD_REC_MEMB_ETHNICITY` | EXCEPTION | `EXC_STG_BAD_REC_MEMB` |
| 100 | `sp_snow_pub_FSS_PTY_EXC_STG_BAD_REC_MEMB_RACE` | EXCEPTION | `EXC_STG_BAD_REC_MEMB` |
| 110 | `sp_snow_pub_FSS_PTY_EXC_STG_BAD_REC_MEMB_LANGUAGE` | EXCEPTION | `EXC_STG_BAD_REC_MEMB` |
| 120 | `sp_snow_pub_FSS_PTY_EXC_STG_BAD_REC_MEMB_SUFFIX` | EXCEPTION | `EXC_STG_BAD_REC_MEMB` |

### m_Tgt_C_S_FSS_Pty_Addr (FSS_ADR)

| STEP_NO | Proc | Kind | Target / work table |
|---|---|---|---|
| 10 | `sp_snow_step_FSS_ADR_S10_SRC` | TRANSFORM | `WRK_FSS_ADDR_S1_SRC` |
| 20 | `sp_snow_step_FSS_ADR_S20_VALIDATED` | TRANSFORM | `WRK_FSS_ADDR_S2_VALIDATED` |
| 30 | `sp_snow_step_FSS_ADR_S30_FLAT` | TRANSFORM | `WRK_FSS_ADDR_S3_FLAT` |
| 40 | `sp_snow_step_FSS_ADR_S40_SCORED` | TRANSFORM | `WRK_FSS_ADDR_S4_SCORED` |
| 50 | `sp_snow_pub_FSS_ADR_DQM_ADDRESS` | VALIDATION | `DQM_ADDRESS` |
| 60 | `sp_snow_pub_FSS_ADR_C_S_FSS_PTY_RLE_ADDR` | SPINE | `C_S_FSS_PTY_RLE_ADDR` |
| 70 | `sp_snow_pub_FSS_ADR_EXC_STG_BAD_REC_MEMB` | EXCEPTION | `EXC_STG_BAD_REC_MEMB` |

### m_Tgt_C_S_FSS_Pty_Rle_Alt_Id (FSS_ALT)

| STEP_NO | Proc | Kind | Target / work table |
|---|---|---|---|
| 10 | `sp_snow_step_FSS_ALT_S10_SRC` | TRANSFORM | `WRK_FSS_ALT_S1_SRC` |
| 20 | `sp_snow_step_FSS_ALT_S20_FILTERED` | TRANSFORM | `WRK_FSS_ALT_S2_FILTERED` |
| 50 | `sp_snow_pub_FSS_ALT_C_S_FSS_PTY_RLE_ALT_ID` | SPINE | `C_S_FSS_PTY_RLE_ALT_ID` |

### m_Tgt_C_S_FSS_Pty_Rle_Phn_And_EAddr (FSS_PHN)

| STEP_NO | Proc | Kind | Target / work table |
|---|---|---|---|
| 10 | `sp_snow_step_FSS_PHN_S10_SRC` | TRANSFORM | `WRK_FSS_PHN_S1_SRC` |
| 20 | `sp_snow_step_FSS_PHN_S20_DQ` | TRANSFORM | `WRK_FSS_PHN_S2_DQ` |
| 30 | `sp_snow_step_FSS_PHN_S30_CHECKED` | TRANSFORM | `WRK_FSS_PHN_S3_CHECKED` |
| 40 | `sp_snow_step_FSS_PHN_S40_ROUTED` | TRANSFORM | `WRK_FSS_PHN_S4_ROUTED` |
| 50 | `sp_snow_pub_FSS_PHN_C_S_FSS_PTY_RLE_EADDR` | SPINE | `C_S_FSS_PTY_RLE_EADDR` |
| 60 | `sp_snow_pub_FSS_PHN_EXC_STG_BAD_REC_MEMB_EMAIL` | EXCEPTION | `EXC_STG_BAD_REC_MEMB` |
| 70 | `sp_snow_pub_FSS_PHN_C_S_FSS_PTY_RLE_PHN` | SPINE | `C_S_FSS_PTY_RLE_PHN` |
| 80 | `sp_snow_pub_FSS_PHN_EXC_STG_BAD_REC_MEMB_PHONE` | EXCEPTION | `EXC_STG_BAD_REC_MEMB` |
| 90 | `sp_snow_pub_FSS_PHN_EXC_STG_BAD_REC_MEMB_EXTENSION` | EXCEPTION | `EXC_STG_BAD_REC_MEMB` |

### m_Tgt_C_S_FSS_Pty_Rle_Rel (FSS_REL)

| STEP_NO | Proc | Kind | Target / work table |
|---|---|---|---|
| 10 | `sp_snow_step_FSS_REL_S10_SRC` | TRANSFORM | `WRK_FSS_REL_S1_SRC` |
| 20 | `sp_snow_step_FSS_REL_S20_CODED` | TRANSFORM | `WRK_FSS_REL_S2_CODED` |
| 30 | `sp_snow_step_FSS_REL_S30_TYPED` | TRANSFORM | `WRK_FSS_REL_S3_TYPED` |
| 40 | `sp_snow_step_FSS_REL_S40_FINAL` | TRANSFORM | `WRK_FSS_REL_S4_FINAL` |
| 50 | `sp_snow_pub_FSS_REL_C_S_FSS_PTY_RLE_REL` | SPINE | `C_S_FSS_PTY_RLE_REL` |
| 60 | `sp_snow_pub_FSS_REL_EXC_STG_BAD_REC_MEMB` | EXCEPTION | `EXC_STG_BAD_REC_MEMB` |

Totals: 6 drivers + 21 steps + 23 branches = 50 procedures. No seed rows.

---

# STEP_MAP_CRE — CRE bare-bones step-driver package

Source of truth: the step numbers, step names, work tables and publish targets below are copied
from the simplified-v2 CRE main procedure
(`snowflake_multisource/CRE/mappings/sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients.sql`) and its
step map (`snowflake_multisource/CRE/STEP_MAP_CRE.md`). Business logic is unchanged; the only
adaptation is the bare-bones driver split (see the manifest). Prefix: `CRE_CARE`.

## Notes (apply to this mapping)

- **Bare-bones variant:** no config table, no job-control table, no checkpoint calls,
  no `P_JOB_RUN_ID`, no `P_INPUT_TABLES`, no flag/input/publish variables, no seed file.
  The driver runs every step and every publish branch unconditionally and RETURNs the
  summary string; the runner prefixes it with a header line and RETURNs it.
- **Install schema:** all table names are unqualified. Install in schema `CRE_ETL_WRK` in
  database `MDM_ETL_CRE`, so unqualified names resolve to that schema's tables.
- **Step 5 (not listed per step):** `CLEANUP_PREVIOUS_RUN` — bare `DROP TABLE IF EXISTS` for
  this mapping's own work tables only. Every run then rebuilds all steps from scratch; there
  is no step-level resume. Step 5 drops ALL work tables on every run.
- **Publish:** the only step that writes to final targets and the only step inside an explicit
  transaction (one transaction, all branches, or nothing). Work tables are TRANSIENT, are NOT
  dropped at the end of a run, and are left standing until the next run of the same mapping
  cleans them up at its step 5. No step-level resume parameter, no end-of-run drops.
- **Summary:** the driver appends one `fn_snow_helper36_common` line per step (10–50) and per
  publish branch (60–230), in execution order, each carrying that unit's row count. There is
  no longer a single combined publish row, and the members-only headline count (`is_member`)
  is no longer computed as a separate line (same as the v2.1 refactor, where the per-branch
  lines replaced the single step-60 publish row).

## Workflow: wf_CRE_Stage_Load_Ongoing

Runner: `runners/sp_etl_run_wf_CRE_Stage_Load_Ongoing.sql` (run script:
`runners/run_wf_CRE_Stage_Load_Ongoing.sql`). The runner calls the driver with zero arguments.

### 1. m_Tgt_C_S_CRE_CARE_Clients

- Driver file: `drivers/driver_sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients.sql`
- Workflow: `wf_CRE_Stage_Load_Ongoing`
- Original parameters (in order):
  `P_PHYSICAL_ADDR_TYPE_CD` = `'002'`, `P_RLE_BO_CLASS_CD_MEMBER` = `'Member'`,
  `P_DEFAULT_TX_STATE_CD` = `'48'`, `P_COUNTY_CD_NONTX` = `'996'`,
  `P_COUNTYCD_DEFAULTALL` = `'998'`, `P_DEFAULT_NONUS_STATE_CD` = `'99'`
- Steps (step 5 cleanup precedes all of these; see Notes):

| STEP_NO | Proc | Kind | Produces (work table) | Consumes | Original params used |
|---|---|---|---|---|---|
| 10 | `sp_snow_step_CRE_CARE_S10_SRC_MRG` | TRANSFORM | `WRK_CRE_CARE_S1_SRC_MRG` | _(none — base source tables)_ | none |
| 20 | `sp_snow_step_CRE_CARE_S20_NAMED` | TRANSFORM | `WRK_CRE_CARE_S2_NAMED` | `WRK_CRE_CARE_S1_SRC_MRG` | none |
| 30 | `sp_snow_step_CRE_CARE_S30_RANKED` | TRANSFORM | `WRK_CRE_CARE_S3_RANKED` | `WRK_CRE_CARE_S2_NAMED` | none |
| 40 | `sp_snow_step_CRE_CARE_S40_FLAT` | TRANSFORM | `WRK_CRE_CARE_S4_FLAT` | `WRK_CRE_CARE_S3_RANKED` | `P_RLE_BO_CLASS_CD_MEMBER`, `P_DEFAULT_NONUS_STATE_CD` |
| 50 | `sp_snow_step_CRE_CARE_S50_KEYED` | TRANSFORM | `WRK_CRE_CARE_S5_KEYED` | `WRK_CRE_CARE_S4_FLAT` | `P_PHYSICAL_ADDR_TYPE_CD`, `P_RLE_BO_CLASS_CD_MEMBER`, `P_DEFAULT_TX_STATE_CD`, `P_COUNTY_CD_NONTX`, `P_COUNTYCD_DEFAULTALL` |

- Work-table mapping, prescribed steps S1–S5 (names preserved verbatim from the main):

| Prescribed step | Work table | Contents |
|---|---|---|
| S1 (step 10) | `WRK_CRE_CARE_S1_SRC_MRG` | CARE snapshot + merge routing (original CTEs: `src`, `xref`, `hmrg_src`, `hmrg_tgt`, routed select) |
| S2 (step 20) | `WRK_CRE_CARE_S2_NAMED` | Name standardisation + member validity (original CTEs: `named`, members select) |
| S3 (step 30) | `WRK_CRE_CARE_S3_RANKED` | Rank per CARE id + validation enrichment (original CTEs: `ranked`, `dq`, `dq2`) |
| S4 (step 40) | `WRK_CRE_CARE_S4_FLAT` | Flattened load-ready rows (original CTEs: `alt_tp`, `flat`) |
| S5 (step 50) | `WRK_CRE_CARE_S5_KEYED` | Route flags + unique-key guards (original CTEs: `keyed` + final select) |

- Publish branches (one per original publish INSERT, in original order; all consume
  `WRK_CRE_CARE_S5_KEYED`; all inside ONE driver transaction):

| STEP_NO | Proc | Kind | Target | Original branch |
|---|---|---|---|---|
| 60 | `sp_snow_pub_CRE_CARE_CRE_SRC_MRG` | STATUS | `CRE_SRC_MRG` | 60a |
| 70 | `sp_snow_pub_CRE_CARE_EXC_STG_BAD_REC_MEMB_FIRST_NAME` | EXCEPTION | `EXC_STG_BAD_REC_MEMB` | 60b |
| 80 | `sp_snow_pub_CRE_CARE_EXC_STG_BAD_REC_MEMB_LAST_NAME` | EXCEPTION | `EXC_STG_BAD_REC_MEMB` | 60c |
| 90 | `sp_snow_pub_CRE_CARE_C_S_CRE_PTY` | SPINE | `C_S_CRE_PTY` | 60d |
| 100 | `sp_snow_pub_CRE_CARE_C_S_CRE_PTY_RLE` | SPINE | `C_S_CRE_PTY_RLE` | 60e |
| 110 | `sp_snow_pub_CRE_CARE_EXC_STG_BAD_REC_MEMB_GENDER` | EXCEPTION | `EXC_STG_BAD_REC_MEMB` | 60f |
| 120 | `sp_snow_pub_CRE_CARE_EXC_STG_BAD_REC_MEMB_SUFFIX` | EXCEPTION | `EXC_STG_BAD_REC_MEMB` | 60g |
| 130 | `sp_snow_pub_CRE_CARE_EXC_STG_BAD_REC_MEMB_ETHNICITY` | EXCEPTION | `EXC_STG_BAD_REC_MEMB` | 60h |
| 140 | `sp_snow_pub_CRE_CARE_EXC_STG_BAD_REC_MEMB_RACE` | EXCEPTION | `EXC_STG_BAD_REC_MEMB` | 60i |
| 150 | `sp_snow_pub_CRE_CARE_C_S_CRE_PTY_RLE_ADDR` | SPINE | `C_S_CRE_PTY_RLE_ADDR` | 60j |
| 160 | `sp_snow_pub_CRE_CARE_EXC_STG_BAD_REC_MEMB_ADDR` | EXCEPTION | `EXC_STG_BAD_REC_MEMB` | 60k |
| 170 | `sp_snow_pub_CRE_CARE_C_S_CRE_PTY_RLE_PHN` | SPINE | `C_S_CRE_PTY_RLE_PHN` | 60l |
| 180 | `sp_snow_pub_CRE_CARE_EXC_STG_BAD_REC_MEMB_PHONE` | EXCEPTION | `EXC_STG_BAD_REC_MEMB` | 60m |
| 190 | `sp_snow_pub_CRE_CARE_C_S_CRE_PTY_RLE_ALT_ID_CARE` | SPINE | `C_S_CRE_PTY_RLE_ALT_ID` | 60n |
| 200 | `sp_snow_pub_CRE_CARE_C_S_CRE_PTY_RLE_ALT_ID_MEDICAID` | SPINE | `C_S_CRE_PTY_RLE_ALT_ID` | 60o |
| 210 | `sp_snow_pub_CRE_CARE_EXC_STG_BAD_REC_MEMB_MEDICAID_ALT` | EXCEPTION | `EXC_STG_BAD_REC_MEMB` | 60p |
| 220 | `sp_snow_pub_CRE_CARE_C_S_CRE_PTY_RLE_ALT_ID_SSN` | SPINE | `C_S_CRE_PTY_RLE_ALT_ID` | 60q |
| 230 | `sp_snow_pub_CRE_CARE_EXC_STG_BAD_REC_MEMB_SSN_ALT` | EXCEPTION | `EXC_STG_BAD_REC_MEMB` | 60r |

- Publish targets (7): `CRE_SRC_MRG`, `C_S_CRE_PTY`, `C_S_CRE_PTY_RLE`,
  `C_S_CRE_PTY_RLE_ADDR`, `C_S_CRE_PTY_RLE_PHN`, `C_S_CRE_PTY_RLE_ALT_ID`,
  `EXC_STG_BAD_REC_MEMB`.
- Spine vs non-spine: the spine path is the `C_S_*` writes (steps 90, 100, 150, 170,
  190, 200, 220) plus the merge-routing `CRE_SRC_MRG` write (step 60, kind STATUS); the
  non-spine path is the `EXC_STG_BAD_REC_MEMB` exception writes (all other branches).

