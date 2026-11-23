# WIC publish_dest S10-only map

S10-only twins: ONLY the first (source) step is inlined as a CTE;
later steps and the WHERE gate are dropped. Each target column is
aliased from a first-step column, a literal, or a parameter. A
column the first step does not carry is NULL (recorded below).

Built: 6 twins. Dropped (not C_S_* targets): 13. Failed: 0.

## Twins

### sp_snow_pub_WIC_ADR_C_S_WIC_PTY_RLE_ADDR.sql -> C_S_WIC_PTY_RLE_ADDR

- Kept steps: `s10_active`. P_RUN_TS: YES.
- WHERE gate dropped: `WHERE score = '100' AND uq_addr`.
- Columns set to NULL (no first-step source): ROWID_OBJECT (kept verbatim), DELETED_IND (kept verbatim), DELETED_DATE (kept verbatim), DELETED_BY (kept verbatim), USG_TP (kept verbatim), FLR_NUM (kept verbatim), LCTN_CRDNT_DESC (kept verbatim), PSTL_BRCD (kept verbatim), RGN_CD (kept verbatim), SRC_STATE (kept verbatim), SRC_PSTL_CD_EXT (kept verbatim), EFF_END_DT (kept verbatim), CREATOR (kept verbatim), PERIOD_REFERENCE_TIME (kept verbatim), COUNTY (via s40_scored).
- Column map:
  - `PKEY_SRC_OBJECT` <- `PKEY_SRC_OBJECT` (via s40_scored; was `pkey_src_object`)
  - `ROWID_OBJECT` <- `NULL` (kept verbatim; was `NULL`)
  - `DELETED_IND` <- `NULL` (kept verbatim; was `NULL`)
  - `DELETED_DATE` <- `NULL` (kept verbatim; was `NULL`)
  - `DELETED_BY` <- `NULL` (kept verbatim; was `NULL`)
  - `PERIOD_START_DATE` <- `DATE_ADDRESS_VALID_FROM` (via s40_scored; was `DATE_ADDRESS_VALID_FROM`)
  - `VERSION_SEQ` <- `1` (via s40_scored; was `version_seq`)
  - `UPDATED_BY` <- `'m_Tgt_C_S_WIC_Pty_Addr'` (via s40_scored; was `mapping_name`)
  - `LAST_UPDATE_DATE` <- `:P_RUN_TS` (via s40_scored; was `run_ts`)
  - `PREF_LVL` <- `'Primary'` (via s40_scored; was `pref_lvl`)
  - `LOC_IDN` <- `NVL(TO_VARCHAR(ID), '') || '|' || NVL(TO_VARCHAR(FID), '')` (via s40_scored; was `loc_idn`)
  - `HM_REL_TP_CD` <- `'Member Addr'` (via s40_scored; was `hm_rel_tp_cd`)
  - `HUB_STATE_IND` <- `1` (via s40_scored; was `hub_state_ind`)
  - `SRC_ROWID` <- `PKEY_SRC_OBJECT` (via s40_scored; was `pkey_src_object`)
  - `USG_TP` <- `NULL` (kept verbatim; was `NULL`)
  - `HIERARCHY_CODE` <- `'Member'` (via s40_scored; was `hierarchy_code`)
  - `ADDR_LN_1` <- `(ADDRESS1::VARCHAR)` (via s40_scored; was `hold_line1`)
  - `ADDR_LN_2` <- `(ADDRESS1::VARCHAR)` (via s40_scored; was `hold_line2`)
  - `SRC_LAST_UPD_DT` <- `DATE_ADDRESS_VALID_FROM` (via s40_scored; was `DATE_ADDRESS_VALID_FROM`)
  - `FLR_NUM` <- `NULL` (kept verbatim; was `NULL`)
  - `LCTN_CRDNT_DESC` <- `NULL` (kept verbatim; was `NULL`)
  - `PSTL_BRCD` <- `NULL` (kept verbatim; was `NULL`)
  - `RGN_CD` <- `NULL` (kept verbatim; was `NULL`)
  - `SRC_ADDR_LN_1` <- `ADDRESS1` (via s40_scored; was `ADDRESS1`)
  - `SRC_ADDR_LN_2` <- `ADDRESS2` (via s40_scored; was `ADDRESS2`)
  - `SRC_CITY` <- `CITY` (via s40_scored; was `CITY`)
  - `SRC_COUNTY` <- `COUNTY` (via s40_scored; was `COUNTY`)
  - `SRC_STATE` <- `NULL` (kept verbatim; was `NULL`)
  - `SRC_CNTRY` <- `'US'` (via s40_scored; was `src_cntry`)
  - `SRC_PSTL_CD` <- `ZIP_CODE` (via s40_scored; was `ZIP_CODE`)
  - `SRC_PSTL_CD_EXT` <- `NULL` (kept verbatim; was `NULL`)
  - `EFF_STRT_DT` <- `DATE_ADDRESS_VALID_FROM` (via s40_scored; was `DATE_ADDRESS_VALID_FROM`)
  - `EFF_END_DT` <- `NULL` (kept verbatim; was `NULL`)
  - `ADDR_TP` <- `'002'` (via s40_scored; was `addr_tp`)
  - `PTY_RLE_FK` <- `NVL(PTY_SRC_KEY, '') || '|Member'` (via s40_scored; was `pty_rle_fk`)
  - `CREATE_DATE` <- `DATE_ADDRESS_VALID_FROM` (via s40_scored; was `DATE_ADDRESS_VALID_FROM`)
  - `CREATOR` <- `NULL` (kept verbatim; was `NULL`)
  - `PERIOD_REFERENCE_TIME` <- `NULL` (kept verbatim; was `NULL`)
  - `CITY` <- `CITY::VARCHAR` (via s40_scored; was `a_city`)
  - `PSTL_CD` <- `SUBSTR(TRIM(ZIP_CODE), 1, 5)::VARCHAR` (via s40_scored; was `a_zip_cd_5`)
  - `CNTRY_CD` <- `'US'::VARCHAR` (via s40_scored; was `a_country`)
  - `VLDTN_MSG` <- `NULL::VARCHAR` (via s40_scored; was `a_match_code`)
  - `LATTD` <- `0::NUMBER(38, 6)` (via s40_scored; was `a_latitude`)
  - `LNGTD` <- `0::NUMBER(38, 6)` (via s40_scored; was `a_longitude`)
  - `COUNTY` <- `NULL` (via s40_scored; was `a_county_fips`)
  - `MLBLTY_SCR` <- `NULL::VARCHAR` (via s40_scored; was `a_mailability_score`)
  - `STATE` <- `(SUBSTR(TRIM(ZIP_CODE), 1, 5))::VARCHAR` (via s40_scored; was `a_state_fips`)
  - `RSDNTL_DLVRY_IND` <- `NULL::VARCHAR` (via s40_scored; was `a_residential`)
  - `ORG_DESC` <- `NULL::VARCHAR` (via s40_scored; was `a_org_descriptor`)
  - `ADDR_TP_CD` <- `NULL::VARCHAR` (via s40_scored; was `a_address_type`)
  - `ORG_NM` <- `NULL::VARCHAR` (via s40_scored; was `a_org_name`)
  - `BLDNG_NM` <- `NULL::VARCHAR` (via s40_scored; was `a_building_name`)
  - `GEOCD_STS_CD` <- `NULL::VARCHAR` (via s40_scored; was `a_geocoding_status`)
  - `SUB_BLDG_NM` <- `NULL::VARCHAR` (via s40_scored; was `a_sub_building_complete`)
  - `SUB_BLDG_DESC` <- `NULL::VARCHAR` (via s40_scored; was `a_sub_building_descriptor`)
  - `BLDG_NMBR` <- `NULL::VARCHAR` (via s40_scored; was `a_building_number`)
  - `PSTL_CD_EXT` <- `SUBSTR(TRIM(ZIP_CODE), 7, 4)::VARCHAR` (via s40_scored; was `a_zip_cd_4_extn`)

