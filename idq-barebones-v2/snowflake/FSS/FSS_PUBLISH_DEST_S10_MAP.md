# FSS publish_dest S10-only map

S10-only twins: ONLY the first (source) step is inlined as a CTE;
later steps and the WHERE gate are dropped. Each target column is
aliased from a first-step column, a literal, or a parameter. A
column the first step does not carry is NULL (recorded below).

Built: 7 twins. Dropped (not C_S_* targets): 16. Failed: 0.

## Twins

### sp_snow_pub_FSS_ADR_C_S_FSS_PTY_RLE_ADDR.sql -> C_S_FSS_PTY_RLE_ADDR

- Kept steps: `s1_src`. P_RUN_TS: YES.
- WHERE gate dropped: `WHERE score = '100' AND uq_addr`.
- Columns set to NULL (no first-step source): ROWID_OBJECT (kept verbatim), DELETED_IND (kept verbatim), DELETED_DATE (kept verbatim), DELETED_BY (kept verbatim), PERIOD_REFERENCE_TIME (kept verbatim), CREATOR (kept verbatim), USG_TP (kept verbatim), FLR_NUM (kept verbatim), COUNTY (via s4_scored), LCTN_CRDNT_DESC (kept verbatim), PSTL_BRCD (kept verbatim), RGN_CD (kept verbatim), SRC_PSTL_CD_EXT (kept verbatim), EFF_END_DT (kept verbatim).
- Column map:
  - `PKEY_SRC_OBJECT` <- `PKEY_SRC_OBJECT` (via s4_scored; was `pkey_src_object`)
  - `ROWID_OBJECT` <- `NULL` (kept verbatim; was `NULL`)
  - `DELETED_IND` <- `NULL` (kept verbatim; was `NULL`)
  - `DELETED_DATE` <- `NULL` (kept verbatim; was `NULL`)
  - `DELETED_BY` <- `NULL` (kept verbatim; was `NULL`)
  - `VERSION_SEQ` <- `1` (via s4_scored; was `version_seq`)
  - `PERIOD_REFERENCE_TIME` <- `NULL` (kept verbatim; was `NULL`)
  - `LAST_UPDATE_DATE` <- `:P_RUN_TS` (via s4_scored; was `run_ts`)
  - `UPDATED_BY` <- `'m_Tgt_C_S_FSS_Pty_Addr'` (via s4_scored; was `mapping_name`)
  - `CREATE_DATE` <- `DT_LAST_UPDATE` (via s4_scored; was `DT_LAST_UPDATE`)
  - `CREATOR` <- `NULL` (kept verbatim; was `NULL`)
  - `SRC_ROWID` <- `PKEY_SRC_OBJECT` (via s4_scored; was `pkey_src_object`)
  - `HUB_STATE_IND` <- `1` (via s4_scored; was `hub_state_ind`)
  - `PTY_RLE_FK` <- `NVL(PTY_SRC_KEY, '') || '|Member'` (via s4_scored; was `pty_rle_fk`)
  - `ADDR_TP` <- `'002'` (via s4_scored; was `addr_tp`)
  - `USG_TP` <- `NULL` (kept verbatim; was `NULL`)
  - `PREF_LVL` <- `'Primary'` (via s4_scored; was `pref_lvl`)
  - `HIERARCHY_CODE` <- `'Member'` (via s4_scored; was `hierarchy_code`)
  - `HM_REL_TP_CD` <- `'Member Addr'` (via s4_scored; was `hm_rel_tp_cd`)
  - `LOC_IDN` <- `NVL(TO_VARCHAR(ID_CLIENT), '') || '|' || NVL(TO_VARCHAR(ID_REGISTRATION_CLIENT), '')` (via s4_scored; was `loc_idn`)
  - `SRC_LAST_UPD_DT` <- `DT_LAST_UPDATE` (via s4_scored; was `DT_LAST_UPDATE`)
  - `ADDR_LN_1` <- `(ADDR_LINE1::VARCHAR)` (via s4_scored; was `hold_line1`)
  - `ADDR_LN_2` <- `(ADDR_LINE1::VARCHAR)` (via s4_scored; was `hold_line2`)
  - `BLDNG_NM` <- `NULL::VARCHAR` (via s4_scored; was `a_building_name`)
  - `FLR_NUM` <- `NULL` (kept verbatim; was `NULL`)
  - `CITY` <- `ADDR_CITY::VARCHAR` (via s4_scored; was `a_city`)
  - `COUNTY` <- `NULL` (via s4_scored; was `a_county_fips`)
  - `STATE` <- `(SUBSTR(TRIM(ADDR_ZIP), 1, 5))::VARCHAR` (via s4_scored; was `a_state_fips`)
  - `CNTRY_CD` <- `'US'::VARCHAR` (via s4_scored; was `a_country`)
  - `PSTL_CD` <- `SUBSTR(TRIM(ADDR_ZIP), 1, 5)::VARCHAR` (via s4_scored; was `a_zip_cd_5`)
  - `PSTL_CD_EXT` <- `SUBSTR(TRIM(ADDR_ZIP), 7, 4)::VARCHAR` (via s4_scored; was `a_zip_cd_4_extn`)
  - `LCTN_CRDNT_DESC` <- `NULL` (kept verbatim; was `NULL`)
  - `LATTD` <- `0::NUMBER(38, 6)` (via s4_scored; was `a_latitude`)
  - `LNGTD` <- `0::NUMBER(38, 6)` (via s4_scored; was `a_longitude`)
  - `PSTL_BRCD` <- `NULL` (kept verbatim; was `NULL`)
  - `VLDTN_MSG` <- `NULL::VARCHAR` (via s4_scored; was `a_match_code`)
  - `RGN_CD` <- `NULL` (kept verbatim; was `NULL`)
  - `MLBLTY_SCR` <- `NULL::VARCHAR` (via s4_scored; was `a_mailability_score`)
  - `ADDR_TP_CD` <- `NULL::VARCHAR` (via s4_scored; was `a_address_type`)
  - `ORG_DESC` <- `NULL::VARCHAR` (via s4_scored; was `a_org_descriptor`)
  - `ORG_NM` <- `NULL::VARCHAR` (via s4_scored; was `a_org_name`)
  - `BLDG_NMBR` <- `NULL::VARCHAR` (via s4_scored; was `a_building_number`)
  - `SUB_BLDG_NM` <- `NULL::VARCHAR` (via s4_scored; was `a_sub_building_complete`)
  - `SUB_BLDG_DESC` <- `NULL::VARCHAR` (via s4_scored; was `a_sub_building_descriptor`)
  - `GEOCD_STS_CD` <- `NULL::VARCHAR` (via s4_scored; was `a_geocoding_status`)
  - `RSDNTL_DLVRY_IND` <- `NULL::VARCHAR` (via s4_scored; was `a_residential`)
  - `SRC_ADDR_LN_1` <- `ADDR_LINE1` (via s4_scored; was `ADDR_LINE1`)
  - `SRC_ADDR_LN_2` <- `ADDR_LINE2` (via s4_scored; was `ADDR_LINE2`)
  - `SRC_CITY` <- `ADDR_CITY` (via s4_scored; was `ADDR_CITY`)
  - `SRC_COUNTY` <- `CD_CNTY` (via s4_scored; was `CD_CNTY`)
  - `SRC_STATE` <- `ADDR_STATE` (via s4_scored; was `ADDR_STATE`)
  - `SRC_CNTRY` <- `'US'` (via s4_scored; was `src_cntry`)
  - `SRC_PSTL_CD` <- `ADDR_ZIP` (via s4_scored; was `ADDR_ZIP`)
  - `SRC_PSTL_CD_EXT` <- `NULL` (kept verbatim; was `NULL`)
  - `EFF_STRT_DT` <- `DT_LAST_UPDATE` (via s4_scored; was `DT_LAST_UPDATE`)
  - `EFF_END_DT` <- `NULL` (kept verbatim; was `NULL`)
  - `PERIOD_START_DATE` <- `DT_CREATED` (via s4_scored; was `DT_CREATED`)

