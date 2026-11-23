# CRE publish_dest S10-only map

S10-only twins: ONLY the first (source) step is inlined as a CTE;
later steps and the WHERE gate are dropped. Each target column is
aliased from a first-step column, a literal, or a parameter. A
column the first step does not carry is NULL (recorded below).

Built: 7 twins. Dropped (not C_S_* targets): 11. Failed: 0.

## Twins

### sp_snow_pub_CRE_CARE_C_S_CRE_PTY.sql -> C_S_CRE_PTY

- Kept steps: `s1_src_mrg`. P_RUN_TS: YES.
- WHERE gate dropped: `WHERE is_member AND uq_pty`.
- Columns set to NULL (no first-step source): PERIOD_END_DATE (via s5_keyed), PERIOD_REFERENCE_TIME (via s5_keyed), SFX_NM (via s5_keyed), ETHNCTY (column MSTR_CODE_VALUE not produced by lkp_cv), RACE_CD (column MSTR_CODE_VALUE not produced by lkp_cv).
- Column map:
  - `PKEY_SRC_OBJECT` <- `CARE_ID` (via s5_keyed; was `pty_key`)
  - `PERIOD_START_DATE` <- `CARE_LASTUP_DT` (via s5_keyed; was `period_start`)
  - `PERIOD_END_DATE` <- `NULL` (via s5_keyed; was `pty_period_end`)
  - `VERSION_SEQ` <- `'1'` (via s5_keyed; VERSION_SEQ computed downstream; literal 1; was `version_seq_num`)
  - `PERIOD_REFERENCE_TIME` <- `NULL` (via s5_keyed; was `pty_period_reference_time`)
  - `TIMELINE_ACTION` <- `IFF((REC_TYPE IN ('B', 'D')), 2, NULL)` (via s5_keyed; was `timeline_action`)
  - `LAST_UPDATE_DATE` <- `:P_RUN_TS` (via s5_keyed; run timestamp; :P_RUN_TS; was `last_update`)
  - `CREATE_DATE` <- `:P_RUN_TS` (via s5_keyed; run timestamp; :P_RUN_TS; was `last_update`)
  - `SRC_ROWID` <- `CARE_ID` (via s5_keyed; was `pty_key`)
  - `BIRTH_DT` <- `BIRTH_DT` (via s5_keyed; was `BIRTH_DT`)
  - `FULL_NM` <- `TRIM(NVL(((INITCAP(FIRSTNM, ' '))), '')
                            || (' ' || TRIM(((INITCAP(('~`!@#$%^&*()_-+=}{[]|\"'':;?/>.<,' || CHR(9)), ' ')))))
                            || ' '
                            || NVL(LTRIM(((INITCAP(LASTNM, ' ')))), ''))::VARCHAR` (via s5_keyed; was `std_full_name`)
  - `GNDR_CD` <- `CASE WHEN 'Indv' IN ('I', 'Indv', 'INDV', 'HCP') AND LEFT(SEX, 1) IN ('B', 'U') THEN NULL
                 WHEN 'Indv' IN ('I', 'Indv', 'INDV', 'HCP') AND LEFT(SEX, 1) = 'M' THEN '1'
                 WHEN 'Indv' IN ('I', 'Indv', 'INDV', 'HCP') AND LEFT(SEX, 1) = 'F' THEN '2'
                 ELSE NULL END::VARCHAR` (via s5_keyed; was `mdm_gender_code`)
  - `SFX_NM` <- `NULL` (via s5_keyed; was `std_sfx_name`)
  - `LST_NM` <- `((INITCAP(LASTNM, ' ')))::VARCHAR` (via s5_keyed; was `std_lst_name`)
  - `FRST_NM` <- `((INITCAP(FIRSTNM, ' ')))::VARCHAR` (via s5_keyed; was `std_first_name`)
  - `PTY_BO_CLASS_CD` <- `'Indv'` (via s5_keyed; was `pty_bo_class_cd`)
  - `SRC_FULL_NM` <- `NVL(NULL, NVL(TRIM(FIRSTNM), '') || ' ' || NVL(TRIM(LASTNM), ''))::VARCHAR` (via s5_keyed; was `std_src_full_name`)
  - `SRC_LAST_UPD_DT` <- `NVL(CARE_LASTUP_DT, INSERT_DATE)` (via s5_keyed; was `src_last_update`)
  - `ETHNCTY` <- `NULL` (column MSTR_CODE_VALUE not produced by lkp_cv; was `ethnicity_mstr`)
  - `RACE_CD` <- `NULL` (column MSTR_CODE_VALUE not produced by lkp_cv; was `race_mstr`)
  - `SRC_ETHNCTY` <- `FEDETH` (via s5_keyed; was `FEDETH`)
  - `SRC_RACE_CD` <- `RACE` (via s5_keyed; was `RACE`)

### sp_snow_pub_CRE_CARE_C_S_CRE_PTY_RLE.sql -> C_S_CRE_PTY_RLE

- Kept steps: `s1_src_mrg`. P_RUN_TS: YES.
- WHERE gate dropped: `WHERE is_member AND uq_rle`.
- Columns set to NULL (no first-step source): PERIOD_END_DATE (via s5_keyed), PERIOD_REFERENCE_TIME (via s5_keyed), TIMELINE_ACTION (via s5_keyed).
- Column map:
  - `PTY_FK` <- `CARE_ID` (via s5_keyed; was `pty_key`)
  - `PKEY_SRC_OBJECT` <- `NVL(CARE_ID, '') || '|' || 'Member'` (via s5_keyed; was `rle_key`)
  - `SRC_ROWID` <- `NVL(CARE_ID, '') || '|' || 'Member'` (via s5_keyed; was `rle_key`)
  - `PERIOD_START_DATE` <- `CARE_LASTUP_DT` (via s5_keyed; was `period_start`)
  - `PERIOD_END_DATE` <- `NULL` (via s5_keyed; was `pty_period_end`)
  - `VERSION_SEQ` <- `'1'` (via s5_keyed; VERSION_SEQ computed downstream; literal 1; was `version_seq_num`)
  - `LAST_UPDATE_DATE` <- `:P_RUN_TS` (via s5_keyed; was `run_ts`)
  - `RLE_BO_CLASS_CD` <- `'Member'` (via s5_keyed; was `rle_bo_class_cd`)
  - `CREATE_DATE` <- `:P_RUN_TS` (via s5_keyed; was `run_ts`)
  - `SRC_LAST_UPD_DT` <- `NVL(CARE_LASTUP_DT, INSERT_DATE)` (via s5_keyed; was `src_last_update`)
  - `PERIOD_REFERENCE_TIME` <- `NULL` (via s5_keyed; was `null_timestamp`)
  - `TIMELINE_ACTION` <- `NULL` (via s5_keyed; was `null_number`)

### sp_snow_pub_CRE_CARE_C_S_CRE_PTY_RLE_ADDR.sql -> C_S_CRE_PTY_RLE_ADDR

- Kept steps: `s1_src_mrg`. P_RUN_TS: YES.
- WHERE gate dropped: `WHERE grp_addr AND uq_addr`.
- Columns set to NULL (no first-step source): PERIOD_REFERENCE_TIME (via s5_keyed), ADDR_LN_2 (via s5_keyed), STATE (via s5_keyed), CNTRY_CD (via s5_keyed), LATTD (via s5_keyed), LNGTD (via s5_keyed), MLBLTY_SCR (via s5_keyed), FLR_NUM (via s5_keyed), ADDR_TP_CD (via s5_keyed), SUB_BLDG_DESC (via s5_keyed), SUB_BLDG_NM (via s5_keyed), BLDG_NMBR (via s5_keyed), BLDNG_NM (via s5_keyed), RSDNTL_DLVRY_IND (via s5_keyed), GEOCD_STS_CD (via s5_keyed), ORG_NM (via s5_keyed), ORG_DESC (via s5_keyed), VLDTN_MSG (via s5_keyed).
- Column map:
  - `PKEY_SRC_OBJECT` <- `(NVL(CARE_ID, '') || '|' || 'Member') || '|' || '002'` (via s5_keyed; was `addr_key`)
  - `SRC_ROWID` <- `LEFT(((NVL(CARE_ID, '') || '|' || 'Member') || '|' || '002'), 30)` (via s5_keyed; was `addr_src_rowid`)
  - `VERSION_SEQ` <- `'1'` (via s5_keyed; VERSION_SEQ computed downstream; literal 1; was `version_seq_num`)
  - `LAST_UPDATE_DATE` <- `:P_RUN_TS` (via s5_keyed; run timestamp; :P_RUN_TS; was `last_update`)
  - `PERIOD_START_DATE` <- `CARE_LASTUP_DT` (via s5_keyed; was `period_start`)
  - `PERIOD_END_DATE` <- `IFF((REC_TYPE IN ('B', 'D')), CARE_LASTUP_DT, NULL)` (via s5_keyed; was `period_end`)
  - `PERIOD_REFERENCE_TIME` <- `NULL` (via s5_keyed; was `period_reference_time`)
  - `TIMELINE_ACTION` <- `IFF((REC_TYPE IN ('B', 'D')), 2, NULL)` (via s5_keyed; was `timeline_action`)
  - `CREATE_DATE` <- `:P_RUN_TS` (via s5_keyed; run timestamp; :P_RUN_TS; was `last_update`)
  - `HIERARCHY_CODE` <- `'Payer'` (via s5_keyed; was `hierarchy_code`)
  - `PREF_LVL` <- `'Primary'` (via s5_keyed; was `pref_lvl`)
  - `ADDR_TP` <- `'002'` (via s5_keyed; was `addr_tp`)
  - `HM_REL_TP_CD` <- `'Member Addr'` (via s5_keyed; was `hm_rel_tp_cd`)
  - `ADDR_LN_1` <- `INITCAP(STREET)` (via s5_keyed; was `a_line1`)
  - `ADDR_LN_2` <- `NULL` (via s5_keyed; was `a_line2`)
  - `CITY` <- `INITCAP(CITY)` (via s5_keyed; was `a_city`)
  - `COUNTY` <- `CNTY` (via s5_keyed; was `a_county`)
  - `STATE` <- `NULL` (via s5_keyed; was `a_state`)
  - `CNTRY_CD` <- `NULL` (via s5_keyed; was `a_country`)
  - `PSTL_CD` <- `ZIP` (via s5_keyed; was `a_postcode`)
  - `PSTL_CD_EXT` <- `ZIPSUF` (via s5_keyed; was `a_postcode_ext`)
  - `LATTD` <- `NULL` (via s5_keyed; was `a_latitude`)
  - `LNGTD` <- `NULL` (via s5_keyed; was `a_longitude`)
  - `MLBLTY_SCR` <- `NULL` (via s5_keyed; was `a_mailability_score`)
  - `PTY_RLE_FK` <- `NVL(CARE_ID, '') || '|' || 'Member'` (via s5_keyed; was `rle_key`)
  - `USG_TP` <- `'002'` (via s5_keyed; was `addr_tp`)
  - `SRC_ADDR_LN_1` <- `STREET` (via s5_keyed; was `STREET`)
  - `SRC_CITY` <- `CITY` (via s5_keyed; was `CITY`)
  - `SRC_COUNTY` <- `CNTY` (via s5_keyed; was `CNTY`)
  - `SRC_STATE` <- `STATE` (via s5_keyed; was `STATE`)
  - `SRC_CNTRY` <- `'US'` (via s5_keyed; was `src_cntry`)
  - `SRC_PSTL_CD` <- `ZIP` (via s5_keyed; was `ZIP`)
  - `SRC_PSTL_CD_EXT` <- `ZIPSUF` (via s5_keyed; was `ZIPSUF`)
  - `SRC_LAST_UPD_DT` <- `CARE_LASTUP_DT` (via s5_keyed; was `CARE_LASTUP_DT`)
  - `FLR_NUM` <- `NULL` (via s5_keyed; was `a_sub_building_number`)
  - `ADDR_TP_CD` <- `NULL` (via s5_keyed; was `a_address_type`)
  - `SUB_BLDG_DESC` <- `NULL` (via s5_keyed; was `a_sub_building_descriptor`)
  - `SUB_BLDG_NM` <- `NULL` (via s5_keyed; was `a_sub_building_complete`)
  - `BLDG_NMBR` <- `NULL` (via s5_keyed; was `a_building_number`)
  - `BLDNG_NM` <- `NULL` (via s5_keyed; was `a_building_name`)
  - `RSDNTL_DLVRY_IND` <- `NULL` (via s5_keyed; was `a_residential`)
  - `GEOCD_STS_CD` <- `NULL` (via s5_keyed; was `a_geocoding_status`)
  - `ORG_NM` <- `NULL` (via s5_keyed; was `a_org_name`)
  - `ORG_DESC` <- `NULL` (via s5_keyed; was `a_org_descriptor`)
  - `VLDTN_MSG` <- `NULL` (via s5_keyed; was `a_match_code`)

### sp_snow_pub_CRE_CARE_C_S_CRE_PTY_RLE_ALT_ID_CARE.sql -> C_S_CRE_PTY_RLE_ALT_ID

- Kept steps: `s1_src_mrg`. P_RUN_TS: YES.
- WHERE gate dropped: `WHERE grp_care_alt AND uq_care_alt`.
- Columns set to NULL (no first-step source): PKEY_SRC_OBJECT (via s5_keyed), ALT_ID_TP (via s5_keyed), ALT_ID_TP_FLTR (via s5_keyed), SRC_ROWID (via s5_keyed), PERIOD_REFERENCE_TIME (via s5_keyed), TIMELINE_ACTION (via s5_keyed).
- Column map:
  - `PKEY_SRC_OBJECT` <- `NULL` (via s5_keyed; was `care_alt_key`)
  - `PERIOD_START_DATE` <- `CARE_LASTUP_DT` (via s5_keyed; was `period_start`)
  - `PERIOD_END_DATE` <- `IFF((REC_TYPE IN ('B', 'D')), CARE_LASTUP_DT, NULL)` (via s5_keyed; was `period_end`)
  - `VERSION_SEQ` <- `'1'` (via s5_keyed; VERSION_SEQ computed downstream; literal 1; was `version_seq_num`)
  - `PTY_RLE_FK` <- `NVL(CARE_ID, '') || '|' || 'Member'` (via s5_keyed; was `rle_key`)
  - `ALT_ID_TP` <- `NULL` (via s5_keyed; was `care_tp_cd`)
  - `ALT_ID_VAL` <- `IFF((LEFT((IFF((IFF(GRP_DELETES, NULL, IFF(NO_MERGE_HISTORY, 'N', 'Y'))) = 'N', TARGET_ID, CARE_ID)), 10)::VARCHAR) IN ('U', 'N'), NULL, (LEFT((IFF((IFF(GRP_DELETES, NULL, IFF(NO_MERGE_HISTORY, 'N', 'Y'))) = 'N', TARGET_ID, CARE_ID)), 10)::VARCHAR))` (via s5_keyed; was `care_alt_val`)
  - `ALT_ID_TP_FLTR` <- `NULL` (via s5_keyed; was `care_tp_cd`)
  - `STS_CD` <- `'Issued'` (via s5_keyed; was `sts_cd`)
  - `SRC_ROWID` <- `NULL` (via s5_keyed; was `care_alt_src_rowid`)
  - `SRC_LAST_UPD_DT` <- `CARE_LASTUP_DT` (via s5_keyed; was `CARE_LASTUP_DT`)
  - `LAST_UPDATE_DATE` <- `:P_RUN_TS` (via s5_keyed; run timestamp; :P_RUN_TS; was `last_update`)
  - `PERIOD_REFERENCE_TIME` <- `NULL` (via s5_keyed; was `null_timestamp`)
  - `TIMELINE_ACTION` <- `NULL` (via s5_keyed; was `null_number`)

### sp_snow_pub_CRE_CARE_C_S_CRE_PTY_RLE_ALT_ID_MEDICAID.sql -> C_S_CRE_PTY_RLE_ALT_ID

- Kept steps: `s1_src_mrg`. P_RUN_TS: YES.
- WHERE gate dropped: `WHERE grp_medicaid_alt AND uq_medicaid_alt`.
- Columns set to NULL (no first-step source): PKEY_SRC_OBJECT (via s5_keyed), ALT_ID_TP (via s5_keyed), ALT_ID_TP_FLTR (via s5_keyed), SRC_ROWID (via s5_keyed), PERIOD_REFERENCE_TIME (via s5_keyed), TIMELINE_ACTION (via s5_keyed).
- Column map:
  - `PKEY_SRC_OBJECT` <- `NULL` (via s5_keyed; was `medicaid_alt_key`)
  - `PERIOD_START_DATE` <- `CARE_LASTUP_DT` (via s5_keyed; was `period_start`)
  - `PERIOD_END_DATE` <- `IFF((REC_TYPE IN ('B', 'D')), CARE_LASTUP_DT, NULL)` (via s5_keyed; was `period_end`)
  - `VERSION_SEQ` <- `'1'` (via s5_keyed; VERSION_SEQ computed downstream; literal 1; was `version_seq_num`)
  - `PTY_RLE_FK` <- `NVL(CARE_ID, '') || '|' || 'Member'` (via s5_keyed; was `rle_key`)
  - `ALT_ID_TP` <- `NULL` (via s5_keyed; was `medicaid_tp_cd`)
  - `ALT_ID_VAL` <- `IFF((LEFT(RECIP_NO, 10)::VARCHAR) IN ('U', 'N'), NULL, (LEFT(RECIP_NO, 10)::VARCHAR))` (via s5_keyed; was `medicaid_alt_val`)
  - `ALT_ID_TP_FLTR` <- `NULL` (via s5_keyed; was `medicaid_tp_cd`)
  - `STS_CD` <- `'Issued'` (via s5_keyed; was `sts_cd`)
  - `SRC_ROWID` <- `NULL` (via s5_keyed; was `medicaid_alt_src_rowid`)
  - `SRC_LAST_UPD_DT` <- `CARE_LASTUP_DT` (via s5_keyed; was `CARE_LASTUP_DT`)
  - `LAST_UPDATE_DATE` <- `:P_RUN_TS` (via s5_keyed; run timestamp; :P_RUN_TS; was `last_update`)
  - `PERIOD_REFERENCE_TIME` <- `NULL` (via s5_keyed; was `null_timestamp`)
  - `TIMELINE_ACTION` <- `NULL` (via s5_keyed; was `null_number`)

### sp_snow_pub_CRE_CARE_C_S_CRE_PTY_RLE_ALT_ID_SSN.sql -> C_S_CRE_PTY_RLE_ALT_ID

- Kept steps: `s1_src_mrg`. P_RUN_TS: YES.
- WHERE gate dropped: `WHERE grp_ssn_alt AND uq_ssn_alt`.
- Columns set to NULL (no first-step source): PKEY_SRC_OBJECT (via s5_keyed), ALT_ID_TP (via s5_keyed), ALT_ID_TP_FLTR (via s5_keyed), SRC_ROWID (via s5_keyed), PERIOD_REFERENCE_TIME (via s5_keyed), TIMELINE_ACTION (via s5_keyed).
- Column map:
  - `PKEY_SRC_OBJECT` <- `NULL` (via s5_keyed; was `ssn_alt_key`)
  - `PERIOD_START_DATE` <- `CARE_LASTUP_DT` (via s5_keyed; was `period_start`)
  - `PERIOD_END_DATE` <- `IFF((REC_TYPE IN ('B', 'D')), CARE_LASTUP_DT, NULL)` (via s5_keyed; was `period_end`)
  - `VERSION_SEQ` <- `'1'` (via s5_keyed; VERSION_SEQ computed downstream; literal 1; was `version_seq_num`)
  - `PTY_RLE_FK` <- `NVL(CARE_ID, '') || '|' || 'Member'` (via s5_keyed; was `rle_key`)
  - `ALT_ID_TP` <- `NULL` (via s5_keyed; was `ssn_tp_cd`)
  - `ALT_ID_VAL` <- `IFF(SSN = 'U' OR SSN = 'N', NULL, SSN)` (via s5_keyed; was `ssn_out`)
  - `ALT_ID_TP_FLTR` <- `NULL` (via s5_keyed; was `ssn_tp_cd`)
  - `STS_CD` <- `'Issued'` (via s5_keyed; was `sts_cd`)
  - `SRC_ROWID` <- `NULL` (via s5_keyed; was `ssn_alt_src_rowid`)
  - `SRC_LAST_UPD_DT` <- `CARE_LASTUP_DT` (via s5_keyed; was `CARE_LASTUP_DT`)
  - `LAST_UPDATE_DATE` <- `:P_RUN_TS` (via s5_keyed; run timestamp; :P_RUN_TS; was `last_update`)
  - `PERIOD_REFERENCE_TIME` <- `NULL` (via s5_keyed; was `null_timestamp`)
  - `TIMELINE_ACTION` <- `NULL` (via s5_keyed; was `null_number`)

### sp_snow_pub_CRE_CARE_C_S_CRE_PTY_RLE_PHN.sql -> C_S_CRE_PTY_RLE_PHN

- Kept steps: `s1_src_mrg`. P_RUN_TS: YES.
- WHERE gate dropped: `WHERE grp_phone AND uq_phone`.
- Columns set to NULL (no first-step source): PERIOD_REFERENCE_TIME (via s5_keyed).
- Column map:
  - `PKEY_SRC_OBJECT` <- `NVL(CARE_ID, '') || '|Member|Telephone|001|' || NVL(PHONE, '')` (via s5_keyed; was `phn_key`)
  - `SRC_ROWID` <- `LEFT((NVL(CARE_ID, '') || '|Member|Telephone|001|' || NVL(PHONE, '')), 30)` (via s5_keyed; was `phn_src_rowid`)
  - `PHN_NUM` <- `PHONE` (via s5_keyed; was `phone_std`)
  - `VERSION_SEQ` <- `'1'` (via s5_keyed; VERSION_SEQ computed downstream; literal 1; was `version_seq_num`)
  - `LAST_UPDATE_DATE` <- `:P_RUN_TS` (via s5_keyed; run timestamp; :P_RUN_TS; was `last_update`)
  - `PHN_TP` <- `'Telephone'` (via s5_keyed; was `phn_tp`)
  - `PTY_RLE_FK` <- `NVL(CARE_ID, '') || '|Member'` (via s5_keyed; was `member_rle_fk`)
  - `USG_TP` <- `'001'` (via s5_keyed; was `usg_tp_phone`)
  - `PREF_LVL` <- `'Primary'` (via s5_keyed; was `pref_lvl`)
  - `PERIOD_START_DATE` <- `CARE_LASTUP_DT` (via s5_keyed; was `period_start`)
  - `PERIOD_END_DATE` <- `IFF((REC_TYPE IN ('B', 'D')), CARE_LASTUP_DT, NULL)` (via s5_keyed; was `period_end`)
  - `TIMELINE_ACTION` <- `IFF((REC_TYPE IN ('B', 'D')), 2, NULL)` (via s5_keyed; was `timeline_action`)
  - `PERIOD_REFERENCE_TIME` <- `NULL` (via s5_keyed; was `period_reference_time`)
  - `CREATE_DATE` <- `:P_RUN_TS` (via s5_keyed; run timestamp; :P_RUN_TS; was `last_update`)
  - `SRC_LAST_UPD_DT` <- `CARE_LASTUP_DT` (via s5_keyed; was `CARE_LASTUP_DT`)

## Dropped (not C_S_* targets)

- sp_snow_pub_CRE_CARE_CRE_SRC_MRG.sql -> CRE_SRC_MRG
- sp_snow_pub_CRE_CARE_EXC_STG_BAD_REC_MEMB_ADDR.sql -> EXC_STG_BAD_REC_MEMB
- sp_snow_pub_CRE_CARE_EXC_STG_BAD_REC_MEMB_ETHNICITY.sql -> EXC_STG_BAD_REC_MEMB
- sp_snow_pub_CRE_CARE_EXC_STG_BAD_REC_MEMB_FIRST_NAME.sql -> EXC_STG_BAD_REC_MEMB
- sp_snow_pub_CRE_CARE_EXC_STG_BAD_REC_MEMB_GENDER.sql -> EXC_STG_BAD_REC_MEMB
- sp_snow_pub_CRE_CARE_EXC_STG_BAD_REC_MEMB_LAST_NAME.sql -> EXC_STG_BAD_REC_MEMB
- sp_snow_pub_CRE_CARE_EXC_STG_BAD_REC_MEMB_MEDICAID_ALT.sql -> EXC_STG_BAD_REC_MEMB
- sp_snow_pub_CRE_CARE_EXC_STG_BAD_REC_MEMB_PHONE.sql -> EXC_STG_BAD_REC_MEMB
- sp_snow_pub_CRE_CARE_EXC_STG_BAD_REC_MEMB_RACE.sql -> EXC_STG_BAD_REC_MEMB
- sp_snow_pub_CRE_CARE_EXC_STG_BAD_REC_MEMB_SSN_ALT.sql -> EXC_STG_BAD_REC_MEMB
- sp_snow_pub_CRE_CARE_EXC_STG_BAD_REC_MEMB_SUFFIX.sql -> EXC_STG_BAD_REC_MEMB