### sp_snow_pub_WIC_ALT_C_S_WIC_PTY_RLE_ALT_ID.sql -> C_S_WIC_PTY_RLE_ALT_ID

- Kept steps: `s10_keys`. P_RUN_TS: YES.
- WHERE gate dropped: `none`.
- Column map:
  - `PKEY_SRC_OBJECT` <- `PKEY_SRC_OBJECT` (via s20_ready; was `x.pkey_src_object`)
  - `SRC_ROWID` <- `NVL(TO_VARCHAR(ID), '') || '|' || ALT_ID_TP` (expression kept; was `NVL(TO_VARCHAR(x.ID), '') || '|' || x.alt_id_tp`)
  - `VERSION_SEQ` <- `1` (kept verbatim; was `1 /* TIMELINE: VERSION_SEQ */`)
  - `PTY_RLE_FK` <- `PTY_RLE_FK` (via s20_ready; was `x.pty_rle_fk`)
  - `ALT_ID_TP` <- `ALT_ID_TP` (via s20_ready; was `x.alt_id_tp`)
  - `ALT_ID_VAL` <- `LPAD(TO_VARCHAR(ID), 12, '0')` (expression kept; was `LPAD(TO_VARCHAR(x.ID), 12, '0')`)
  - `CREATE_DATE` <- `DATEKEY` (via s20_ready; was `x.DATEKEY`)
  - `LAST_UPDATE_DATE` <- `:P_RUN_TS` (kept verbatim; was `:P_RUN_TS`)
  - `ALT_ID_TP_FLTR` <- `ALT_ID_TP` (via s20_ready; was `x.alt_id_tp`)
  - `SRC_LAST_UPD_DT` <- `DATEKEY` (via s20_ready; was `x.DATEKEY /* IIF(IsNull(DATEKEY), DATEKEY, DATEKEY) */`)
  - `STS_CD` <- `'Issued'` (kept verbatim; was `'Issued'`)
  - `PERIOD_START_DATE` <- `DATEKEY` (via s20_ready; was `x.DATEKEY /* TIMELINE */`)

