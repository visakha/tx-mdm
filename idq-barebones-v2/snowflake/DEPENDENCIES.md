# DEPENDENCIES — bare-bones work-table producer/consumer chains (all sources)

No config table exists in this variant, so there are no config columns. Each mapping's chain is: step produces exactly one work table; the next step consumes it; publish branches consume the final ready table(s). Assembled from the per-source fragments (content unchanged).

---

# DEPENDENCIES_TRS — TRS bare-bones work-table dependencies

Bare-bones fragment for coordinator assembly. Every unit, its produced and
consumed work tables (pipe-delimited). No run-config columns.

## Rules

- Work-table dependencies are INTRA-mapping only: verified by scanning
  every step CTAS and publish INSERT — no step or branch reads a work
  table produced by a different mapping. Cross-mapping coupling happens
  only through final/staging tables and through runner order (below),
  never through WRK_TRS_* tables.
- A step whose consumed list is empty reads base/staging tables only
  (step 10 of every mapping, and RELDEACT step 40, which reads the MDM
  cross-reference from base tables).

## Dependency chains in words

- **Runner order, wf_TRS_Stage_Load_1_Ongoing**: PTY first (it builds
  STG_TRS_VALID_MEMBERS, which every later mapping joins to), then PTYDEACT,
  TOA, REL1, RELDEACT, REL2, PHN, MNGSW, AUTHREP (after MNGSW: it appends
  to the table MNGSW loads), NM, ALT, PLN, ADDR1, ADDR2 (after ADDR1: it
  reads the unique addresses of part 1, STG_TRS_D_UNQ_ADDR).
- **Runner order, wf_TRS_Stage_Load_TOA**: STGTOA alone (TOA reference
  catalogue into C_S_LU_TOA).
- **Within each mapping**, the chain is the step order in its manifest,
  with two branch exceptions: PTY step 40 reads step 20, NOT step 30
  (exceptions and valid rows are two branches of the same DQ output);
  REL1/REL2 step 40 reads step 20, NOT step 30 (valid relationships only,
  router exceptions are a side branch); PHN step 60 reads step 10, NOT
  step 50 (emails branch off the source, not off phone versions);
  RELDEACT step 50 reads steps 30 AND 40.
- **PTYDEACT step 50** follows the publish step (40) only in sequence:
  it records a decision after publish and consumes no table.

## Chains per mapping

- **m_Tgt_C_S_TRS_Pty_OnGoing**: step 10 (`sp_snow_step_TRS_PTY_S10_SRC`) produces `WRK_TRS_PTY_S1_SRC` from base tables; step 20 (`sp_snow_step_TRS_PTY_S20_DQ`) produces `WRK_TRS_PTY_S2_DQ` from WRK_TRS_PTY_S1_SRC; step 30 (`sp_snow_step_TRS_PTY_S30_ROUTER`) produces `WRK_TRS_PTY_S3_ROUTER` from WRK_TRS_PTY_S2_DQ; step 40 (`sp_snow_step_TRS_PTY_S40_DEDUP`) produces `WRK_TRS_PTY_S4_DEDUP` from WRK_TRS_PTY_S2_DQ; step 50 (`sp_snow_pub_TRS_PTY_EXC_STG_BAD_REC_MEMB_NAME`) publishes `EXC_STG_BAD_REC_MEMB` from WRK_TRS_PTY_S3_ROUTER; step 60 (`sp_snow_pub_TRS_PTY_EXC_STG_BAD_REC_MEMB_GENDER`) publishes `EXC_STG_BAD_REC_MEMB` from WRK_TRS_PTY_S3_ROUTER; step 70 (`sp_snow_pub_TRS_PTY_EXC_STG_BAD_REC_MEMB_DEATH`) publishes `EXC_STG_BAD_REC_MEMB` from WRK_TRS_PTY_S3_ROUTER; step 80 (`sp_snow_pub_TRS_PTY_EXC_STG_BAD_REC_MEMB_BIRTH`) publishes `EXC_STG_BAD_REC_MEMB` from WRK_TRS_PTY_S3_ROUTER; step 90 (`sp_snow_pub_TRS_PTY_C_S_TRS_PTY`) publishes `C_S_TRS_PTY` from WRK_TRS_PTY_S4_DEDUP; step 100 (`sp_snow_pub_TRS_PTY_C_S_TRS_PTY_RLE`) publishes `C_S_TRS_PTY_RLE` from WRK_TRS_PTY_S4_DEDUP; step 110 (`sp_snow_pub_TRS_PTY_STG_TRS_VALID_MEMBERS`) publishes `STG_TRS_VALID_MEMBERS` from WRK_TRS_PTY_S4_DEDUP; step 120 (`sp_snow_pub_TRS_PTY_EXC_STG_BAD_REC_MEMB_RACE`) publishes `EXC_STG_BAD_REC_MEMB` from WRK_TRS_PTY_S4_DEDUP; step 130 (`sp_snow_pub_TRS_PTY_EXC_STG_BAD_REC_MEMB_ETHNICITY`) publishes `EXC_STG_BAD_REC_MEMB` from WRK_TRS_PTY_S4_DEDUP.
- **m_Tgt_C_S_TRS_Pty_Deactivation_1**: step 10 (`sp_snow_step_TRS_PTYDEACT_S10_DEACTV`) produces `WRK_TRS_DEACT1_S10_DEACTV` from base tables; step 20 (`sp_snow_step_TRS_PTYDEACT_S20_DEACTV_ID`) produces `WRK_TRS_DEACT1_S20_DEACTV_ID` from WRK_TRS_DEACT1_S10_DEACTV; step 30 (`sp_snow_step_TRS_PTYDEACT_S30_READY`) produces `WRK_TRS_DEACT1_S30_READY` from WRK_TRS_DEACT1_S20_DEACTV_ID; step 40 (`sp_snow_pub_TRS_PTYDEACT_STG_TRS_DEACTIVED_MEMBERS`) publishes `STG_TRS_DEACTIVED_MEMBERS` from WRK_TRS_DEACT1_S30_READY; step 50 (`sp_snow_step_TRS_PTYDEACT_S50_NOTPERFORMED`) records after publish and consumes nothing.
- **m_Tgt_C_S_TRS_Pty_Rle_TOA**: step 10 (`sp_snow_step_TRS_TOA_S10_RAW`) produces `WRK_TRS_TOA_S10_RAW` from base tables; step 20 (`sp_snow_step_TRS_TOA_S20_LATEST`) produces `WRK_TRS_TOA_S20_SRC` from WRK_TRS_TOA_S10_RAW; step 30 (`sp_snow_step_TRS_TOA_S30_KEYED`) produces `WRK_TRS_TOA_S30_KEYED` from WRK_TRS_TOA_S20_SRC; step 40 (`sp_snow_step_TRS_TOA_S40_RANKED`) produces `WRK_TRS_TOA_S40_RANKED` from WRK_TRS_TOA_S30_KEYED; step 50 (`sp_snow_pub_TRS_TOA_EXC_STG_BAD_REC_MEMB_BAD_VALUE`) publishes `EXC_STG_BAD_REC_MEMB` from WRK_TRS_TOA_S40_RANKED; step 60 (`sp_snow_pub_TRS_TOA_EXC_STG_BAD_REC_MEMB_DATES`) publishes `EXC_STG_BAD_REC_MEMB` from WRK_TRS_TOA_S40_RANKED; step 70 (`sp_snow_pub_TRS_TOA_C_S_TRS_PTY_RLE_TOA`) publishes `C_S_TRS_PTY_RLE_TOA` from WRK_TRS_TOA_S40_RANKED.
- **m_Tgt_C_S_TRS_Pty_Rle_Rel_1_Mem_To_Mem**: step 10 (`sp_snow_step_TRS_REL1_S10_SRC`) produces `WRK_TRS_REL1_S1_SRC` from base tables; step 20 (`sp_snow_step_TRS_REL1_S20_KEYED`) produces `WRK_TRS_REL1_S2_KEYED` from WRK_TRS_REL1_S1_SRC; step 30 (`sp_snow_step_TRS_REL1_S30_ROUTER`) produces `WRK_TRS_REL1_S3_ROUTER` from WRK_TRS_REL1_S2_KEYED; step 40 (`sp_snow_step_TRS_REL1_S40_CONSOL`) produces `WRK_TRS_REL1_S4_CONSOL` from WRK_TRS_REL1_S2_KEYED; step 50 (`sp_snow_step_TRS_REL1_S50_PREP`) produces `WRK_TRS_REL1_S5_PREP` from WRK_TRS_REL1_S4_CONSOL; step 60 (`sp_snow_step_TRS_REL1_S60_TIMELINE`) produces `WRK_TRS_REL1_S6_TIMELINE` from WRK_TRS_REL1_S5_PREP; step 70 (`sp_snow_pub_TRS_REL1_EXC_STG_BAD_REC_MEMB_MAIN_ALT_ID`) publishes `EXC_STG_BAD_REC_MEMB` from WRK_TRS_REL1_S3_ROUTER; step 80 (`sp_snow_pub_TRS_REL1_EXC_STG_BAD_REC_MEMB_REF_ALT_ID`) publishes `EXC_STG_BAD_REC_MEMB` from WRK_TRS_REL1_S3_ROUTER; step 90 (`sp_snow_pub_TRS_REL1_EXC_STG_BAD_REC_MEMB_LOOKUP`) publishes `EXC_STG_BAD_REC_MEMB` from WRK_TRS_REL1_S3_ROUTER; step 100 (`sp_snow_pub_TRS_REL1_EXC_STG_BAD_REC_MEMB_DATES`) publishes `EXC_STG_BAD_REC_MEMB` from WRK_TRS_REL1_S3_ROUTER; step 110 (`sp_snow_pub_TRS_REL1_C_S_TRS_PTY_RLE_REL`) publishes `C_S_TRS_PTY_RLE_REL` from WRK_TRS_REL1_S6_TIMELINE.
- **m_Tgt_C_S_TRS_Pty_Rle_Rel_DeActivation_1**: step 10 (`sp_snow_step_TRS_RELDEACT_S10_MINPK`) produces `WRK_TRS_RELDEACT_S10_MINPK` from base tables; step 20 (`sp_snow_step_TRS_RELDEACT_S20_SRC`) produces `WRK_TRS_RELDEACT_S20_SRC` from WRK_TRS_RELDEACT_S10_MINPK; step 30 (`sp_snow_step_TRS_RELDEACT_S30_KEYED`) produces `WRK_TRS_RELDEACT_S30_KEYED` from WRK_TRS_RELDEACT_S20_SRC; step 40 (`sp_snow_step_TRS_RELDEACT_S40_XREF`) produces `WRK_TRS_RELDEACT_S40_XREF` from base tables; step 50 (`sp_snow_step_TRS_RELDEACT_S50_READY`) produces `WRK_TRS_RELDEACT_S50_READY` from WRK_TRS_RELDEACT_S30_KEYED|WRK_TRS_RELDEACT_S40_XREF; step 60 (`sp_snow_pub_TRS_RELDEACT_STG_TRS_DEACTIVATED_RELATIONSHIPS`) publishes `STG_TRS_DEACTIVATED_RELATIONSHIPS` from WRK_TRS_RELDEACT_S50_READY.
- **m_Tgt_C_S_TRS_Pty_Rle_Rel_2_Mem_To_PCP**: step 10 (`sp_snow_step_TRS_REL2_S10_SRC`) produces `WRK_TRS_REL2_S1_SRC` from base tables; step 20 (`sp_snow_step_TRS_REL2_S20_KEYED`) produces `WRK_TRS_REL2_S2_KEYED` from WRK_TRS_REL2_S1_SRC; step 30 (`sp_snow_step_TRS_REL2_S30_ROUTER`) produces `WRK_TRS_REL2_S3_ROUTER` from WRK_TRS_REL2_S2_KEYED; step 40 (`sp_snow_step_TRS_REL2_S40_CONSOL`) produces `WRK_TRS_REL2_S4_CONSOL` from WRK_TRS_REL2_S2_KEYED; step 50 (`sp_snow_step_TRS_REL2_S50_PREP`) produces `WRK_TRS_REL2_S5_PREP` from WRK_TRS_REL2_S4_CONSOL; step 60 (`sp_snow_step_TRS_REL2_S60_TIMELINE`) produces `WRK_TRS_REL2_S6_TIMELINE` from WRK_TRS_REL2_S5_PREP; step 70 (`sp_snow_pub_TRS_REL2_EXC_STG_BAD_REC_MEMB_DATES`) publishes `EXC_STG_BAD_REC_MEMB` from WRK_TRS_REL2_S3_ROUTER; step 80 (`sp_snow_pub_TRS_REL2_EXC_STG_BAD_REC_MEMB_DEFAULT`) publishes `EXC_STG_BAD_REC_MEMB` from WRK_TRS_REL2_S3_ROUTER; step 90 (`sp_snow_pub_TRS_REL2_C_S_TRS_PTY_RLE_REL_PROV`) publishes `C_S_TRS_PTY_RLE_REL_PROV` from WRK_TRS_REL2_S6_TIMELINE.
- **m_Tgt_C_S_TRS_Pty_Rle_Phn_And_EAddr**: step 10 (`sp_snow_step_TRS_PHN_S10_SRC`) produces `WRK_TRS_PHN_S1_SRC` from base tables; step 20 (`sp_snow_step_TRS_PHN_S20_SLOTS`) produces `WRK_TRS_PHN_S2_SLOTS` from WRK_TRS_PHN_S1_SRC; step 30 (`sp_snow_step_TRS_PHN_S30_CHECKED`) produces `WRK_TRS_PHN_S3_CHECKED` from WRK_TRS_PHN_S2_SLOTS; step 40 (`sp_snow_step_TRS_PHN_S40_PHONES`) produces `WRK_TRS_PHN_S4_PHONES` from WRK_TRS_PHN_S3_CHECKED; step 50 (`sp_snow_step_TRS_PHN_S50_VERSIONS`) produces `WRK_TRS_PHN_S5_VERSIONS` from WRK_TRS_PHN_S4_PHONES; step 60 (`sp_snow_step_TRS_PHN_S60_EMAILS`) produces `WRK_TRS_PHN_S6_EMAILS` from WRK_TRS_PHN_S1_SRC; step 70 (`sp_snow_step_TRS_PHN_S70_EADDR`) produces `WRK_TRS_PHN_S7_VERSIONS` from WRK_TRS_PHN_S6_EMAILS; step 80 (`sp_snow_pub_TRS_PHN_C_S_TRS_PTY_RLE_PHN`) publishes `C_S_TRS_PTY_RLE_PHN` from WRK_TRS_PHN_S5_VERSIONS; step 90 (`sp_snow_pub_TRS_PHN_EXC_STG_BAD_REC_MEMB_PHONE`) publishes `EXC_STG_BAD_REC_MEMB` from WRK_TRS_PHN_S4_PHONES; step 100 (`sp_snow_pub_TRS_PHN_C_S_TRS_PTY_RLE_EADDR`) publishes `C_S_TRS_PTY_RLE_EADDR` from WRK_TRS_PHN_S7_VERSIONS; step 110 (`sp_snow_pub_TRS_PHN_EXC_STG_BAD_REC_MEMB_EMAIL`) publishes `EXC_STG_BAD_REC_MEMB` from WRK_TRS_PHN_S6_EMAILS.
- **m_Tgt_C_S_TRS_Pty_Mng_Attr_Sw**: step 10 (`sp_snow_step_TRS_MNGSW_S10_DAILY`) produces `WRK_TRS_MNGSW_S10_DAILY` from base tables; step 20 (`sp_snow_step_TRS_MNGSW_S20_SRC`) produces `WRK_TRS_MNGSW_S20_SRC` from WRK_TRS_MNGSW_S10_DAILY; step 30 (`sp_snow_step_TRS_MNGSW_S30_NORM`) produces `WRK_TRS_MNGSW_S30_NORM` from WRK_TRS_MNGSW_S20_SRC; step 40 (`sp_snow_step_TRS_MNGSW_S40_ATTRS`) produces `WRK_TRS_MNGSW_S40_ATTRS` from WRK_TRS_MNGSW_S30_NORM; step 50 (`sp_snow_pub_TRS_MNGSW_C_S_TRS_PTY_MNG_ATTR`) publishes `C_S_TRS_PTY_MNG_ATTR` from WRK_TRS_MNGSW_S40_ATTRS.
- **m_Tgt_C_S_TRS_Pty_Mng_Attr_Auth_Rep_Ongoing**: step 10 (`sp_snow_step_TRS_AUTHREP_S10_PAYEE`) produces `WRK_TRS_MNGAR_S10_PAYEE` from base tables; step 20 (`sp_snow_step_TRS_AUTHREP_S20_SRC`) produces `WRK_TRS_MNGAR_S20_SRC` from WRK_TRS_MNGAR_S10_PAYEE; step 30 (`sp_snow_step_TRS_AUTHREP_S30_KEYED`) produces `WRK_TRS_MNGAR_S30_KEYED` from WRK_TRS_MNGAR_S20_SRC; step 40 (`sp_snow_step_TRS_AUTHREP_S40_AGG`) produces `WRK_TRS_MNGAR_S40_AGG` from WRK_TRS_MNGAR_S30_KEYED; step 50 (`sp_snow_pub_TRS_AUTHREP_C_S_TRS_PTY_MNG_ATTR`) publishes `C_S_TRS_PTY_MNG_ATTR` from WRK_TRS_MNGAR_S40_AGG.
- **m_Tgt_C_S_TRS_Pty_Nm**: step 10 (`sp_snow_step_TRS_NM_S10_SRC`) produces `WRK_TRS_NM_S10_SRC` from base tables; step 20 (`sp_snow_step_TRS_NM_S20_NAMED`) produces `WRK_TRS_NM_S20_NAMED` from WRK_TRS_NM_S10_SRC; step 30 (`sp_snow_step_TRS_NM_S30_STD`) produces `WRK_TRS_NM_S30_STD` from WRK_TRS_NM_S20_NAMED; step 40 (`sp_snow_step_TRS_NM_S40_DEDUP`) produces `WRK_TRS_NM_S40_DEDUP` from WRK_TRS_NM_S30_STD; step 50 (`sp_snow_pub_TRS_NM_C_S_TRS_PTY_NM`) publishes `C_S_TRS_PTY_NM` from WRK_TRS_NM_S40_DEDUP.
- **m_Tgt_C_S_TRS_Pty_Rle_Alt_Id**: step 10 (`sp_snow_step_TRS_ALT_S10_SRC`) produces `WRK_TRS_ALT_S1_SRC` from base tables; step 20 (`sp_snow_step_TRS_ALT_S20_SSN`) produces `WRK_TRS_ALT_S2_SSN` from WRK_TRS_ALT_S1_SRC; step 30 (`sp_snow_step_TRS_ALT_S30_NORM`) produces `WRK_TRS_ALT_S3_NORM` from WRK_TRS_ALT_S2_SSN; step 40 (`sp_snow_step_TRS_ALT_S40_ROUTED`) produces `WRK_TRS_ALT_S4_ROUTED` from WRK_TRS_ALT_S3_NORM; step 50 (`sp_snow_pub_TRS_ALT_C_S_TRS_PTY_RLE_ALT_ID`) publishes `C_S_TRS_PTY_RLE_ALT_ID` from WRK_TRS_ALT_S4_ROUTED; step 60 (`sp_snow_pub_TRS_ALT_EXC_STG_BAD_REC_MEMB`) publishes `EXC_STG_BAD_REC_MEMB` from WRK_TRS_ALT_S4_ROUTED.
- **m_Tgt_C_S_TRS_Pty_Rle_Pln**: step 10 (`sp_snow_step_TRS_PLN_S10_SRC`) produces `WRK_TRS_PLN_S10_SRC` from base tables; step 20 (`sp_snow_step_TRS_PLN_S20_PLANNED`) produces `WRK_TRS_PLN_S20_PLANNED` from WRK_TRS_PLN_S10_SRC; step 30 (`sp_snow_step_TRS_PLN_S30_RANKED`) produces `WRK_TRS_PLN_S30_RANKED` from WRK_TRS_PLN_S20_PLANNED; step 40 (`sp_snow_pub_TRS_PLN_C_S_TRS_PTY_RLE_PLN`) publishes `C_S_TRS_PTY_RLE_PLN` from WRK_TRS_PLN_S30_RANKED; step 50 (`sp_snow_pub_TRS_PLN_EXC_STG_BAD_REC_MEMB`) publishes `EXC_STG_BAD_REC_MEMB` from WRK_TRS_PLN_S30_RANKED.
- **m_Tgt_C_S_TRS_Addr_1**: step 10 (`sp_snow_step_TRS_ADDR1_S10_SRC`) produces `WRK_TRS_ADDR1_S10_SRC` from base tables; step 20 (`sp_snow_step_TRS_ADDR1_S20_DERIVED`) produces `WRK_TRS_ADDR1_S20_DERIVED` from WRK_TRS_ADDR1_S10_SRC; step 30 (`sp_snow_step_TRS_ADDR1_S30_VALIDATED`) produces `WRK_TRS_ADDR1_S30_VALIDATED` from WRK_TRS_ADDR1_S20_DERIVED; step 40 (`sp_snow_step_TRS_ADDR1_S40_READY`) produces `WRK_TRS_ADDR1_S40_READY` from WRK_TRS_ADDR1_S30_VALIDATED; step 50 (`sp_snow_pub_TRS_ADDR1_STG_TRS_D_UNQ_ADDR`) publishes `STG_TRS_D_UNQ_ADDR` from WRK_TRS_ADDR1_S40_READY.
- **m_Tgt_C_S_TRS_Addr_2**: step 10 (`sp_snow_step_TRS_ADDR2_S10_DEDUP`) produces `WRK_TRS_ADDR2_S10_DEDUP` from base tables; step 20 (`sp_snow_step_TRS_ADDR2_S20_SRC`) produces `WRK_TRS_ADDR2_S20_SRC` from WRK_TRS_ADDR2_S10_DEDUP; step 30 (`sp_snow_step_TRS_ADDR2_S30_KEYED`) produces `WRK_TRS_ADDR2_S30_KEYED` from WRK_TRS_ADDR2_S20_SRC; step 40 (`sp_snow_step_TRS_ADDR2_S40_SCORED`) produces `WRK_TRS_ADDR2_S40_SCORED` from WRK_TRS_ADDR2_S30_KEYED; step 50 (`sp_snow_step_TRS_ADDR2_S50_READY`) produces `WRK_TRS_ADDR2_S50_READY` from WRK_TRS_ADDR2_S40_SCORED; step 60 (`sp_snow_pub_TRS_ADDR2_DQM_ADDRESS`) publishes `DQM_ADDRESS` from WRK_TRS_ADDR2_S50_READY; step 70 (`sp_snow_pub_TRS_ADDR2_C_S_TRS_PTY_RLE_ADDR`) publishes `C_S_TRS_PTY_RLE_ADDR` from WRK_TRS_ADDR2_S50_READY; step 80 (`sp_snow_pub_TRS_ADDR2_EXC_STG_BAD_REC_MEMB`) publishes `EXC_STG_BAD_REC_MEMB` from WRK_TRS_ADDR2_S50_READY.
- **m_Tgt_C_S_TRS_Stg_TOA**: step 10 (`sp_snow_step_TRS_STGTOA_S10_KEYED`) produces `WRK_TRS_LUTOA_S10_KEYED` from base tables; step 20 (`sp_snow_step_TRS_STGTOA_S20_FINAL`) produces `WRK_TRS_LUTOA_S20_FINAL` from WRK_TRS_LUTOA_S10_KEYED; step 30 (`sp_snow_pub_TRS_STGTOA_C_S_LU_TOA`) publishes `C_S_LU_TOA` from WRK_TRS_LUTOA_S20_FINAL.