### sp_snow_pub_FSS_ALT_C_S_FSS_PTY_RLE_ALT_ID.sql -> C_S_FSS_PTY_RLE_ALT_ID

- Kept steps: `s1_src`. P_RUN_TS: YES.
- WHERE gate dropped: `none`.
- Column map:
  - `PKEY_SRC_OBJECT` <- `PKEY_SRC_OBJECT` (via s2_filtered; was `x.pkey_src_object`)
  - `PTY_RLE_FK` <- `PTY_RLE_FK` (via s2_filtered; was `x.pty_rle_fk`)
  - `ALT_ID_TP` <- `ALT_ID_TP` (via s2_filtered; was `x.alt_id_tp`)
  - `ALT_ID_VAL` <- `LPAD(TO_VARCHAR(ID_CLIENT), 10, '0')` (expression kept; was `LPAD(TO_VARCHAR(x.ID_CLIENT), 10, '0')`)
  - `SRC_LAST_UPD_DT` <- `:P_RUN_TS` (kept verbatim; was `:P_RUN_TS`)
  - `HUB_STATE_IND` <- `1` (kept verbatim; was `1`)
  - `STS_CD` <- `'Issued'` (kept verbatim; was `'Issued'`)
  - `SRC_ROWID` <- `NVL(TO_VARCHAR(ID_CLIENT), '') || '|' || ALT_ID_TP` (expression kept; was `NVL(TO_VARCHAR(x.ID_CLIENT), '') || '|' || x.alt_id_tp`)
  - `LAST_UPDATE_DATE` <- `:P_RUN_TS` (kept verbatim; was `:P_RUN_TS`)
  - `VERSION_SEQ` <- `1` (kept verbatim; was `1 /* TIMELINE: VERSION_SEQ */`)
  - `ALT_ID_TP_FLTR` <- `ALT_ID_TP` (via s2_filtered; was `x.alt_id_tp`)
  - `CREATE_DATE` <- `DT_CREATED` (via s2_filtered; was `x.DT_CREATED`)
  - `PERIOD_START_DATE` <- `DT_CREATED` (via s2_filtered; was `x.DT_CREATED /* TIMELINE */`)