### sp_snow_pub_WIC_PHN_C_S_WIC_PTY_RLE_EADDR.sql -> C_S_WIC_PTY_RLE_EADDR

- Kept steps: `s10_src`. P_RUN_TS: YES.
- WHERE gate dropped: `WHERE grp_email_good AND uq_eaddr`.
- Columns set to NULL (no first-step source): ELEC_ADDR (via s40_ready), USG_TP (kept verbatim).
- Column map:
  - `PKEY_SRC_OBJECT` <- `EADDR_PKEY` (via s40_ready; was `eaddr_pkey`)
  - `PERIOD_START_DATE` <- `DATEKEY` (via s40_ready; was `DATEKEY`)
  - `VERSION_SEQ` <- `'1'` (via s40_ready; was `version_seq`)
  - `LAST_UPDATE_DATE` <- `:P_RUN_TS` (via s40_ready; was `run_ts`)
  - `CREATE_DATE` <- `:P_RUN_TS` (via s40_ready; was `run_ts`)
  - `SRC_ROWID` <- `EADDR_PKEY` (via s40_ready; was `eaddr_pkey`)
  - `HUB_STATE_IND` <- `1` (via s40_ready; was `hub_state_ind`)
  - `PTY_RLE_FK` <- `PTY_RLE_FK` (via s40_ready; was `pty_rle_fk`)
  - `ELEC_ADDR` <- `NULL` (via s40_ready; was `std_email`)
  - `USG_TP` <- `NULL` (kept verbatim; was `NULL`)
  - `STS_CD` <- `'Active'` (via s40_ready; was `eaddr_sts_cd`)
  - `IS_VLD` <- `'Y'` (via s40_ready; was `eaddr_is_vld`)
  - `SRC_LAST_UPD_DT` <- `DATEKEY` (via s40_ready; was `DATEKEY`)
  - `ADDR_TP` <- `'001'` (via s40_ready; was `eaddr_addr_tp`)