## All units

| Mapping | STEP_NO | Proc | Produced work table | Consumed work tables |
|---|---|---|---|---|
| m_Tgt_C_S_TRS_Pty_OnGoing | 10 | `sp_snow_step_TRS_PTY_S10_SRC` | WRK_TRS_PTY_S1_SRC |  |
| m_Tgt_C_S_TRS_Pty_OnGoing | 20 | `sp_snow_step_TRS_PTY_S20_DQ` | WRK_TRS_PTY_S2_DQ | WRK_TRS_PTY_S1_SRC |
| m_Tgt_C_S_TRS_Pty_OnGoing | 30 | `sp_snow_step_TRS_PTY_S30_ROUTER` | WRK_TRS_PTY_S3_ROUTER | WRK_TRS_PTY_S2_DQ |
| m_Tgt_C_S_TRS_Pty_OnGoing | 40 | `sp_snow_step_TRS_PTY_S40_DEDUP` | WRK_TRS_PTY_S4_DEDUP | WRK_TRS_PTY_S2_DQ |
| m_Tgt_C_S_TRS_Pty_OnGoing | 50 | `sp_snow_pub_TRS_PTY_EXC_STG_BAD_REC_MEMB_NAME` |  | WRK_TRS_PTY_S3_ROUTER |
| m_Tgt_C_S_TRS_Pty_OnGoing | 60 | `sp_snow_pub_TRS_PTY_EXC_STG_BAD_REC_MEMB_GENDER` |  | WRK_TRS_PTY_S3_ROUTER |
| m_Tgt_C_S_TRS_Pty_OnGoing | 70 | `sp_snow_pub_TRS_PTY_EXC_STG_BAD_REC_MEMB_DEATH` |  | WRK_TRS_PTY_S3_ROUTER |
| m_Tgt_C_S_TRS_Pty_OnGoing | 80 | `sp_snow_pub_TRS_PTY_EXC_STG_BAD_REC_MEMB_BIRTH` |  | WRK_TRS_PTY_S3_ROUTER |
| m_Tgt_C_S_TRS_Pty_OnGoing | 90 | `sp_snow_pub_TRS_PTY_C_S_TRS_PTY` |  | WRK_TRS_PTY_S4_DEDUP |
| m_Tgt_C_S_TRS_Pty_OnGoing | 100 | `sp_snow_pub_TRS_PTY_C_S_TRS_PTY_RLE` |  | WRK_TRS_PTY_S4_DEDUP |
| m_Tgt_C_S_TRS_Pty_OnGoing | 110 | `sp_snow_pub_TRS_PTY_STG_TRS_VALID_MEMBERS` |  | WRK_TRS_PTY_S4_DEDUP |
| m_Tgt_C_S_TRS_Pty_OnGoing | 120 | `sp_snow_pub_TRS_PTY_EXC_STG_BAD_REC_MEMB_RACE` |  | WRK_TRS_PTY_S4_DEDUP |
| m_Tgt_C_S_TRS_Pty_OnGoing | 130 | `sp_snow_pub_TRS_PTY_EXC_STG_BAD_REC_MEMB_ETHNICITY` |  | WRK_TRS_PTY_S4_DEDUP |
| m_Tgt_C_S_TRS_Pty_Deactivation_1 | 10 | `sp_snow_step_TRS_PTYDEACT_S10_DEACTV` | WRK_TRS_DEACT1_S10_DEACTV |  |
| m_Tgt_C_S_TRS_Pty_Deactivation_1 | 20 | `sp_snow_step_TRS_PTYDEACT_S20_DEACTV_ID` | WRK_TRS_DEACT1_S20_DEACTV_ID | WRK_TRS_DEACT1_S10_DEACTV |
| m_Tgt_C_S_TRS_Pty_Deactivation_1 | 30 | `sp_snow_step_TRS_PTYDEACT_S30_READY` | WRK_TRS_DEACT1_S30_READY | WRK_TRS_DEACT1_S20_DEACTV_ID |
| m_Tgt_C_S_TRS_Pty_Deactivation_1 | 40 | `sp_snow_pub_TRS_PTYDEACT_STG_TRS_DEACTIVED_MEMBERS` |  | WRK_TRS_DEACT1_S30_READY |
| m_Tgt_C_S_TRS_Pty_Deactivation_1 | 50 | `sp_snow_step_TRS_PTYDEACT_S50_NOTPERFORMED` |  |  |
| m_Tgt_C_S_TRS_Pty_Rle_TOA | 10 | `sp_snow_step_TRS_TOA_S10_RAW` | WRK_TRS_TOA_S10_RAW |  |
| m_Tgt_C_S_TRS_Pty_Rle_TOA | 20 | `sp_snow_step_TRS_TOA_S20_LATEST` | WRK_TRS_TOA_S20_SRC | WRK_TRS_TOA_S10_RAW |
| m_Tgt_C_S_TRS_Pty_Rle_TOA | 30 | `sp_snow_step_TRS_TOA_S30_KEYED` | WRK_TRS_TOA_S30_KEYED | WRK_TRS_TOA_S20_SRC |
| m_Tgt_C_S_TRS_Pty_Rle_TOA | 40 | `sp_snow_step_TRS_TOA_S40_RANKED` | WRK_TRS_TOA_S40_RANKED | WRK_TRS_TOA_S30_KEYED |
| m_Tgt_C_S_TRS_Pty_Rle_TOA | 50 | `sp_snow_pub_TRS_TOA_EXC_STG_BAD_REC_MEMB_BAD_VALUE` |  | WRK_TRS_TOA_S40_RANKED |
| m_Tgt_C_S_TRS_Pty_Rle_TOA | 60 | `sp_snow_pub_TRS_TOA_EXC_STG_BAD_REC_MEMB_DATES` |  | WRK_TRS_TOA_S40_RANKED |
| m_Tgt_C_S_TRS_Pty_Rle_TOA | 70 | `sp_snow_pub_TRS_TOA_C_S_TRS_PTY_RLE_TOA` |  | WRK_TRS_TOA_S40_RANKED |
| m_Tgt_C_S_TRS_Pty_Rle_Rel_1_Mem_To_Mem | 10 | `sp_snow_step_TRS_REL1_S10_SRC` | WRK_TRS_REL1_S1_SRC |  |
| m_Tgt_C_S_TRS_Pty_Rle_Rel_1_Mem_To_Mem | 20 | `sp_snow_step_TRS_REL1_S20_KEYED` | WRK_TRS_REL1_S2_KEYED | WRK_TRS_REL1_S1_SRC |
| m_Tgt_C_S_TRS_Pty_Rle_Rel_1_Mem_To_Mem | 30 | `sp_snow_step_TRS_REL1_S30_ROUTER` | WRK_TRS_REL1_S3_ROUTER | WRK_TRS_REL1_S2_KEYED |
| m_Tgt_C_S_TRS_Pty_Rle_Rel_1_Mem_To_Mem | 40 | `sp_snow_step_TRS_REL1_S40_CONSOL` | WRK_TRS_REL1_S4_CONSOL | WRK_TRS_REL1_S2_KEYED |
| m_Tgt_C_S_TRS_Pty_Rle_Rel_1_Mem_To_Mem | 50 | `sp_snow_step_TRS_REL1_S50_PREP` | WRK_TRS_REL1_S5_PREP | WRK_TRS_REL1_S4_CONSOL |
| m_Tgt_C_S_TRS_Pty_Rle_Rel_1_Mem_To_Mem | 60 | `sp_snow_step_TRS_REL1_S60_TIMELINE` | WRK_TRS_REL1_S6_TIMELINE | WRK_TRS_REL1_S5_PREP |
| m_Tgt_C_S_TRS_Pty_Rle_Rel_1_Mem_To_Mem | 70 | `sp_snow_pub_TRS_REL1_EXC_STG_BAD_REC_MEMB_MAIN_ALT_ID` |  | WRK_TRS_REL1_S3_ROUTER |
| m_Tgt_C_S_TRS_Pty_Rle_Rel_1_Mem_To_Mem | 80 | `sp_snow_pub_TRS_REL1_EXC_STG_BAD_REC_MEMB_REF_ALT_ID` |  | WRK_TRS_REL1_S3_ROUTER |
| m_Tgt_C_S_TRS_Pty_Rle_Rel_1_Mem_To_Mem | 90 | `sp_snow_pub_TRS_REL1_EXC_STG_BAD_REC_MEMB_LOOKUP` |  | WRK_TRS_REL1_S3_ROUTER |
| m_Tgt_C_S_TRS_Pty_Rle_Rel_1_Mem_To_Mem | 100 | `sp_snow_pub_TRS_REL1_EXC_STG_BAD_REC_MEMB_DATES` |  | WRK_TRS_REL1_S3_ROUTER |
| m_Tgt_C_S_TRS_Pty_Rle_Rel_1_Mem_To_Mem | 110 | `sp_snow_pub_TRS_REL1_C_S_TRS_PTY_RLE_REL` |  | WRK_TRS_REL1_S6_TIMELINE |
| m_Tgt_C_S_TRS_Pty_Rle_Rel_DeActivation_1 | 10 | `sp_snow_step_TRS_RELDEACT_S10_MINPK` | WRK_TRS_RELDEACT_S10_MINPK |  |
| m_Tgt_C_S_TRS_Pty_Rle_Rel_DeActivation_1 | 20 | `sp_snow_step_TRS_RELDEACT_S20_SRC` | WRK_TRS_RELDEACT_S20_SRC | WRK_TRS_RELDEACT_S10_MINPK |
| m_Tgt_C_S_TRS_Pty_Rle_Rel_DeActivation_1 | 30 | `sp_snow_step_TRS_RELDEACT_S30_KEYED` | WRK_TRS_RELDEACT_S30_KEYED | WRK_TRS_RELDEACT_S20_SRC |
| m_Tgt_C_S_TRS_Pty_Rle_Rel_DeActivation_1 | 40 | `sp_snow_step_TRS_RELDEACT_S40_XREF` | WRK_TRS_RELDEACT_S40_XREF |  |
| m_Tgt_C_S_TRS_Pty_Rle_Rel_DeActivation_1 | 50 | `sp_snow_step_TRS_RELDEACT_S50_READY` | WRK_TRS_RELDEACT_S50_READY | WRK_TRS_RELDEACT_S30_KEYED|WRK_TRS_RELDEACT_S40_XREF |
| m_Tgt_C_S_TRS_Pty_Rle_Rel_DeActivation_1 | 60 | `sp_snow_pub_TRS_RELDEACT_STG_TRS_DEACTIVATED_RELATIONSHIPS` |  | WRK_TRS_RELDEACT_S50_READY |
| m_Tgt_C_S_TRS_Pty_Rle_Rel_2_Mem_To_PCP | 10 | `sp_snow_step_TRS_REL2_S10_SRC` | WRK_TRS_REL2_S1_SRC |  |
| m_Tgt_C_S_TRS_Pty_Rle_Rel_2_Mem_To_PCP | 20 | `sp_snow_step_TRS_REL2_S20_KEYED` | WRK_TRS_REL2_S2_KEYED | WRK_TRS_REL2_S1_SRC |
| m_Tgt_C_S_TRS_Pty_Rle_Rel_2_Mem_To_PCP | 30 | `sp_snow_step_TRS_REL2_S30_ROUTER` | WRK_TRS_REL2_S3_ROUTER | WRK_TRS_REL2_S2_KEYED |
| m_Tgt_C_S_TRS_Pty_Rle_Rel_2_Mem_To_PCP | 40 | `sp_snow_step_TRS_REL2_S40_CONSOL` | WRK_TRS_REL2_S4_CONSOL | WRK_TRS_REL2_S2_KEYED |
| m_Tgt_C_S_TRS_Pty_Rle_Rel_2_Mem_To_PCP | 50 | `sp_snow_step_TRS_REL2_S50_PREP` | WRK_TRS_REL2_S5_PREP | WRK_TRS_REL2_S4_CONSOL |
| m_Tgt_C_S_TRS_Pty_Rle_Rel_2_Mem_To_PCP | 60 | `sp_snow_step_TRS_REL2_S60_TIMELINE` | WRK_TRS_REL2_S6_TIMELINE | WRK_TRS_REL2_S5_PREP |
| m_Tgt_C_S_TRS_Pty_Rle_Rel_2_Mem_To_PCP | 70 | `sp_snow_pub_TRS_REL2_EXC_STG_BAD_REC_MEMB_DATES` |  | WRK_TRS_REL2_S3_ROUTER |
| m_Tgt_C_S_TRS_Pty_Rle_Rel_2_Mem_To_PCP | 80 | `sp_snow_pub_TRS_REL2_EXC_STG_BAD_REC_MEMB_DEFAULT` |  | WRK_TRS_REL2_S3_ROUTER |
| m_Tgt_C_S_TRS_Pty_Rle_Rel_2_Mem_To_PCP | 90 | `sp_snow_pub_TRS_REL2_C_S_TRS_PTY_RLE_REL_PROV` |  | WRK_TRS_REL2_S6_TIMELINE |
| m_Tgt_C_S_TRS_Pty_Rle_Phn_And_EAddr | 10 | `sp_snow_step_TRS_PHN_S10_SRC` | WRK_TRS_PHN_S1_SRC |  |
| m_Tgt_C_S_TRS_Pty_Rle_Phn_And_EAddr | 20 | `sp_snow_step_TRS_PHN_S20_SLOTS` | WRK_TRS_PHN_S2_SLOTS | WRK_TRS_PHN_S1_SRC |
| m_Tgt_C_S_TRS_Pty_Rle_Phn_And_EAddr | 30 | `sp_snow_step_TRS_PHN_S30_CHECKED` | WRK_TRS_PHN_S3_CHECKED | WRK_TRS_PHN_S2_SLOTS |
| m_Tgt_C_S_TRS_Pty_Rle_Phn_And_EAddr | 40 | `sp_snow_step_TRS_PHN_S40_PHONES` | WRK_TRS_PHN_S4_PHONES | WRK_TRS_PHN_S3_CHECKED |
| m_Tgt_C_S_TRS_Pty_Rle_Phn_And_EAddr | 50 | `sp_snow_step_TRS_PHN_S50_VERSIONS` | WRK_TRS_PHN_S5_VERSIONS | WRK_TRS_PHN_S4_PHONES |
| m_Tgt_C_S_TRS_Pty_Rle_Phn_And_EAddr | 60 | `sp_snow_step_TRS_PHN_S60_EMAILS` | WRK_TRS_PHN_S6_EMAILS | WRK_TRS_PHN_S1_SRC |
| m_Tgt_C_S_TRS_Pty_Rle_Phn_And_EAddr | 70 | `sp_snow_step_TRS_PHN_S70_EADDR` | WRK_TRS_PHN_S7_VERSIONS | WRK_TRS_PHN_S6_EMAILS |
| m_Tgt_C_S_TRS_Pty_Rle_Phn_And_EAddr | 80 | `sp_snow_pub_TRS_PHN_C_S_TRS_PTY_RLE_PHN` |  | WRK_TRS_PHN_S5_VERSIONS |
| m_Tgt_C_S_TRS_Pty_Rle_Phn_And_EAddr | 90 | `sp_snow_pub_TRS_PHN_EXC_STG_BAD_REC_MEMB_PHONE` |  | WRK_TRS_PHN_S4_PHONES |
| m_Tgt_C_S_TRS_Pty_Rle_Phn_And_EAddr | 100 | `sp_snow_pub_TRS_PHN_C_S_TRS_PTY_RLE_EADDR` |  | WRK_TRS_PHN_S7_VERSIONS |
| m_Tgt_C_S_TRS_Pty_Rle_Phn_And_EAddr | 110 | `sp_snow_pub_TRS_PHN_EXC_STG_BAD_REC_MEMB_EMAIL` |  | WRK_TRS_PHN_S6_EMAILS |
| m_Tgt_C_S_TRS_Pty_Mng_Attr_Sw | 10 | `sp_snow_step_TRS_MNGSW_S10_DAILY` | WRK_TRS_MNGSW_S10_DAILY |  |
| m_Tgt_C_S_TRS_Pty_Mng_Attr_Sw | 20 | `sp_snow_step_TRS_MNGSW_S20_SRC` | WRK_TRS_MNGSW_S20_SRC | WRK_TRS_MNGSW_S10_DAILY |
| m_Tgt_C_S_TRS_Pty_Mng_Attr_Sw | 30 | `sp_snow_step_TRS_MNGSW_S30_NORM` | WRK_TRS_MNGSW_S30_NORM | WRK_TRS_MNGSW_S20_SRC |
| m_Tgt_C_S_TRS_Pty_Mng_Attr_Sw | 40 | `sp_snow_step_TRS_MNGSW_S40_ATTRS` | WRK_TRS_MNGSW_S40_ATTRS | WRK_TRS_MNGSW_S30_NORM |
| m_Tgt_C_S_TRS_Pty_Mng_Attr_Sw | 50 | `sp_snow_pub_TRS_MNGSW_C_S_TRS_PTY_MNG_ATTR` |  | WRK_TRS_MNGSW_S40_ATTRS |
| m_Tgt_C_S_TRS_Pty_Mng_Attr_Auth_Rep_Ongoing | 10 | `sp_snow_step_TRS_AUTHREP_S10_PAYEE` | WRK_TRS_MNGAR_S10_PAYEE |  |
| m_Tgt_C_S_TRS_Pty_Mng_Attr_Auth_Rep_Ongoing | 20 | `sp_snow_step_TRS_AUTHREP_S20_SRC` | WRK_TRS_MNGAR_S20_SRC | WRK_TRS_MNGAR_S10_PAYEE |
| m_Tgt_C_S_TRS_Pty_Mng_Attr_Auth_Rep_Ongoing | 30 | `sp_snow_step_TRS_AUTHREP_S30_KEYED` | WRK_TRS_MNGAR_S30_KEYED | WRK_TRS_MNGAR_S20_SRC |
| m_Tgt_C_S_TRS_Pty_Mng_Attr_Auth_Rep_Ongoing | 40 | `sp_snow_step_TRS_AUTHREP_S40_AGG` | WRK_TRS_MNGAR_S40_AGG | WRK_TRS_MNGAR_S30_KEYED |
| m_Tgt_C_S_TRS_Pty_Mng_Attr_Auth_Rep_Ongoing | 50 | `sp_snow_pub_TRS_AUTHREP_C_S_TRS_PTY_MNG_ATTR` |  | WRK_TRS_MNGAR_S40_AGG |
| m_Tgt_C_S_TRS_Pty_Nm | 10 | `sp_snow_step_TRS_NM_S10_SRC` | WRK_TRS_NM_S10_SRC |  |
| m_Tgt_C_S_TRS_Pty_Nm | 20 | `sp_snow_step_TRS_NM_S20_NAMED` | WRK_TRS_NM_S20_NAMED | WRK_TRS_NM_S10_SRC |
| m_Tgt_C_S_TRS_Pty_Nm | 30 | `sp_snow_step_TRS_NM_S30_STD` | WRK_TRS_NM_S30_STD | WRK_TRS_NM_S20_NAMED |
| m_Tgt_C_S_TRS_Pty_Nm | 40 | `sp_snow_step_TRS_NM_S40_DEDUP` | WRK_TRS_NM_S40_DEDUP | WRK_TRS_NM_S30_STD |
| m_Tgt_C_S_TRS_Pty_Nm | 50 | `sp_snow_pub_TRS_NM_C_S_TRS_PTY_NM` |  | WRK_TRS_NM_S40_DEDUP |
| m_Tgt_C_S_TRS_Pty_Rle_Alt_Id | 10 | `sp_snow_step_TRS_ALT_S10_SRC` | WRK_TRS_ALT_S1_SRC |  |
| m_Tgt_C_S_TRS_Pty_Rle_Alt_Id | 20 | `sp_snow_step_TRS_ALT_S20_SSN` | WRK_TRS_ALT_S2_SSN | WRK_TRS_ALT_S1_SRC |
| m_Tgt_C_S_TRS_Pty_Rle_Alt_Id | 30 | `sp_snow_step_TRS_ALT_S30_NORM` | WRK_TRS_ALT_S3_NORM | WRK_TRS_ALT_S2_SSN |
| m_Tgt_C_S_TRS_Pty_Rle_Alt_Id | 40 | `sp_snow_step_TRS_ALT_S40_ROUTED` | WRK_TRS_ALT_S4_ROUTED | WRK_TRS_ALT_S3_NORM |
| m_Tgt_C_S_TRS_Pty_Rle_Alt_Id | 50 | `sp_snow_pub_TRS_ALT_C_S_TRS_PTY_RLE_ALT_ID` |  | WRK_TRS_ALT_S4_ROUTED |
| m_Tgt_C_S_TRS_Pty_Rle_Alt_Id | 60 | `sp_snow_pub_TRS_ALT_EXC_STG_BAD_REC_MEMB` |  | WRK_TRS_ALT_S4_ROUTED |
| m_Tgt_C_S_TRS_Pty_Rle_Pln | 10 | `sp_snow_step_TRS_PLN_S10_SRC` | WRK_TRS_PLN_S10_SRC |  |
| m_Tgt_C_S_TRS_Pty_Rle_Pln | 20 | `sp_snow_step_TRS_PLN_S20_PLANNED` | WRK_TRS_PLN_S20_PLANNED | WRK_TRS_PLN_S10_SRC |
| m_Tgt_C_S_TRS_Pty_Rle_Pln | 30 | `sp_snow_step_TRS_PLN_S30_RANKED` | WRK_TRS_PLN_S30_RANKED | WRK_TRS_PLN_S20_PLANNED |
| m_Tgt_C_S_TRS_Pty_Rle_Pln | 40 | `sp_snow_pub_TRS_PLN_C_S_TRS_PTY_RLE_PLN` |  | WRK_TRS_PLN_S30_RANKED |
| m_Tgt_C_S_TRS_Pty_Rle_Pln | 50 | `sp_snow_pub_TRS_PLN_EXC_STG_BAD_REC_MEMB` |  | WRK_TRS_PLN_S30_RANKED |
| m_Tgt_C_S_TRS_Addr_1 | 10 | `sp_snow_step_TRS_ADDR1_S10_SRC` | WRK_TRS_ADDR1_S10_SRC |  |
| m_Tgt_C_S_TRS_Addr_1 | 20 | `sp_snow_step_TRS_ADDR1_S20_DERIVED` | WRK_TRS_ADDR1_S20_DERIVED | WRK_TRS_ADDR1_S10_SRC |
| m_Tgt_C_S_TRS_Addr_1 | 30 | `sp_snow_step_TRS_ADDR1_S30_VALIDATED` | WRK_TRS_ADDR1_S30_VALIDATED | WRK_TRS_ADDR1_S20_DERIVED |
| m_Tgt_C_S_TRS_Addr_1 | 40 | `sp_snow_step_TRS_ADDR1_S40_READY` | WRK_TRS_ADDR1_S40_READY | WRK_TRS_ADDR1_S30_VALIDATED |
| m_Tgt_C_S_TRS_Addr_1 | 50 | `sp_snow_pub_TRS_ADDR1_STG_TRS_D_UNQ_ADDR` |  | WRK_TRS_ADDR1_S40_READY |
| m_Tgt_C_S_TRS_Addr_2 | 10 | `sp_snow_step_TRS_ADDR2_S10_DEDUP` | WRK_TRS_ADDR2_S10_DEDUP |  |
| m_Tgt_C_S_TRS_Addr_2 | 20 | `sp_snow_step_TRS_ADDR2_S20_SRC` | WRK_TRS_ADDR2_S20_SRC | WRK_TRS_ADDR2_S10_DEDUP |
| m_Tgt_C_S_TRS_Addr_2 | 30 | `sp_snow_step_TRS_ADDR2_S30_KEYED` | WRK_TRS_ADDR2_S30_KEYED | WRK_TRS_ADDR2_S20_SRC |
| m_Tgt_C_S_TRS_Addr_2 | 40 | `sp_snow_step_TRS_ADDR2_S40_SCORED` | WRK_TRS_ADDR2_S40_SCORED | WRK_TRS_ADDR2_S30_KEYED |
| m_Tgt_C_S_TRS_Addr_2 | 50 | `sp_snow_step_TRS_ADDR2_S50_READY` | WRK_TRS_ADDR2_S50_READY | WRK_TRS_ADDR2_S40_SCORED |
| m_Tgt_C_S_TRS_Addr_2 | 60 | `sp_snow_pub_TRS_ADDR2_DQM_ADDRESS` |  | WRK_TRS_ADDR2_S50_READY |
| m_Tgt_C_S_TRS_Addr_2 | 70 | `sp_snow_pub_TRS_ADDR2_C_S_TRS_PTY_RLE_ADDR` |  | WRK_TRS_ADDR2_S50_READY |
| m_Tgt_C_S_TRS_Addr_2 | 80 | `sp_snow_pub_TRS_ADDR2_EXC_STG_BAD_REC_MEMB` |  | WRK_TRS_ADDR2_S50_READY |
| m_Tgt_C_S_TRS_Stg_TOA | 10 | `sp_snow_step_TRS_STGTOA_S10_KEYED` | WRK_TRS_LUTOA_S10_KEYED |  |
| m_Tgt_C_S_TRS_Stg_TOA | 20 | `sp_snow_step_TRS_STGTOA_S20_FINAL` | WRK_TRS_LUTOA_S20_FINAL | WRK_TRS_LUTOA_S10_KEYED |
| m_Tgt_C_S_TRS_Stg_TOA | 30 | `sp_snow_pub_TRS_STGTOA_C_S_LU_TOA` |  | WRK_TRS_LUTOA_S20_FINAL |