### sp_snow_pub_FSS_PHN_C_S_FSS_PTY_RLE_EADDR.sql -> C_S_FSS_PTY_RLE_EADDR

- Kept steps: `s1_src`. P_RUN_TS: YES.
- WHERE gate dropped: `WHERE grp_email_good AND uq_eaddr`.
- Columns set to NULL (no first-step source): USG_TP (kept verbatim), ELEC_ADDR (via s4_routed).
- Column map:
  - `PKEY_SRC_OBJECT` <- `EADDR_PKEY` (via s4_routed; was `eaddr_pkey`)
  - `PERIOD_START_DATE` <- `DT_LAST_UPDATE` (via s4_routed; was `DT_LAST_UPDATE`)
  - `VERSION_SEQ` <- `'1'` (via s4_routed; was `version_seq`)
  - `LAST_UPDATE_DATE` <- `:P_RUN_TS` (via s4_routed; was `run_ts`)
  - `CREATE_DATE` <- `:P_RUN_TS` (via s4_routed; was `run_ts`)
  - `SRC_ROWID` <- `EADDR_PKEY` (via s4_routed; was `eaddr_pkey`)
  - `HUB_STATE_IND` <- `1` (via s4_routed; was `hub_state_ind`)
  - `PTY_RLE_FK` <- `PTY_RLE_FK` (via s4_routed; was `pty_rle_fk`)
  - `ADDR_TP` <- `'001'` (via s4_routed; was `eaddr_addr_tp`)
  - `USG_TP` <- `NULL` (kept verbatim; was `NULL`)
  - `ELEC_ADDR` <- `NULL` (via s4_routed; was `std_email`)
  - `STS_CD` <- `'Active'` (via s4_routed; was `eaddr_sts_cd`)
  - `IS_VLD` <- `'Y'` (via s4_routed; was `eaddr_is_vld`)
  - `SRC_LAST_UPD_DT` <- `DT_LAST_UPDATE` (via s4_routed; was `DT_LAST_UPDATE`)

### sp_snow_pub_FSS_PHN_C_S_FSS_PTY_RLE_PHN.sql -> C_S_FSS_PTY_RLE_PHN

- Kept steps: `s1_src`. P_RUN_TS: YES.
- WHERE gate dropped: `WHERE grp_phone_good AND uq_phn`.
- Columns set to NULL (no first-step source): PHN_NUM_EXT (via s4_routed).
- Column map:
  - `PKEY_SRC_OBJECT` <- `PHN_PKEY` (via s4_routed; was `phn_pkey`)
  - `PERIOD_START_DATE` <- `DT_LAST_UPDATE` (via s4_routed; was `DT_LAST_UPDATE`)
  - `VERSION_SEQ` <- `'1'` (via s4_routed; was `version_seq`)
  - `LAST_UPDATE_DATE` <- `:P_RUN_TS` (via s4_routed; was `run_ts`)
  - `SRC_ROWID` <- `PHN_PKEY` (via s4_routed; was `phn_pkey`)
  - `HUB_STATE_IND` <- `1` (via s4_routed; was `hub_state_ind`)
  - `PTY_RLE_FK` <- `PTY_RLE_FK` (via s4_routed; was `pty_rle_fk`)
  - `PHN_TP` <- `'Telephone'` (via s4_routed; was `phn_tp`)
  - `USG_TP` <- `'001'` (via s4_routed; was `usg_tp`)
  - `PHN_NUM` <- `NBR_PHONE` (via s4_routed; was `std_phone`)
  - `PREF_LVL` <- `'Primary'` (via s4_routed; was `pref_lvl`)
  - `SRC_LAST_UPD_DT` <- `DT_LAST_UPDATE` (via s4_routed; was `DT_LAST_UPDATE`)
  - `PHN_NUM_EXT` <- `NULL` (via s4_routed; was `phn_num_ext`)