### sp_snow_pub_WIC_PHN_C_S_WIC_PTY_RLE_PHN.sql -> C_S_WIC_PTY_RLE_PHN

- Kept steps: `s10_src`. P_RUN_TS: YES.
- WHERE gate dropped: `WHERE grp_phone_good AND uq_phn`.
- Column map:
  - `PKEY_SRC_OBJECT` <- `PHN_PKEY` (via s40_ready; was `phn_pkey`)
  - `PERIOD_START_DATE` <- `DATEKEY` (via s40_ready; was `DATEKEY`)
  - `VERSION_SEQ` <- `'1'` (via s40_ready; was `version_seq`)
  - `LAST_UPDATE_DATE` <- `:P_RUN_TS` (via s40_ready; was `run_ts`)
  - `SRC_ROWID` <- `PHN_PKEY` (via s40_ready; was `phn_pkey`)
  - `PTY_RLE_FK` <- `PTY_RLE_FK` (via s40_ready; was `pty_rle_fk`)
  - `PHN_TP` <- `'Telephone'` (via s40_ready; was `phn_tp`)
  - `USG_TP` <- `'001'` (via s40_ready; was `usg_tp`)
  - `PHN_NUM` <- `STD_PHONE` (via s40_ready; was `std_phone`)
  - `PREF_LVL` <- `'Primary'` (via s40_ready; was `pref_lvl`)
  - `SRC_LAST_UPD_DT` <- `DATEKEY` (via s40_ready; was `DATEKEY`)
  - `HUB_STATE_IND` <- `1` (via s40_ready; was `hub_state_ind`)

### sp_snow_pub_WIC_PTY_C_S_WIC_PTY.sql -> C_S_WIC_PTY