---

# DEPENDENCIES_ECI — work-table producer / consumer chains (bare-bones)

One chain per mapping. A step produces exactly one work table; the next step consumes it. Publish branches consume the final ready table. No gating or checkpoint columns are involved.

## ADR — m_Tgt_C_S_ECI_Pty_Addr

- Step 10 `sp_snow_step_ECI_ADR_S10_SRC` produces `WRK_ECI_ADR_S10_SRC` from V_ECI_ETL_SRC_FAMILY_ADDRESS (also reads: V_ECI_ETL_SRC_FAMILY_ADDRESS).
- Step 20 `sp_snow_step_ECI_ADR_S20_KEYED` produces `WRK_ECI_ADR_S20_KEYED` from WRK_ECI_ADR_S10_SRC (also reads: STG_ECI_PTY_INACTIVE_STS).
- Step 30 `sp_snow_step_ECI_ADR_S30_VALIDATED` produces `WRK_ECI_ADR_S30_VALIDATED` from WRK_ECI_ADR_S20_KEYED.
- Step 40 `sp_snow_step_ECI_ADR_S40_FLAT` produces `WRK_ECI_ADR_S40_FLAT` from WRK_ECI_ADR_S30_VALIDATED.
- Step 50 `sp_snow_step_ECI_ADR_S50_READY` produces `WRK_ECI_ADR_S50_READY` from WRK_ECI_ADR_S40_FLAT (also reads: C_S_ECI_PTY_RLE_ADDR).
- Publish step 60 `sp_snow_pub_ECI_ADR_DQM_ADDRESS` reads `WRK_ECI_ADR_S50_READY` and writes `DQM_ADDRESS`.
- Publish step 70 `sp_snow_pub_ECI_ADR_C_S_ECI_PTY_RLE_ADDR` reads `WRK_ECI_ADR_S50_READY` and writes `C_S_ECI_PTY_RLE_ADDR`.
- Publish step 80 `sp_snow_pub_ECI_ADR_EXC_STG_BAD_REC_MEMB` reads `WRK_ECI_ADR_S50_READY` and writes `EXC_STG_BAD_REC_MEMB`.