### sp_snow_pub_FSS_PTY_C_S_FSS_PTY.sql -> C_S_FSS_PTY

- Kept steps: `s1_src`. P_RUN_TS: YES.
- WHERE gate dropped: `WHERE uq_pty`.
- Columns set to NULL (no first-step source): ETHNCTY (column MSTR_CODE_VALUE not produced by lkp_cv), PRFRD_LANG_CD (column MSTR_CODE_VALUE not produced by lkp_cv), SFX_NM (column MSTR_CODE_VALUE not produced by lkp_cv_any).
- Column map:
  - `PKEY_SRC_OBJECT` <- `TRIM(PTY_SRC_KEY)` (via s4_routed; was `pkey_trim`)
  - `PERIOD_START_DATE` <- `DT_LAST_UPDATE` (via s4_routed; was `DT_LAST_UPDATE`)
  - `VERSION_SEQ` <- `1` (via s4_routed; was `version_seq`)
  - `LAST_UPDATE_DATE` <- `:P_RUN_TS` (via s4_routed; was `run_ts`)
  - `CREATE_DATE` <- `DT_LAST_UPDATE` (via s4_routed; was `DT_LAST_UPDATE`)
  - `SRC_ROWID` <- `TRIM(PTY_SRC_KEY)` (via s4_routed; was `pkey_trim`)
  - `HUB_STATE_IND` <- `1` (via s4_routed; was `hub_state_ind`)
  - `PTY_BO_CLASS_CD` <- `'Indv'` (via s4_routed; was `pty_bo_class_cd`)
  - `PRFX_NM` <- `NULL::VARCHAR` (via s4_routed; was `std_prfx_name`)
  - `FRST_NM` <- `((INITCAP(NM_FIRST, ' ')))::VARCHAR` (via s4_routed; was `std_first_name`)
  - `MDL_NM` <- `((INITCAP(NM_MIDDLE, ' ')))::VARCHAR` (via s4_routed; was `std_mdl_name`)
  - `LST_NM` <- `((INITCAP(NM_LAST, ' ')))::VARCHAR` (via s4_routed; was `std_lst_name`)
  - `FULL_NM` <- `TRIM(NVL(((INITCAP(NM_FIRST, ' '))), '')
                            || (' ' || TRIM(((INITCAP(NM_MIDDLE, ' ')))))
                            || ' '
                            || NVL(LTRIM(((INITCAP(NM_LAST, ' ')))), ''))::VARCHAR` (via s4_routed; was `std_full_name`)
  - `GNDR_CD` <- `CASE WHEN 'Indv' IN ('I', 'Indv', 'INDV', 'HCP') AND LEFT(CD_GENDER, 1) IN ('B', 'U') THEN NULL
                 WHEN 'Indv' IN ('I', 'Indv', 'INDV', 'HCP') AND LEFT(CD_GENDER, 1) = 'M' THEN '1'
                 WHEN 'Indv' IN ('I', 'Indv', 'INDV', 'HCP') AND LEFT(CD_GENDER, 1) = 'F' THEN '2'
                 ELSE NULL END::VARCHAR` (via s4_routed; was `mdm_gender_code`)
  - `BIRTH_DT` <- `DT_DOB` (via s4_routed; was `DT_DOB`)
  - `SRC_FULL_NM` <- `NVL(TRIM(NVL(NM_FIRST, '') || IFF(NM_MIDDLE IS NOT NULL, ' ' || TRIM(NM_MIDDLE), '')
                    || ' ' || NVL(LTRIM(NM_LAST), '')), NVL(TRIM(NM_FIRST), '') || ' ' || NVL(TRIM(NM_LAST), ''))::VARCHAR` (via s4_routed; was `std_src_full_name`)
  - `ETHNCTY` <- `NULL` (column MSTR_CODE_VALUE not produced by lkp_cv; was `ethnicity_mstr`)
  - `SRC_ETHNCTY` <- `CD_HISPANIC` (via s4_routed; was `CD_HISPANIC`)
  - `RACE_CD` <- `CASE WHEN RACE_WHITE + RACE_AA + RACE_ASIAN + RACE_PI + RACE_AN = 2
                     THEN '006'
                 WHEN RACE_WHITE + RACE_AA + RACE_ASIAN + RACE_PI + RACE_AN > 2
                     THEN '007'
                 WHEN RACE_WHITE + RACE_AA + RACE_ASIAN + RACE_PI + RACE_AN = 0
                     THEN NULL
                 WHEN RACE_WHITE + RACE_AA + RACE_ASIAN + RACE_PI + RACE_AN = 1
                     THEN CASE WHEN RACE_WHITE = 1 THEN '001'
                               WHEN RACE_AA = 1 THEN '002'
                               WHEN RACE_AN = 1 THEN '003'
                               WHEN RACE_ASIAN = 1 THEN '004'
                               WHEN RACE_PI = 1 THEN '005' END
                 ELSE NULL END::VARCHAR` (via s4_routed; was `mdm_race_cd`)
  - `SRC_RACE_CD` <- `'WH' || NVL(TO_VARCHAR(RACE_WHITE), '') || 'AA' || NVL(TO_VARCHAR(RACE_AA), '')
            || 'AS' || NVL(TO_VARCHAR(RACE_ASIAN), '') || 'PI' || NVL(TO_VARCHAR(RACE_PI), '')
            || 'NA' || NVL(TO_VARCHAR(RACE_AN), '')::VARCHAR` (via s4_routed; was `src_race_ind_list`)
  - `SRC_LAST_UPD_DT` <- `DT_LAST_UPDATE` (via s4_routed; was `DT_LAST_UPDATE`)
  - `PRFRD_LANG_CD` <- `NULL` (column MSTR_CODE_VALUE not produced by lkp_cv; was `language_mstr`)
  - `SFX_NM` <- `NULL` (column MSTR_CODE_VALUE not produced by lkp_cv_any; was `std_suffix`)