- Kept steps: `s10_active`. P_RUN_TS: YES.
- WHERE gate dropped: `WHERE uq_pty`.
- Columns set to NULL (no first-step source): ETHNCTY (column MSTR_CODE_VALUE not produced by lkp_cv), PRFRD_LANG_CD (column MSTR_CODE_VALUE not produced by lkp_cv).
- Column map:
  - `PKEY_SRC_OBJECT` <- `TRIM(PTY_SRC_KEY)` (via s40_routed; was `pkey_trim`)
  - `VERSION_SEQ` <- `1` (via s40_routed; was `version_seq`)
  - `LAST_UPDATE_DATE` <- `:P_RUN_TS` (via s40_routed; was `run_ts`)
  - `SRC_ROWID` <- `TRIM(PTY_SRC_KEY)` (via s40_routed; was `pkey_trim`)
  - `HUB_STATE_IND` <- `1` (via s40_routed; was `hub_state_ind`)
  - `PTY_BO_CLASS_CD` <- `'Indv'` (via s40_routed; was `pty_bo_class_cd`)
  - `BIRTH_WGHT_GRMS` <- `BIRTH_WT_OZ * 28.35` (via s40_routed; was `birth_wght_grms`)
  - `PERIOD_START_DATE` <- `DATEKEY` (via s40_routed; was `DATEKEY`)
  - `CREATE_DATE` <- `DATEKEY` (via s40_routed; was `DATEKEY`)
  - `PRFX_NM` <- `NULL::VARCHAR` (via s40_routed; was `std_prfx_name`)
  - `FRST_NM` <- `((INITCAP(FIRST_NAME, ' ')))::VARCHAR` (via s40_routed; was `std_first_name`)
  - `MDL_NM` <- `((INITCAP(MIDDLE_NAME, ' ')))::VARCHAR` (via s40_routed; was `std_mdl_name`)
  - `LST_NM` <- `((INITCAP(LAST_NAME, ' ')))::VARCHAR` (via s40_routed; was `std_lst_name`)
  - `FULL_NM` <- `TRIM(NVL(((INITCAP(FIRST_NAME, ' '))), '')
                            || (' ' || TRIM(((INITCAP(MIDDLE_NAME, ' ')))))
                            || ' '
                            || NVL(LTRIM(((INITCAP(LAST_NAME, ' ')))), ''))::VARCHAR` (via s40_routed; was `std_full_name`)
  - `GNDR_CD` <- `CASE WHEN 'Indv' IN ('I', 'Indv', 'INDV', 'HCP') AND LEFT(GENDER, 1) IN ('B', 'U') THEN NULL
                 WHEN 'Indv' IN ('I', 'Indv', 'INDV', 'HCP') AND LEFT(GENDER, 1) = 'M' THEN '1'
                 WHEN 'Indv' IN ('I', 'Indv', 'INDV', 'HCP') AND LEFT(GENDER, 1) = 'F' THEN '2'
                 ELSE NULL END::VARCHAR` (via s40_routed; was `mdm_gender_code`)
  - `BIRTH_DT` <- `DOB` (via s40_routed; was `DOB`)
  - `SRC_RACE_CD` <- `'WH' || NVL(TO_VARCHAR(RACE_WHITE_IND), '') || 'AA' || NVL(TO_VARCHAR(RACE_AA_IND), '')
            || 'AS' || NVL(TO_VARCHAR(RACE_ASIAN_IND), '') || 'PI' || NVL(TO_VARCHAR(RACE_PI_IND), '')
            || 'NA' || NVL(TO_VARCHAR(RACE_AN_IND), '')::VARCHAR` (via s40_routed; was `src_race_ind_list`)
  - `RACE_CD` <- `CASE WHEN RACE_WHITE_IND + RACE_AA_IND + RACE_ASIAN_IND + RACE_PI_IND + RACE_AN_IND = 2
                     THEN '006'
                 WHEN RACE_WHITE_IND + RACE_AA_IND + RACE_ASIAN_IND + RACE_PI_IND + RACE_AN_IND > 2
                     THEN '007'
                 WHEN RACE_WHITE_IND + RACE_AA_IND + RACE_ASIAN_IND + RACE_PI_IND + RACE_AN_IND = 0
                     THEN NULL
                 WHEN RACE_WHITE_IND + RACE_AA_IND + RACE_ASIAN_IND + RACE_PI_IND + RACE_AN_IND = 1
                     THEN CASE WHEN RACE_WHITE_IND = 1 THEN '001'
                               WHEN RACE_AA_IND = 1 THEN '002'
                               WHEN RACE_AN_IND = 1 THEN '003'
                               WHEN RACE_ASIAN_IND = 1 THEN '004'
                               WHEN RACE_PI_IND = 1 THEN '005' END
                 ELSE NULL END::VARCHAR` (via s40_routed; was `mdm_race_cd`)
  - `ETHNCTY` <- `NULL` (column MSTR_CODE_VALUE not produced by lkp_cv; was `ethnicity_mstr`)
  - `SRC_ETHNCTY` <- `ETHNICITY` (via s40_routed; was `ETHNICITY`)
  - `PRFRD_LANG_CD` <- `NULL` (column MSTR_CODE_VALUE not produced by lkp_cv; was `language_mstr`)
  - `SRC_LAST_UPD_DT` <- `DATEKEY` (via s40_routed; was `DATEKEY`)
  - `SRC_PRFRD_LANG_CD` <- `LANGUAGE_CD` (via s40_routed; was `LANGUAGE_CD`)
  - `SRC_FULL_NM` <- `NVL(TRIM(NVL(FIRST_NAME, '') || IFF(MIDDLE_NAME IS NOT NULL, ' ' || TRIM(MIDDLE_NAME), '')
                        || ' ' || NVL(LTRIM(LAST_NAME), '')), NVL(TRIM(FIRST_NAME), '') || ' ' || NVL(TRIM(LAST_NAME), ''))::VARCHAR` (via s40_routed; was `std_src_full_name`)