## ALT — m_Tgt_C_S_ECI_Pty_Rle_Alt_Id

- Step 10 `sp_snow_step_ECI_ALT_S10_SRC` produces `WRK_ECI_ALT_S10_SRC` from STG_ECI_D_CHILD, STG_ECI_D_FAMILY, STG_ECI_D_MEDICAID, STG_ECI_SN_CASE (also reads: STG_ECI_D_CHILD, STG_ECI_D_FAMILY, STG_ECI_D_MEDICAID, STG_ECI_SN_CASE).
- Step 20 `sp_snow_step_ECI_ALT_S20_ACTIVE` produces `WRK_ECI_ALT_S20_ACTIVE` from WRK_ECI_ALT_S10_SRC (also reads: STG_ECI_PTY_INACTIVE_STS).
- Step 30 `sp_snow_step_ECI_ALT_S30_ROUTED` produces `WRK_ECI_ALT_S30_ROUTED` from WRK_ECI_ALT_S20_ACTIVE.
- Step 40 `sp_snow_step_ECI_ALT_S40_READY` produces `WRK_ECI_ALT_S40_READY` from WRK_ECI_ALT_S30_ROUTED (also reads: C_S_ECI_PTY_RLE_ALT_ID, EXC_STG_BAD_REC_MEMB).
- Publish step 50 `sp_snow_pub_ECI_ALT_C_S_ECI_PTY_RLE_ALT_ID` reads `WRK_ECI_ALT_S40_READY` and writes `C_S_ECI_PTY_RLE_ALT_ID`.
- Publish step 60 `sp_snow_pub_ECI_ALT_EXC_STG_BAD_REC_MEMB_SSN` reads `WRK_ECI_ALT_S40_READY` and writes `EXC_STG_BAD_REC_MEMB`.
- Publish step 70 `sp_snow_pub_ECI_ALT_EXC_STG_BAD_REC_MEMB_MEDICAID` reads `WRK_ECI_ALT_S40_READY` and writes `EXC_STG_BAD_REC_MEMB`.

## PHN — m_Tgt_C_S_ECI_Pty_Rle_Phn_And_EAddr