### sp_snow_pub_FSS_PTY_C_S_FSS_PTY_RLE.sql -> C_S_FSS_PTY_RLE

- Kept steps: `s1_src`. P_RUN_TS: YES.
- WHERE gate dropped: `WHERE uq_rle`.
- Column map:
  - `PKEY_SRC_OBJECT` <- `TRIM(PTY_SRC_KEY) || '|' || 'Member'` (via s4_routed; was `rle_pkey`)
  - `PERIOD_START_DATE` <- `DT_LAST_UPDATE` (via s4_routed; was `DT_LAST_UPDATE`)
  - `VERSION_SEQ` <- `1` (via s4_routed; was `version_seq`)
  - `LAST_UPDATE_DATE` <- `:P_RUN_TS` (via s4_routed; was `run_ts`)
  - `CREATE_DATE` <- `DT_LAST_UPDATE` (via s4_routed; was `DT_LAST_UPDATE`)
  - `SRC_ROWID` <- `TRIM(PTY_SRC_KEY) || '|' || 'Member'` (via s4_routed; was `rle_pkey`)
  - `HUB_STATE_IND` <- `1` (via s4_routed; was `hub_state_ind`)
  - `PTY_FK` <- `TRIM(PTY_SRC_KEY)` (via s4_routed; was `pkey_trim`)
  - `RLE_BO_CLASS_CD` <- `'Member'` (via s4_routed; was `rle_bo_class_cd`)
  - `SRC_LAST_UPD_DT` <- `DT_LAST_UPDATE` (via s4_routed; was `DT_LAST_UPDATE`)

### sp_snow_pub_FSS_REL_C_S_FSS_PTY_RLE_REL.sql -> C_S_FSS_PTY_RLE_REL