### sp_snow_pub_WIC_PTY_C_S_WIC_PTY_RLE.sql -> C_S_WIC_PTY_RLE

- Kept steps: `s10_active`. P_RUN_TS: YES.
- WHERE gate dropped: `WHERE uq_rle`.
- Column map:
  - `PKEY_SRC_OBJECT` <- `TRIM(PTY_SRC_KEY) || '|Member'` (via s40_routed; was `rle_pkey`)
  - `SRC_ROWID` <- `TRIM(PTY_SRC_KEY) || '|Member'` (via s40_routed; was `rle_pkey`)
  - `RLE_BO_CLASS_CD` <- `'Member'` (via s40_routed; was `rle_bo_class_cd`)
  - `PTY_FK` <- `TRIM(PTY_SRC_KEY)` (via s40_routed; was `pkey_trim`)
  - `VERSION_SEQ` <- `1` (via s40_routed; was `version_seq`)
  - `LAST_UPDATE_DATE` <- `:P_RUN_TS` (via s40_routed; was `run_ts`)
  - `HUB_STATE_IND` <- `1` (via s40_routed; was `hub_state_ind`)
  - `CREATE_DATE` <- `DATEKEY` (via s40_routed; was `DATEKEY`)
  - `PERIOD_START_DATE` <- `DATEKEY` (via s40_routed; was `DATEKEY`)
  - `SRC_LAST_UPD_DT` <- `DATEKEY` (via s40_routed; was `DATEKEY`)

## Dropped (not C_S_* targets)

- sp_snow_pub_WIC_ADR_DQM_ADDRESS.sql -> DQM_ADDRESS
- sp_snow_pub_WIC_ADR_EXC_STG_BAD_REC_MEMB.sql -> EXC_STG_BAD_REC_MEMB
- sp_snow_pub_WIC_PHN_EXC_STG_BAD_REC_MEMB_EMAIL.sql -> EXC_STG_BAD_REC_MEMB
- sp_snow_pub_WIC_PHN_EXC_STG_BAD_REC_MEMB_PHONE.sql -> EXC_STG_BAD_REC_MEMB
- sp_snow_pub_WIC_PTY_EXC_STG_BAD_REC_MEMB_BIRTH.sql -> EXC_STG_BAD_REC_MEMB
- sp_snow_pub_WIC_PTY_EXC_STG_BAD_REC_MEMB_ETHNICITY.sql -> EXC_STG_BAD_REC_MEMB
- sp_snow_pub_WIC_PTY_EXC_STG_BAD_REC_MEMB_GENDER.sql -> EXC_STG_BAD_REC_MEMB
- sp_snow_pub_WIC_PTY_EXC_STG_BAD_REC_MEMB_LANGUAGE.sql -> EXC_STG_BAD_REC_MEMB
- sp_snow_pub_WIC_PTY_EXC_STG_BAD_REC_MEMB_RACE.sql -> EXC_STG_BAD_REC_MEMB
- sp_snow_pub_WIC_VAL_EXC_STG_BAD_REC_MEMB.sql -> EXC_STG_BAD_REC_MEMB
- sp_snow_pub_WIC_VAL_STG_WIC_PTY_INACTIVE_LOG_DEACTIVATION.sql -> STG_WIC_PTY_INACTIVE_LOG
- sp_snow_pub_WIC_VAL_STG_WIC_PTY_INACTIVE_LOG_REACTIVATION.sql -> STG_WIC_PTY_INACTIVE_LOG
- sp_snow_pub_WIC_VAL_STG_WIC_PTY_INACTIVE_STS.sql -> STG_WIC_PTY_INACTIVE_STS