- Step 10 `sp_snow_step_ECI_PHN_S10_SRC` produces `WRK_ECI_PHN_S10_SRC` from V_ECI_ETL_SRC_FAMILY_PHONE (also reads: V_ECI_ETL_SRC_FAMILY_PHONE).
- Step 20 `sp_snow_step_ECI_PHN_S20_ACTIVE` produces `WRK_ECI_PHN_S20_ACTIVE` from WRK_ECI_PHN_S10_SRC (also reads: STG_ECI_PTY_INACTIVE_STS).
- Step 30 `sp_snow_step_ECI_PHN_S30_DQ` produces `WRK_ECI_PHN_S30_DQ` from WRK_ECI_PHN_S20_ACTIVE.
- Step 40 `sp_snow_step_ECI_PHN_S40_ROUTED` produces `WRK_ECI_PHN_S40_ROUTED` from WRK_ECI_PHN_S30_DQ.
- Step 50 `sp_snow_step_ECI_PHN_S50_READY` produces `WRK_ECI_PHN_S50_READY` from WRK_ECI_PHN_S40_ROUTED (also reads: C_S_ECI_PTY_RLE_EADDR, C_S_ECI_PTY_RLE_PHN).
- Publish step 60 `sp_snow_pub_ECI_PHN_C_S_ECI_PTY_RLE_PHN` reads `WRK_ECI_PHN_S50_READY` and writes `C_S_ECI_PTY_RLE_PHN`.
- Publish step 70 `sp_snow_pub_ECI_PHN_EXC_STG_BAD_REC_MEMB_PHONE` reads `WRK_ECI_PHN_S50_READY` and writes `EXC_STG_BAD_REC_MEMB`.
- Publish step 80 `sp_snow_pub_ECI_PHN_C_S_ECI_PTY_RLE_EADDR` reads `WRK_ECI_PHN_S50_READY` and writes `C_S_ECI_PTY_RLE_EADDR`.
- Publish step 90 `sp_snow_pub_ECI_PHN_EXC_STG_BAD_REC_MEMB_EMAIL` reads `WRK_ECI_PHN_S50_READY` and writes `EXC_STG_BAD_REC_MEMB`.

## PTY — m_Tgt_C_S_ECI_Pty

- Step 10 `sp_snow_step_ECI_PTY_S10_SRC` produces `WRK_ECI_PTY_S10_SRC` from STG_ECI_D_CHILD, STG_ECI_D_FAMILY (also reads: STG_ECI_D_CHILD, STG_ECI_D_FAMILY).
- Step 20 `sp_snow_step_ECI_PTY_S20_ACTIVE` produces `WRK_ECI_PTY_S20_ACTIVE` from WRK_ECI_PTY_S10_SRC (also reads: STG_ECI_PTY_INACTIVE_STS).
- Step 30 `sp_snow_step_ECI_PTY_S30_DQ` produces `WRK_ECI_PTY_S30_DQ` from WRK_ECI_PTY_S20_ACTIVE.
- Step 40 `sp_snow_step_ECI_PTY_S40_DQ2` produces `WRK_ECI_PTY_S40_DQ2` from WRK_ECI_PTY_S30_DQ.
- Step 50 `sp_snow_step_ECI_PTY_S50_READY` produces `WRK_ECI_PTY_S50_READY` from WRK_ECI_PTY_S40_DQ2 (also reads: C_S_ECI_PTY, C_S_ECI_PTY_RLE).
- Publish step 60 `sp_snow_pub_ECI_PTY_C_S_ECI_PTY` reads `WRK_ECI_PTY_S50_READY` and writes `C_S_ECI_PTY`.
- Publish step 70 `sp_snow_pub_ECI_PTY_C_S_ECI_PTY_RLE` reads `WRK_ECI_PTY_S50_READY` and writes `C_S_ECI_PTY_RLE`.
- Publish step 80 `sp_snow_pub_ECI_PTY_EXC_STG_BAD_REC_MEMB_GENDER` reads `WRK_ECI_PTY_S50_READY` and writes `EXC_STG_BAD_REC_MEMB`.
- Publish step 90 `sp_snow_pub_ECI_PTY_EXC_STG_BAD_REC_MEMB_BIRTH` reads `WRK_ECI_PTY_S50_READY` and writes `EXC_STG_BAD_REC_MEMB`.
- Publish step 100 `sp_snow_pub_ECI_PTY_EXC_STG_BAD_REC_MEMB_ETHNICITY` reads `WRK_ECI_PTY_S50_READY` and writes `EXC_STG_BAD_REC_MEMB`.
- Publish step 110 `sp_snow_pub_ECI_PTY_EXC_STG_BAD_REC_MEMB_RACE` reads `WRK_ECI_PTY_S50_READY` and writes `EXC_STG_BAD_REC_MEMB`.
- Publish step 120 `sp_snow_pub_ECI_PTY_EXC_STG_BAD_REC_MEMB_LANGUAGE` reads `WRK_ECI_PTY_S50_READY` and writes `EXC_STG_BAD_REC_MEMB`.

## REL — m_Tgt_C_S_ECI_Pty_Rle_Rel

- Step 10 `sp_snow_step_ECI_REL_S10_SRC` produces `WRK_ECI_REL_S10_SRC` from STG_ECI_D_FAMILY (also reads: STG_ECI_D_FAMILY).
- Step 20 `sp_snow_step_ECI_REL_S20_KEYED` produces `WRK_ECI_REL_S20_KEYED` from WRK_ECI_REL_S10_SRC (also reads: STG_ECI_PTY_INACTIVE_STS).
- Step 30 `sp_snow_step_ECI_REL_S30_TYPED` produces `WRK_ECI_REL_S30_TYPED` from WRK_ECI_REL_S20_KEYED (also reads: LOOKUP_CODE_VALUE, STG_ECI_SN_CHILD).
- Step 40 `sp_snow_step_ECI_REL_S40_READY` produces `WRK_ECI_REL_S40_READY` from WRK_ECI_REL_S30_TYPED (also reads: C_S_ECI_PTY_RLE_REL).
- Publish step 50 `sp_snow_pub_ECI_REL_C_S_ECI_PTY_RLE_REL` reads `WRK_ECI_REL_S40_READY` and writes `C_S_ECI_PTY_RLE_REL`.
- Publish step 60 `sp_snow_pub_ECI_REL_EXC_STG_BAD_REC_MEMB` reads `WRK_ECI_REL_S40_READY` and writes `EXC_STG_BAD_REC_MEMB`.

## RFA — m_Tgt_Stg_ECI_Pty_Reactivation_D_Family_Addr

- Step 10 `sp_snow_step_ECI_RFA_S10_LATEST` produces `WRK_ECI_RFA_S10_LATEST` from STG_ECI_H_FAMILY_ADDRESS, V_ECI_ETL_LU_REACTIVATED_ID (also reads: STG_ECI_H_FAMILY_ADDRESS, V_ECI_ETL_LU_REACTIVATED_ID).
- Step 20 `sp_snow_step_ECI_RFA_S20_KEEPNEW` produces `WRK_ECI_RFA_S20_KEEPNEW` from WRK_ECI_RFA_S10_LATEST (also reads: STG_ECI_D_FAMILY_ADDRESS).
- Publish step 30 `sp_snow_pub_ECI_RFA_STG_ECI_D_FAMILY_ADDRESS` reads `WRK_ECI_RFA_S20_KEEPNEW` and writes `STG_ECI_D_FAMILY_ADDRESS`.

## RFM — m_Tgt_Stg_ECI_Pty_Reactivation_D_Medicaid

- Step 10 `sp_snow_step_ECI_RFM_S10_LATEST` produces `WRK_ECI_RFM_S10_LATEST` from STG_ECI_D_MEDICAID, STG_ECI_H_MEDICAID, STG_ECI_SN_CASE, V_ECI_ETL_LU_REACTIVATED_ID (also reads: STG_ECI_D_MEDICAID, STG_ECI_H_MEDICAID, STG_ECI_SN_CASE, V_ECI_ETL_LU_REACTIVATED_ID).
- Step 20 `sp_snow_step_ECI_RFM_S20_KEEPNEW` produces `WRK_ECI_RFM_S20_KEEPNEW` from WRK_ECI_RFM_S10_LATEST.
- Publish step 30 `sp_snow_pub_ECI_RFM_STG_ECI_D_MEDICAID` reads `WRK_ECI_RFM_S20_KEEPNEW` and writes `STG_ECI_D_MEDICAID`.

## RFP — m_Tgt_Stg_ECI_Pty_Reactivation_D_Family_Phn

- Step 10 `sp_snow_step_ECI_RFP_S10_LATEST` produces `WRK_ECI_RFP_S10_LATEST` from STG_ECI_H_FAMILY_PHONE, V_ECI_ETL_LU_REACTIVATED_ID (also reads: STG_ECI_H_FAMILY_PHONE, V_ECI_ETL_LU_REACTIVATED_ID).
- Step 20 `sp_snow_step_ECI_RFP_S20_KEEPNEW` produces `WRK_ECI_RFP_S20_KEEPNEW` from WRK_ECI_RFP_S10_LATEST (also reads: STG_ECI_D_FAMILY_PHONE).
- Publish step 30 `sp_snow_pub_ECI_RFP_STG_ECI_D_FAMILY_PHONE` reads `WRK_ECI_RFP_S20_KEEPNEW` and writes `STG_ECI_D_FAMILY_PHONE`.

## VAL — m_Tgt_C_S_ECI_Pty_Validation

- Step 10 `sp_snow_step_ECI_VAL_S10_SRC` produces `WRK_ECI_VAL_S10_SRC` from STG_ECI_D_CHILD, STG_ECI_D_FAMILY (also reads: STG_ECI_D_CHILD, STG_ECI_D_FAMILY).
- Step 20 `sp_snow_step_ECI_VAL_S20_ENRICHED` produces `WRK_ECI_VAL_S20_ENRICHED` from WRK_ECI_VAL_S10_SRC (also reads: C_B_PTY_XREF, STG_ECI_PTY_INACTIVE_STS, V_ECI_ETL_LU_DUP_CASES, V_ECI_ETL_LU_FAMILY_VALIDATION).
- Step 30 `sp_snow_step_ECI_VAL_S30_ROUTED` produces `WRK_ECI_VAL_S30_ROUTED` from WRK_ECI_VAL_S20_ENRICHED.
- Publish step 40 `sp_snow_pub_ECI_VAL_EXC_STG_BAD_REC_MEMB` reads `WRK_ECI_VAL_S30_ROUTED` and writes `EXC_STG_BAD_REC_MEMB`.
- Publish step 50 `sp_snow_pub_ECI_VAL_STG_ECI_PTY_INACTIVE_LOG_DEACTIVATION` reads `WRK_ECI_VAL_S30_ROUTED` and writes `STG_ECI_PTY_INACTIVE_LOG`.
- Publish step 60 `sp_snow_pub_ECI_VAL_STG_ECI_PTY_INACTIVE_STS` reads `WRK_ECI_VAL_S30_ROUTED` and writes `STG_ECI_PTY_INACTIVE_STS`.
- Publish step 70 `sp_snow_pub_ECI_VAL_STG_ECI_PTY_INACTIVE_LOG_REACTIVATION` reads `WRK_ECI_VAL_S30_ROUTED` and writes `STG_ECI_PTY_INACTIVE_LOG`.

## Cross-mapping (workflow order)

- VAL runs first: its publish branches write `STG_ECI_PTY_INACTIVE_STS` and `STG_ECI_PTY_INACTIVE_LOG`. Later mappings filter on the status table: step 20 of PTY, ADR, ALT, PHN and REL reads `STG_ECI_PTY_INACTIVE_STS`.
- Reactivation mappings RFA, RFP and RFM run before ALT, PHN, ADR and REL: they write the delta tables `STG_ECI_D_FAMILY_ADDRESS`, `STG_ECI_D_FAMILY_PHONE` and `STG_ECI_D_MEDICAID`, which the later mappings re-send to MDM.
- Runner order: VAL, PTY, RFA, RFP, RFM, ALT, PHN, ADR, REL.

---

# WIC Dependencies — wf_WIC_Stage_Load (bare-bones variant)
No work table is shared between mappings; each mapping's step 5 drops only its own tables.
Every step consumes exactly the previous step's work table (step 10 consumes no work table; it reads base tables); every publish branch consumes the final step's work table.

## Per-unit dependencies