- Kept steps: `s1_src`. P_RUN_TS: YES.
- WHERE gate dropped: `WHERE mstr_ref_code IS NOT NULL AND uq_rel`.
- Columns set to NULL (no first-step source): REL_TP (via s4_final), PKEY_SRC_OBJECT (via s4_final), SRC_ROWID (via s4_final).
- Column map:
  - `REL_TP` <- `NULL` (via s4_final; was `mstr_ref_code`)
  - `VERSION_SEQ` <- `1` (via s4_final; was `version_seq`)
  - `HUB_STATE_IND` <- `1` (via s4_final; was `hub_state_ind`)
  - `REL_TYPE_CODE` <- `'Member Relationship'` (via s4_final; was `rel_type_code`)
  - `HIERARCHY_CODE` <- `'Member'` (via s4_final; was `hierarchy_code`)
  - `UPDATED_BY` <- `'batchload'` (via s4_final; was `batch_user`)
  - `LAST_UPDATE_DATE` <- `:P_RUN_TS` (via s4_final; was `run_ts`)
  - `PERIOD_START_DATE` <- `RELN_DT_CREATED` (via s4_final; was `RELN_DT_CREATED`)
  - `PKEY_SRC_OBJECT` <- `NULL` (via s4_final; was `rel_pkey`)
  - `PTY_RLE_FK_1` <- `NVL(IFF(RELATION_DIRECTION = 'To Child', RELN_PTY_SRC_KEY, PTY_SRC_KEY), '') || '|Member'` (via s4_final; was `rel_fk_1`)
  - `PTY_RLE_FK_2` <- `NVL(IFF(RELATION_DIRECTION = 'To Child', PTY_SRC_KEY, RELN_PTY_SRC_KEY), '') || '|Member'` (via s4_final; was `rel_fk_2`)
  - `SRC_LAST_UPD_DT` <- `RELN_DT_LAST_UPDATE` (via s4_final; was `RELN_DT_LAST_UPDATE`)
  - `CREATOR` <- `'batchload'` (via s4_final; was `batch_user`)
  - `SRC_ROWID` <- `NULL` (via s4_final; was `rel_pkey`)
  - `CREATE_DATE` <- `RELN_DT_LAST_UPDATE` (via s4_final; was `RELN_DT_LAST_UPDATE`)

## Dropped (not C_S_* targets)

- sp_snow_pub_FSS_ADR_DQM_ADDRESS.sql -> DQM_ADDRESS
- sp_snow_pub_FSS_ADR_EXC_STG_BAD_REC_MEMB.sql -> EXC_STG_BAD_REC_MEMB
- sp_snow_pub_FSS_PHN_EXC_STG_BAD_REC_MEMB_EMAIL.sql -> EXC_STG_BAD_REC_MEMB
- sp_snow_pub_FSS_PHN_EXC_STG_BAD_REC_MEMB_EXTENSION.sql -> EXC_STG_BAD_REC_MEMB
- sp_snow_pub_FSS_PHN_EXC_STG_BAD_REC_MEMB_PHONE.sql -> EXC_STG_BAD_REC_MEMB
- sp_snow_pub_FSS_PTY_EXC_STG_BAD_REC_MEMB_BIRTH.sql -> EXC_STG_BAD_REC_MEMB
- sp_snow_pub_FSS_PTY_EXC_STG_BAD_REC_MEMB_ETHNICITY.sql -> EXC_STG_BAD_REC_MEMB
- sp_snow_pub_FSS_PTY_EXC_STG_BAD_REC_MEMB_GENDER.sql -> EXC_STG_BAD_REC_MEMB
- sp_snow_pub_FSS_PTY_EXC_STG_BAD_REC_MEMB_LANGUAGE.sql -> EXC_STG_BAD_REC_MEMB
- sp_snow_pub_FSS_PTY_EXC_STG_BAD_REC_MEMB_RACE.sql -> EXC_STG_BAD_REC_MEMB
- sp_snow_pub_FSS_PTY_EXC_STG_BAD_REC_MEMB_SUFFIX.sql -> EXC_STG_BAD_REC_MEMB
- sp_snow_pub_FSS_REL_EXC_STG_BAD_REC_MEMB.sql -> EXC_STG_BAD_REC_MEMB
- sp_snow_pub_FSS_VAL_EXC_STG_BAD_REC_MEMB.sql -> EXC_STG_BAD_REC_MEMB
- sp_snow_pub_FSS_VAL_STG_FSS_PTY_INACTIVE_LOG.sql -> STG_FSS_PTY_INACTIVE_LOG
- sp_snow_pub_FSS_VAL_STG_FSS_PTY_INACTIVE_STS_NEW.sql -> STG_FSS_PTY_INACTIVE_STS
- sp_snow_pub_FSS_VAL_STG_FSS_PTY_INACTIVE_STS_REACTIVATION.sql -> STG_FSS_PTY_INACTIVE_STS