| Mapping | STEP_NO | Proc | Produced (work table) | Consumed (work table) | Target | Kind |
|---|---|---|---|---|---|---|
| `m_Tgt_C_S_WIC_Pty_Validation` | 10 | `sp_snow_step_WIC_VAL_S10_ENRICHED` | `WRK_WIC_VAL_S10_ENRICHED` | `` | `` | TRANSFORM |
| `m_Tgt_C_S_WIC_Pty_Validation` | 20 | `sp_snow_step_WIC_VAL_S20_NAMED` | `WRK_WIC_VAL_S20_NAMED` | `WRK_WIC_VAL_S10_ENRICHED` | `` | TRANSFORM |
| `m_Tgt_C_S_WIC_Pty_Validation` | 30 | `sp_snow_step_WIC_VAL_S30_ROUTED` | `WRK_WIC_VAL_S30_ROUTED` | `WRK_WIC_VAL_S20_NAMED` | `` | TRANSFORM |
| `m_Tgt_C_S_WIC_Pty_Validation` | 40 | `sp_snow_pub_WIC_VAL_EXC_STG_BAD_REC_MEMB` | `` | `WRK_WIC_VAL_S30_ROUTED` | `EXC_STG_BAD_REC_MEMB` | EXCEPTION |
| `m_Tgt_C_S_WIC_Pty_Validation` | 50 | `sp_snow_pub_WIC_VAL_STG_WIC_PTY_INACTIVE_LOG_DEACTIVATION` | `` | `WRK_WIC_VAL_S30_ROUTED` | `STG_WIC_PTY_INACTIVE_LOG` | STATUS |
| `m_Tgt_C_S_WIC_Pty_Validation` | 60 | `sp_snow_pub_WIC_VAL_STG_WIC_PTY_INACTIVE_STS` | `` | `WRK_WIC_VAL_S30_ROUTED` | `STG_WIC_PTY_INACTIVE_STS` | STATUS |
| `m_Tgt_C_S_WIC_Pty_Validation` | 70 | `sp_snow_pub_WIC_VAL_STG_WIC_PTY_INACTIVE_LOG_REACTIVATION` | `` | `WRK_WIC_VAL_S30_ROUTED` | `STG_WIC_PTY_INACTIVE_LOG` | STATUS |
| `m_Tgt_C_S_WIC_Pty` | 10 | `sp_snow_step_WIC_PTY_S10_ACTIVE` | `WRK_WIC_PTY_S10_ACTIVE` | `` | `` | TRANSFORM |
| `m_Tgt_C_S_WIC_Pty` | 20 | `sp_snow_step_WIC_PTY_S20_DQ` | `WRK_WIC_PTY_S20_DQ` | `WRK_WIC_PTY_S10_ACTIVE` | `` | TRANSFORM |
| `m_Tgt_C_S_WIC_Pty` | 30 | `sp_snow_step_WIC_PTY_S30_DQ2` | `WRK_WIC_PTY_S30_DQ2` | `WRK_WIC_PTY_S20_DQ` | `` | TRANSFORM |
| `m_Tgt_C_S_WIC_Pty` | 40 | `sp_snow_step_WIC_PTY_S40_ROUTED` | `WRK_WIC_PTY_S40_ROUTED` | `WRK_WIC_PTY_S30_DQ2` | `` | TRANSFORM |
| `m_Tgt_C_S_WIC_Pty` | 50 | `sp_snow_pub_WIC_PTY_C_S_WIC_PTY` | `` | `WRK_WIC_PTY_S40_ROUTED` | `C_S_WIC_PTY` | SPINE |
| `m_Tgt_C_S_WIC_Pty` | 60 | `sp_snow_pub_WIC_PTY_C_S_WIC_PTY_RLE` | `` | `WRK_WIC_PTY_S40_ROUTED` | `C_S_WIC_PTY_RLE` | SPINE |
| `m_Tgt_C_S_WIC_Pty` | 70 | `sp_snow_pub_WIC_PTY_EXC_STG_BAD_REC_MEMB_GENDER` | `` | `WRK_WIC_PTY_S40_ROUTED` | `EXC_STG_BAD_REC_MEMB` | EXCEPTION |
| `m_Tgt_C_S_WIC_Pty` | 80 | `sp_snow_pub_WIC_PTY_EXC_STG_BAD_REC_MEMB_BIRTH` | `` | `WRK_WIC_PTY_S40_ROUTED` | `EXC_STG_BAD_REC_MEMB` | EXCEPTION |
| `m_Tgt_C_S_WIC_Pty` | 90 | `sp_snow_pub_WIC_PTY_EXC_STG_BAD_REC_MEMB_ETHNICITY` | `` | `WRK_WIC_PTY_S40_ROUTED` | `EXC_STG_BAD_REC_MEMB` | EXCEPTION |
| `m_Tgt_C_S_WIC_Pty` | 100 | `sp_snow_pub_WIC_PTY_EXC_STG_BAD_REC_MEMB_RACE` | `` | `WRK_WIC_PTY_S40_ROUTED` | `EXC_STG_BAD_REC_MEMB` | EXCEPTION |
| `m_Tgt_C_S_WIC_Pty` | 110 | `sp_snow_pub_WIC_PTY_EXC_STG_BAD_REC_MEMB_LANGUAGE` | `` | `WRK_WIC_PTY_S40_ROUTED` | `EXC_STG_BAD_REC_MEMB` | EXCEPTION |
| `m_Tgt_C_S_WIC_Pty_Addr` | 10 | `sp_snow_step_WIC_ADR_S10_ACTIVE` | `WRK_WIC_ADDR_S10_ACTIVE` | `` | `` | TRANSFORM |
| `m_Tgt_C_S_WIC_Pty_Addr` | 20 | `sp_snow_step_WIC_ADR_S20_VALIDATED` | `WRK_WIC_ADDR_S20_VALIDATED` | `WRK_WIC_ADDR_S10_ACTIVE` | `` | TRANSFORM |
| `m_Tgt_C_S_WIC_Pty_Addr` | 30 | `sp_snow_step_WIC_ADR_S30_FLAT` | `WRK_WIC_ADDR_S30_FLAT` | `WRK_WIC_ADDR_S20_VALIDATED` | `` | TRANSFORM |
| `m_Tgt_C_S_WIC_Pty_Addr` | 40 | `sp_snow_step_WIC_ADR_S40_SCORED` | `WRK_WIC_ADDR_S40_SCORED` | `WRK_WIC_ADDR_S30_FLAT` | `` | TRANSFORM |
| `m_Tgt_C_S_WIC_Pty_Addr` | 50 | `sp_snow_pub_WIC_ADR_DQM_ADDRESS` | `` | `WRK_WIC_ADDR_S40_SCORED` | `DQM_ADDRESS` | VALIDATION |
| `m_Tgt_C_S_WIC_Pty_Addr` | 60 | `sp_snow_pub_WIC_ADR_C_S_WIC_PTY_RLE_ADDR` | `` | `WRK_WIC_ADDR_S40_SCORED` | `C_S_WIC_PTY_RLE_ADDR` | SPINE |
| `m_Tgt_C_S_WIC_Pty_Addr` | 70 | `sp_snow_pub_WIC_ADR_EXC_STG_BAD_REC_MEMB` | `` | `WRK_WIC_ADDR_S40_SCORED` | `EXC_STG_BAD_REC_MEMB` | EXCEPTION |
| `m_Tgt_C_S_WIC_Pty_Rle_Phn_And_EAddr` | 10 | `sp_snow_step_WIC_PHN_S10_SRC` | `WRK_WIC_PHN_S10_SRC` | `` | `` | TRANSFORM |
| `m_Tgt_C_S_WIC_Pty_Rle_Phn_And_EAddr` | 20 | `sp_snow_step_WIC_PHN_S20_CHECKED` | `WRK_WIC_PHN_S20_CHECKED` | `WRK_WIC_PHN_S10_SRC` | `` | TRANSFORM |
| `m_Tgt_C_S_WIC_Pty_Rle_Phn_And_EAddr` | 30 | `sp_snow_step_WIC_PHN_S30_ROUTED` | `WRK_WIC_PHN_S30_ROUTED` | `WRK_WIC_PHN_S20_CHECKED` | `` | TRANSFORM |
| `m_Tgt_C_S_WIC_Pty_Rle_Phn_And_EAddr` | 40 | `sp_snow_step_WIC_PHN_S40_READY` | `WRK_WIC_PHN_S40_READY` | `WRK_WIC_PHN_S30_ROUTED` | `` | TRANSFORM |
| `m_Tgt_C_S_WIC_Pty_Rle_Phn_And_EAddr` | 50 | `sp_snow_pub_WIC_PHN_C_S_WIC_PTY_RLE_PHN` | `` | `WRK_WIC_PHN_S40_READY` | `C_S_WIC_PTY_RLE_PHN` | SPINE |
| `m_Tgt_C_S_WIC_Pty_Rle_Phn_And_EAddr` | 60 | `sp_snow_pub_WIC_PHN_EXC_STG_BAD_REC_MEMB_PHONE` | `` | `WRK_WIC_PHN_S40_READY` | `EXC_STG_BAD_REC_MEMB` | EXCEPTION |
| `m_Tgt_C_S_WIC_Pty_Rle_Phn_And_EAddr` | 70 | `sp_snow_pub_WIC_PHN_C_S_WIC_PTY_RLE_EADDR` | `` | `WRK_WIC_PHN_S40_READY` | `C_S_WIC_PTY_RLE_EADDR` | SPINE |
| `m_Tgt_C_S_WIC_Pty_Rle_Phn_And_EAddr` | 80 | `sp_snow_pub_WIC_PHN_EXC_STG_BAD_REC_MEMB_EMAIL` | `` | `WRK_WIC_PHN_S40_READY` | `EXC_STG_BAD_REC_MEMB` | EXCEPTION |
| `m_Tgt_C_S_WIC_Pty_Rle_Alt_Id` | 10 | `sp_snow_step_WIC_ALT_S10_KEYS` | `WRK_WIC_ALT_S10_KEYS` | `` | `` | TRANSFORM |
| `m_Tgt_C_S_WIC_Pty_Rle_Alt_Id` | 20 | `sp_snow_step_WIC_ALT_S20_READY` | `WRK_WIC_ALT_S20_READY` | `WRK_WIC_ALT_S10_KEYS` | `` | TRANSFORM |
| `m_Tgt_C_S_WIC_Pty_Rle_Alt_Id` | 30 | `sp_snow_pub_WIC_ALT_C_S_WIC_PTY_RLE_ALT_ID` | `` | `WRK_WIC_ALT_S20_READY` | `C_S_WIC_PTY_RLE_ALT_ID` | SPINE |

## Dependency chains in words

- **m_Tgt_C_S_WIC_Pty_Validation**: step 10 (`WRK_WIC_VAL_S10_ENRICHED`) -> step 20 (`WRK_WIC_VAL_S20_NAMED`) -> step 30 (`WRK_WIC_VAL_S30_ROUTED`) -> publish branches step 40 (`EXC_STG_BAD_REC_MEMB`), step 50 (`STG_WIC_PTY_INACTIVE_LOG`), step 60 (`STG_WIC_PTY_INACTIVE_STS`), step 70 (`STG_WIC_PTY_INACTIVE_LOG`). Every step consumes exactly the previous step's work table (step 10 consumes no work table; it reads base tables); every publish branch consumes the final step's work table.
- **m_Tgt_C_S_WIC_Pty**: step 10 (`WRK_WIC_PTY_S10_ACTIVE`) -> step 20 (`WRK_WIC_PTY_S20_DQ`) -> step 30 (`WRK_WIC_PTY_S30_DQ2`) -> step 40 (`WRK_WIC_PTY_S40_ROUTED`) -> publish branches step 50 (`C_S_WIC_PTY`), step 60 (`C_S_WIC_PTY_RLE`), step 70 (`EXC_STG_BAD_REC_MEMB`), step 80 (`EXC_STG_BAD_REC_MEMB`), step 90 (`EXC_STG_BAD_REC_MEMB`), step 100 (`EXC_STG_BAD_REC_MEMB`), step 110 (`EXC_STG_BAD_REC_MEMB`). Every step consumes exactly the previous step's work table (step 10 consumes no work table; it reads base tables); every publish branch consumes the final step's work table.
- **m_Tgt_C_S_WIC_Pty_Addr**: step 10 (`WRK_WIC_ADDR_S10_ACTIVE`) -> step 20 (`WRK_WIC_ADDR_S20_VALIDATED`) -> step 30 (`WRK_WIC_ADDR_S30_FLAT`) -> step 40 (`WRK_WIC_ADDR_S40_SCORED`) -> publish branches step 50 (`DQM_ADDRESS`), step 60 (`C_S_WIC_PTY_RLE_ADDR`), step 70 (`EXC_STG_BAD_REC_MEMB`). Every step consumes exactly the previous step's work table (step 10 consumes no work table; it reads base tables); every publish branch consumes the final step's work table.
- **m_Tgt_C_S_WIC_Pty_Rle_Phn_And_EAddr**: step 10 (`WRK_WIC_PHN_S10_SRC`) -> step 20 (`WRK_WIC_PHN_S20_CHECKED`) -> step 30 (`WRK_WIC_PHN_S30_ROUTED`) -> step 40 (`WRK_WIC_PHN_S40_READY`) -> publish branches step 50 (`C_S_WIC_PTY_RLE_PHN`), step 60 (`EXC_STG_BAD_REC_MEMB`), step 70 (`C_S_WIC_PTY_RLE_EADDR`), step 80 (`EXC_STG_BAD_REC_MEMB`). Every step consumes exactly the previous step's work table (step 10 consumes no work table; it reads base tables); every publish branch consumes the final step's work table.
- **m_Tgt_C_S_WIC_Pty_Rle_Alt_Id**: step 10 (`WRK_WIC_ALT_S10_KEYS`) -> step 20 (`WRK_WIC_ALT_S20_READY`) -> publish branches step 30 (`C_S_WIC_PTY_RLE_ALT_ID`). Every step consumes exactly the previous step's work table (step 10 consumes no work table; it reads base tables); every publish branch consumes the final step's work table.

## Cross-mapping dependencies (target tables, not work tables)

- `m_Tgt_C_S_WIC_Pty_Validation` runs FIRST in the workflow runner because it maintains `STG_WIC_PTY_INACTIVE_STS`, which every later WIC mapping filters on with a `NOT EXISTS (DEACTIVATION_STS IS NOT NULL)` test. This is a target-table dependency through the shared schema, not a work-table dependency: no driver reads another mapping's work tables.
- `m_Tgt_C_S_WIC_Pty` loads `C_S_WIC_PTY` / `C_S_WIC_PTY_RLE`; the Address, Phone/E-mail and Alt Id mappings' final steps guard against those targets (insert-only guards), so they must run after Party in the same run order as the original runner.
- The workflow runner order is therefore: Validation -> Party -> Address -> Phone/E-mail -> Alt Id. Changing that order changes results.

---

# TTF Work-Table Dependencies (bare-bones variant)

Work-table producer / consumer chains per mapping. No config columns.
Cross-mapping order is the workflow runner order: Validation, Pty,
Alt_Id, Phn. Within a mapping, each step consumes the previous step's
work table (or base source tables for step 10); every publish branch
consumes the mapping's final routed work table.

## m_Tgt_C_S_TTF_Pty_Validation

- Step 10 `sp_snow_step_TTF_VAL_S10_ENRICHED` produces `WRK_TTF_VAL_S1_ENRICHED`, consumes `(base source tables)`.
- Step 20 `sp_snow_step_TTF_VAL_S20_NAMED` produces `WRK_TTF_VAL_S2_NAMED`, consumes `WRK_TTF_VAL_S1_ENRICHED`.
- Step 30 `sp_snow_step_TTF_VAL_S30_ROUTED` produces `WRK_TTF_VAL_S3_ROUTED`, consumes `WRK_TTF_VAL_S2_NAMED`.
- Branch step 40 `sp_snow_pub_TTF_VAL_EXC_STG_BAD_REC_MEMB` publishes to `EXC_STG_BAD_REC_MEMB`, consumes `WRK_TTF_VAL_S3_ROUTED`.
- Branch step 50 `sp_snow_pub_TTF_VAL_STG_TTF_PTY_INACTIVE_LOG_DEACTIVATION` publishes to `STG_TTF_PTY_INACTIVE_LOG`, consumes `WRK_TTF_VAL_S3_ROUTED`.
- Branch step 60 `sp_snow_pub_TTF_VAL_STG_TTF_PTY_INACTIVE_STS` publishes to `STG_TTF_PTY_INACTIVE_STS`, consumes `WRK_TTF_VAL_S3_ROUTED`.
- Branch step 70 `sp_snow_pub_TTF_VAL_STG_TTF_PTY_INACTIVE_LOG_REACTIVATION` publishes to `STG_TTF_PTY_INACTIVE_LOG`, consumes `WRK_TTF_VAL_S3_ROUTED`.

## m_Tgt_C_S_TTF_Pty

- Step 10 `sp_snow_step_TTF_PTY_S10_ACTIVE` produces `WRK_TTF_PTY_S1_ACTIVE`, consumes `(base source tables)`.
- Step 20 `sp_snow_step_TTF_PTY_S20_DQ` produces `WRK_TTF_PTY_S2_DQ`, consumes `WRK_TTF_PTY_S1_ACTIVE`.
- Step 30 `sp_snow_step_TTF_PTY_S30_DQ2` produces `WRK_TTF_PTY_S3_DQ2`, consumes `WRK_TTF_PTY_S2_DQ`.
- Step 40 `sp_snow_step_TTF_PTY_S40_ROUTED` produces `WRK_TTF_PTY_S4_ROUTED`, consumes `WRK_TTF_PTY_S3_DQ2`.
- Branch step 50 `sp_snow_pub_TTF_PTY_C_S_TTF_PTY` publishes to `C_S_TTF_PTY`, consumes `WRK_TTF_PTY_S4_ROUTED`.
- Branch step 60 `sp_snow_pub_TTF_PTY_C_S_TTF_PTY_RLE` publishes to `C_S_TTF_PTY_RLE`, consumes `WRK_TTF_PTY_S4_ROUTED`.
- Branch step 70 `sp_snow_pub_TTF_PTY_EXC_STG_BAD_REC_MEMB_GENDER` publishes to `EXC_STG_BAD_REC_MEMB`, consumes `WRK_TTF_PTY_S4_ROUTED`.
- Branch step 80 `sp_snow_pub_TTF_PTY_EXC_STG_BAD_REC_MEMB_BIRTH` publishes to `EXC_STG_BAD_REC_MEMB`, consumes `WRK_TTF_PTY_S4_ROUTED`.
- Branch step 90 `sp_snow_pub_TTF_PTY_EXC_STG_BAD_REC_MEMB_ETHNICITY` publishes to `EXC_STG_BAD_REC_MEMB`, consumes `WRK_TTF_PTY_S4_ROUTED`.
- Branch step 100 `sp_snow_pub_TTF_PTY_EXC_STG_BAD_REC_MEMB_RACE` publishes to `EXC_STG_BAD_REC_MEMB`, consumes `WRK_TTF_PTY_S4_ROUTED`.

## m_Tgt_C_S_TTF_Pty_Rle_Alt_Id

- Step 10 `sp_snow_step_TTF_ALT_S10_KEYS` produces `WRK_TTF_ALT_S1_KEYS`, consumes `(base source tables)`.
- Step 20 `sp_snow_step_TTF_ALT_S20_DEDUP` produces `WRK_TTF_ALT_S2_DEDUP`, consumes `WRK_TTF_ALT_S1_KEYS`.
- Branch step 30 `sp_snow_pub_TTF_ALT_C_S_TTF_PTY_RLE_ALT_ID` publishes to `C_S_TTF_PTY_RLE_ALT_ID`, consumes `WRK_TTF_ALT_S2_DEDUP`.

## m_Tgt_C_S_TTF_Pty_Rle_Phn

- Step 10 `sp_snow_step_TTF_PHN_S10_SRC` produces `WRK_TTF_PHN_S1_SRC`, consumes `(base source tables)`.
- Step 20 `sp_snow_step_TTF_PHN_S20_CHECKED` produces `WRK_TTF_PHN_S2_CHECKED`, consumes `WRK_TTF_PHN_S1_SRC`.
- Step 30 `sp_snow_step_TTF_PHN_S30_ROUTED` produces `WRK_TTF_PHN_S3_ROUTED`, consumes `WRK_TTF_PHN_S2_CHECKED`.
- Branch step 40 `sp_snow_pub_TTF_PHN_C_S_TTF_PTY_RLE_PHN` publishes to `C_S_TTF_PTY_RLE_PHN`, consumes `WRK_TTF_PHN_S3_ROUTED`.
- Branch step 50 `sp_snow_pub_TTF_PHN_EXC_STG_BAD_REC_MEMB` publishes to `EXC_STG_BAD_REC_MEMB`, consumes `WRK_TTF_PHN_S3_ROUTED`.

## Cross-mapping dependencies (verified in the v2.1 step SQL)

- `m_Tgt_C_S_TTF_Pty_Validation` step 10 reads `STG_TTF_PTY_INACTIVE_STS`
  and its publish branches write `STG_TTF_PTY_INACTIVE_STS` and
  `STG_TTF_PTY_INACTIVE_LOG`; it runs first in the workflow.
- `m_Tgt_C_S_TTF_Pty` step 10 filters out parties present in
  `STG_TTF_PTY_INACTIVE_STS` (NOT EXISTS); it runs second.
- `m_Tgt_C_S_TTF_Pty_Rle_Alt_Id` step 10 likewise filters out parties
  present in `STG_TTF_PTY_INACTIVE_STS`; it runs third.
- `m_Tgt_C_S_TTF_Pty_Rle_Phn` runs fourth, after the party tables exist.

---

# FSS dependencies -- bare-bones step driver (wf_FSS_Stage_Load)

No config table, no gating: dependencies are the driver call order plus the work-table producer/consumer chains below. Every unit runs unconditionally, in order. Within a mapping, every step consumes exactly the previous step's work table; every publish branch consumes the last step's work table. Step 5 cleanup drops ALL of the mapping's work tables, so a missing upstream table now fails when the consuming CTAS runs, instead of via an existence check.

Cross-mapping dependencies (target tables, not work tables -- the workflow runner order enforces them):

- `m_Tgt_C_S_FSS_Pty_Validation` first: it maintains `STG_FSS_PTY_INACTIVE_STS`, which every later mapping reads via a NOT EXISTS (DEACTIVATION_STS IS NOT NULL) filter.

- `m_Tgt_C_S_FSS_Pty` second: it loads `C_S_FSS_PTY` / `C_S_FSS_PTY_RLE`, which later mappings' keys build on.

- Addresses, alternate IDs, phones / e-mails, relationships after that, in the original run-script order.

### m_Tgt_C_S_FSS_Pty_Validation (PREFIX FSS_VAL)

| Unit | STEP_NO | Produced | Consumed |
|---|---|---|---|
| driver `sp_snow_main_m_Tgt_C_S_FSS_Pty_Validation` | 5 (cleanup) |  |  |
| step `sp_snow_step_FSS_VAL_S10_SRC` | 10 | WRK_FSS_VAL_S1_SRC |  |
| step `sp_snow_step_FSS_VAL_S20_ENRICHED` | 20 | WRK_FSS_VAL_S2_ENRICHED | WRK_FSS_VAL_S1_SRC |
| step `sp_snow_step_FSS_VAL_S30_ROUTED` | 30 | WRK_FSS_VAL_S3_ROUTED | WRK_FSS_VAL_S2_ENRICHED |
| branch `sp_snow_pub_FSS_VAL_EXC_STG_BAD_REC_MEMB` | 50 |  | WRK_FSS_VAL_S3_ROUTED |
| branch `sp_snow_pub_FSS_VAL_STG_FSS_PTY_INACTIVE_LOG` | 60 |  | WRK_FSS_VAL_S3_ROUTED |
| branch `sp_snow_pub_FSS_VAL_STG_FSS_PTY_INACTIVE_STS_NEW` | 70 |  | WRK_FSS_VAL_S3_ROUTED |
| branch `sp_snow_pub_FSS_VAL_STG_FSS_PTY_INACTIVE_STS_REACTIVATION` | 80 |  | WRK_FSS_VAL_S3_ROUTED |
Chain in words: step 5 cleanup (drops `WRK_FSS_VAL_S1_SRC`, `WRK_FSS_VAL_S2_ENRICHED`, `WRK_FSS_VAL_S3_ROUTED`) -> step 10 (SRC) -> step 20 (ENRICHED) -> step 30 (ROUTED) -> publish 50 (`EXC_STG_BAD_REC_MEMB`) -> publish 60 (`STG_FSS_PTY_INACTIVE_LOG`) -> publish 70 (`STG_FSS_PTY_INACTIVE_STS`) -> publish 80 (`STG_FSS_PTY_INACTIVE_STS`). Each unit depends only on the unit that produced the work table it consumes; publish branches all depend on the last transform step (30), not on each other, and run together in one transaction.

### m_Tgt_C_S_FSS_Pty (PREFIX FSS_PTY)

| Unit | STEP_NO | Produced | Consumed |
|---|---|---|---|
| driver `sp_snow_main_m_Tgt_C_S_FSS_Pty` | 5 (cleanup) |  |  |
| step `sp_snow_step_FSS_PTY_S10_SRC` | 10 | WRK_FSS_PTY_S1_SRC |  |
| step `sp_snow_step_FSS_PTY_S20_DQ` | 20 | WRK_FSS_PTY_S2_DQ | WRK_FSS_PTY_S1_SRC |
| step `sp_snow_step_FSS_PTY_S30_DQ2` | 30 | WRK_FSS_PTY_S3_DQ2 | WRK_FSS_PTY_S2_DQ |
| step `sp_snow_step_FSS_PTY_S40_ROUTED` | 40 | WRK_FSS_PTY_S4_ROUTED | WRK_FSS_PTY_S3_DQ2 |
| branch `sp_snow_pub_FSS_PTY_C_S_FSS_PTY` | 50 |  | WRK_FSS_PTY_S4_ROUTED |
| branch `sp_snow_pub_FSS_PTY_C_S_FSS_PTY_RLE` | 60 |  | WRK_FSS_PTY_S4_ROUTED |
| branch `sp_snow_pub_FSS_PTY_EXC_STG_BAD_REC_MEMB_GENDER` | 70 |  | WRK_FSS_PTY_S4_ROUTED |
| branch `sp_snow_pub_FSS_PTY_EXC_STG_BAD_REC_MEMB_BIRTH` | 80 |  | WRK_FSS_PTY_S4_ROUTED |
| branch `sp_snow_pub_FSS_PTY_EXC_STG_BAD_REC_MEMB_ETHNICITY` | 90 |  | WRK_FSS_PTY_S4_ROUTED |
| branch `sp_snow_pub_FSS_PTY_EXC_STG_BAD_REC_MEMB_RACE` | 100 |  | WRK_FSS_PTY_S4_ROUTED |
| branch `sp_snow_pub_FSS_PTY_EXC_STG_BAD_REC_MEMB_LANGUAGE` | 110 |  | WRK_FSS_PTY_S4_ROUTED |
| branch `sp_snow_pub_FSS_PTY_EXC_STG_BAD_REC_MEMB_SUFFIX` | 120 |  | WRK_FSS_PTY_S4_ROUTED |
Chain in words: step 5 cleanup (drops `WRK_FSS_PTY_S1_SRC`, `WRK_FSS_PTY_S2_DQ`, `WRK_FSS_PTY_S3_DQ2`, `WRK_FSS_PTY_S4_ROUTED`) -> step 10 (SRC_ACTIVE) -> step 20 (DQ_CHECKS) -> step 30 (DQ2_EXCEPTIONS) -> step 40 (ROUTED) -> publish 50 (`C_S_FSS_PTY`) -> publish 60 (`C_S_FSS_PTY_RLE`) -> publish 70 (`EXC_STG_BAD_REC_MEMB`) -> publish 80 (`EXC_STG_BAD_REC_MEMB`) -> publish 90 (`EXC_STG_BAD_REC_MEMB`) -> publish 100 (`EXC_STG_BAD_REC_MEMB`) -> publish 110 (`EXC_STG_BAD_REC_MEMB`) -> publish 120 (`EXC_STG_BAD_REC_MEMB`). Each unit depends only on the unit that produced the work table it consumes; publish branches all depend on the last transform step (40), not on each other, and run together in one transaction.

### m_Tgt_C_S_FSS_Pty_Addr (PREFIX FSS_ADR)

| Unit | STEP_NO | Produced | Consumed |
|---|---|---|---|
| driver `sp_snow_main_m_Tgt_C_S_FSS_Pty_Addr` | 5 (cleanup) |  |  |
| step `sp_snow_step_FSS_ADR_S10_SRC` | 10 | WRK_FSS_ADDR_S1_SRC |  |
| step `sp_snow_step_FSS_ADR_S20_VALIDATED` | 20 | WRK_FSS_ADDR_S2_VALIDATED | WRK_FSS_ADDR_S1_SRC |
| step `sp_snow_step_FSS_ADR_S30_FLAT` | 30 | WRK_FSS_ADDR_S3_FLAT | WRK_FSS_ADDR_S2_VALIDATED |
| step `sp_snow_step_FSS_ADR_S40_SCORED` | 40 | WRK_FSS_ADDR_S4_SCORED | WRK_FSS_ADDR_S3_FLAT |
| branch `sp_snow_pub_FSS_ADR_DQM_ADDRESS` | 50 |  | WRK_FSS_ADDR_S4_SCORED |
| branch `sp_snow_pub_FSS_ADR_C_S_FSS_PTY_RLE_ADDR` | 60 |  | WRK_FSS_ADDR_S4_SCORED |
| branch `sp_snow_pub_FSS_ADR_EXC_STG_BAD_REC_MEMB` | 70 |  | WRK_FSS_ADDR_S4_SCORED |
Chain in words: step 5 cleanup (drops `WRK_FSS_ADDR_S1_SRC`, `WRK_FSS_ADDR_S2_VALIDATED`, `WRK_FSS_ADDR_S3_FLAT`, `WRK_FSS_ADDR_S4_SCORED`) -> step 10 (SRC_ACTIVE) -> step 20 (VALIDATED) -> step 30 (FLAT) -> step 40 (SCORED) -> publish 50 (`DQM_ADDRESS`) -> publish 60 (`C_S_FSS_PTY_RLE_ADDR`) -> publish 70 (`EXC_STG_BAD_REC_MEMB`). Each unit depends only on the unit that produced the work table it consumes; publish branches all depend on the last transform step (40), not on each other, and run together in one transaction.

### m_Tgt_C_S_FSS_Pty_Rle_Alt_Id (PREFIX FSS_ALT)

| Unit | STEP_NO | Produced | Consumed |
|---|---|---|---|
| driver `sp_snow_main_m_Tgt_C_S_FSS_Pty_Rle_Alt_Id` | 5 (cleanup) |  |  |
| step `sp_snow_step_FSS_ALT_S10_SRC` | 10 | WRK_FSS_ALT_S1_SRC |  |
| step `sp_snow_step_FSS_ALT_S20_FILTERED` | 20 | WRK_FSS_ALT_S2_FILTERED | WRK_FSS_ALT_S1_SRC |
| branch `sp_snow_pub_FSS_ALT_C_S_FSS_PTY_RLE_ALT_ID` | 50 |  | WRK_FSS_ALT_S2_FILTERED |
Chain in words: step 5 cleanup (drops `WRK_FSS_ALT_S1_SRC`, `WRK_FSS_ALT_S2_FILTERED`) -> step 10 (SRC_KEYED) -> step 20 (FILTERED) -> publish 50 (`C_S_FSS_PTY_RLE_ALT_ID`). Each unit depends only on the unit that produced the work table it consumes; publish branches all depend on the last transform step (20), not on each other, and run together in one transaction.

### m_Tgt_C_S_FSS_Pty_Rle_Phn_And_EAddr (PREFIX FSS_PHN)

| Unit | STEP_NO | Produced | Consumed |
|---|---|---|---|
| driver `sp_snow_main_m_Tgt_C_S_FSS_Pty_Rle_Phn_And_EAddr` | 5 (cleanup) |  |  |
| step `sp_snow_step_FSS_PHN_S10_SRC` | 10 | WRK_FSS_PHN_S1_SRC |  |
| step `sp_snow_step_FSS_PHN_S20_DQ` | 20 | WRK_FSS_PHN_S2_DQ | WRK_FSS_PHN_S1_SRC |
| step `sp_snow_step_FSS_PHN_S30_CHECKED` | 30 | WRK_FSS_PHN_S3_CHECKED | WRK_FSS_PHN_S2_DQ |
| step `sp_snow_step_FSS_PHN_S40_ROUTED` | 40 | WRK_FSS_PHN_S4_ROUTED | WRK_FSS_PHN_S3_CHECKED |
| branch `sp_snow_pub_FSS_PHN_C_S_FSS_PTY_RLE_EADDR` | 50 |  | WRK_FSS_PHN_S4_ROUTED |
| branch `sp_snow_pub_FSS_PHN_EXC_STG_BAD_REC_MEMB_EMAIL` | 60 |  | WRK_FSS_PHN_S4_ROUTED |
| branch `sp_snow_pub_FSS_PHN_C_S_FSS_PTY_RLE_PHN` | 70 |  | WRK_FSS_PHN_S4_ROUTED |
| branch `sp_snow_pub_FSS_PHN_EXC_STG_BAD_REC_MEMB_PHONE` | 80 |  | WRK_FSS_PHN_S4_ROUTED |
| branch `sp_snow_pub_FSS_PHN_EXC_STG_BAD_REC_MEMB_EXTENSION` | 90 |  | WRK_FSS_PHN_S4_ROUTED |
Chain in words: step 5 cleanup (drops `WRK_FSS_PHN_S1_SRC`, `WRK_FSS_PHN_S2_DQ`, `WRK_FSS_PHN_S3_CHECKED`, `WRK_FSS_PHN_S4_ROUTED`) -> step 10 (SRC_ACTIVE) -> step 20 (DQ_VALIDATE) -> step 30 (CHECKED) -> step 40 (ROUTED) -> publish 50 (`C_S_FSS_PTY_RLE_EADDR`) -> publish 60 (`EXC_STG_BAD_REC_MEMB`) -> publish 70 (`C_S_FSS_PTY_RLE_PHN`) -> publish 80 (`EXC_STG_BAD_REC_MEMB`) -> publish 90 (`EXC_STG_BAD_REC_MEMB`). Each unit depends only on the unit that produced the work table it consumes; publish branches all depend on the last transform step (40), not on each other, and run together in one transaction.

### m_Tgt_C_S_FSS_Pty_Rle_Rel (PREFIX FSS_REL)

| Unit | STEP_NO | Produced | Consumed |
|---|---|---|---|
| driver `sp_snow_main_m_Tgt_C_S_FSS_Pty_Rle_Rel` | 5 (cleanup) |  |  |
| step `sp_snow_step_FSS_REL_S10_SRC` | 10 | WRK_FSS_REL_S1_SRC |  |
| step `sp_snow_step_FSS_REL_S20_CODED` | 20 | WRK_FSS_REL_S2_CODED | WRK_FSS_REL_S1_SRC |
| step `sp_snow_step_FSS_REL_S30_TYPED` | 30 | WRK_FSS_REL_S3_TYPED | WRK_FSS_REL_S2_CODED |
| step `sp_snow_step_FSS_REL_S40_FINAL` | 40 | WRK_FSS_REL_S4_FINAL | WRK_FSS_REL_S3_TYPED |
| branch `sp_snow_pub_FSS_REL_C_S_FSS_PTY_RLE_REL` | 50 |  | WRK_FSS_REL_S4_FINAL |
| branch `sp_snow_pub_FSS_REL_EXC_STG_BAD_REC_MEMB` | 60 |  | WRK_FSS_REL_S4_FINAL |
Chain in words: step 5 cleanup (drops `WRK_FSS_REL_S1_SRC`, `WRK_FSS_REL_S2_CODED`, `WRK_FSS_REL_S3_TYPED`, `WRK_FSS_REL_S4_FINAL`) -> step 10 (SRC_ACTIVE) -> step 20 (CODED) -> step 30 (TYPED) -> step 40 (FINAL) -> publish 50 (`C_S_FSS_PTY_RLE_REL`) -> publish 60 (`EXC_STG_BAD_REC_MEMB`). Each unit depends only on the unit that produced the work table it consumes; publish branches all depend on the last transform step (40), not on each other, and run together in one transaction.

---

# DEPENDENCIES_CRE — m_Tgt_C_S_CRE_CARE_Clients, bare-bones step-driver variant (CRE ONLY)

Workflow: `wf_CRE_Stage_Load_Ongoing`. Mapping: `m_Tgt_C_S_CRE_CARE_Clients`.
Fragment for coordinator assembly (bare-bones variant: no config table, no
job-control table, no flag gating). Dependencies below are work-table
producer/consumer chains only. Base source tables and final target tables
are NOT work-table dependencies and are not listed as consumed (they are
named in each unit's own header).

## Units

| Step | Unit (procedure) | Kind | Produced | Consumed |
|---|---|---|---|---|
| 10 | `sp_snow_step_CRE_CARE_S10_SRC_MRG` | TRANSFORM | `WRK_CRE_CARE_S1_SRC_MRG` | _(none — base source tables)_ |
| 20 | `sp_snow_step_CRE_CARE_S20_NAMED` | TRANSFORM | `WRK_CRE_CARE_S2_NAMED` | `WRK_CRE_CARE_S1_SRC_MRG` |
| 30 | `sp_snow_step_CRE_CARE_S30_RANKED` | TRANSFORM | `WRK_CRE_CARE_S3_RANKED` | `WRK_CRE_CARE_S2_NAMED` |
| 40 | `sp_snow_step_CRE_CARE_S40_FLAT` | TRANSFORM | `WRK_CRE_CARE_S4_FLAT` | `WRK_CRE_CARE_S3_RANKED` |
| 50 | `sp_snow_step_CRE_CARE_S50_KEYED` | TRANSFORM | `WRK_CRE_CARE_S5_KEYED` | `WRK_CRE_CARE_S4_FLAT` |
| 60 | `sp_snow_pub_CRE_CARE_CRE_SRC_MRG` | STATUS | | `WRK_CRE_CARE_S5_KEYED` |
| 70 | `sp_snow_pub_CRE_CARE_EXC_STG_BAD_REC_MEMB_FIRST_NAME` | EXCEPTION | | `WRK_CRE_CARE_S5_KEYED` |
| 80 | `sp_snow_pub_CRE_CARE_EXC_STG_BAD_REC_MEMB_LAST_NAME` | EXCEPTION | | `WRK_CRE_CARE_S5_KEYED` |
| 90 | `sp_snow_pub_CRE_CARE_C_S_CRE_PTY` | SPINE | | `WRK_CRE_CARE_S5_KEYED` |
| 100 | `sp_snow_pub_CRE_CARE_C_S_CRE_PTY_RLE` | SPINE | | `WRK_CRE_CARE_S5_KEYED` |
| 110 | `sp_snow_pub_CRE_CARE_EXC_STG_BAD_REC_MEMB_GENDER` | EXCEPTION | | `WRK_CRE_CARE_S5_KEYED` |
| 120 | `sp_snow_pub_CRE_CARE_EXC_STG_BAD_REC_MEMB_SUFFIX` | EXCEPTION | | `WRK_CRE_CARE_S5_KEYED` |
| 130 | `sp_snow_pub_CRE_CARE_EXC_STG_BAD_REC_MEMB_ETHNICITY` | EXCEPTION | | `WRK_CRE_CARE_S5_KEYED` |
| 140 | `sp_snow_pub_CRE_CARE_EXC_STG_BAD_REC_MEMB_RACE` | EXCEPTION | | `WRK_CRE_CARE_S5_KEYED` |
| 150 | `sp_snow_pub_CRE_CARE_C_S_CRE_PTY_RLE_ADDR` | SPINE | | `WRK_CRE_CARE_S5_KEYED` |
| 160 | `sp_snow_pub_CRE_CARE_EXC_STG_BAD_REC_MEMB_ADDR` | EXCEPTION | | `WRK_CRE_CARE_S5_KEYED` |
| 170 | `sp_snow_pub_CRE_CARE_C_S_CRE_PTY_RLE_PHN` | SPINE | | `WRK_CRE_CARE_S5_KEYED` |
| 180 | `sp_snow_pub_CRE_CARE_EXC_STG_BAD_REC_MEMB_PHONE` | EXCEPTION | | `WRK_CRE_CARE_S5_KEYED` |
| 190 | `sp_snow_pub_CRE_CARE_C_S_CRE_PTY_RLE_ALT_ID_CARE` | SPINE | | `WRK_CRE_CARE_S5_KEYED` |
| 200 | `sp_snow_pub_CRE_CARE_C_S_CRE_PTY_RLE_ALT_ID_MEDICAID` | SPINE | | `WRK_CRE_CARE_S5_KEYED` |
| 210 | `sp_snow_pub_CRE_CARE_EXC_STG_BAD_REC_MEMB_MEDICAID_ALT` | EXCEPTION | | `WRK_CRE_CARE_S5_KEYED` |
| 220 | `sp_snow_pub_CRE_CARE_C_S_CRE_PTY_RLE_ALT_ID_SSN` | SPINE | | `WRK_CRE_CARE_S5_KEYED` |
| 230 | `sp_snow_pub_CRE_CARE_EXC_STG_BAD_REC_MEMB_SSN_ALT` | EXCEPTION | | `WRK_CRE_CARE_S5_KEYED` |

## Dependency chains, in words

- **Transform chain (strictly linear):** step 10 produces the snapshot + merge-routing
  table; step 20 consumes it and produces the standardised table; step 30 consumes
  that and produces the ranked + enriched table; step 40 consumes that and produces
  the flattened table; step 50 consumes that and produces the keyed table. Each
  transform step depends on exactly the previous step, and on nothing else in
  work-table terms (reference lookups and helper functions are not work tables).
- **Publish fan-out:** all eighteen publish branches depend on step 50 only — each
  reads `WRK_CRE_CARE_S5_KEYED` and nothing else. No branch depends on another
  branch; branch order matters only for the original INSERT ALL order and for
  summary order, not for data (each branch reads the same keyed table
  with its own original WHEN guard, exactly as the original INSERT ALL branches
  each read the same final select).
- **Step 5 cleanup:** step 5 (dropping all five work tables) runs before step 10
  on every run; there is no step-level resume.
- **Full chain, end to end:** step 5 cleanup → 10 → 20 → 30 → 40 → 50
  → (60, 70, 80, 90, 100, 110, 120, 130, 140, 150, 160, 170, 180, 190, 200, 210,
  220, 230 in one transaction) → driver RETURNs the summary string.
- **Cross-mapping:** none. This workflow has a single mapping; no other mapping
  consumes any `WRK_CRE_*` table produced here.

