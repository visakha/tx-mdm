# ECI publish_dest S10-only map

S10-only twins: ONLY the first (source) step is inlined as a CTE;
later steps and the WHERE gate are dropped. Each target column is
aliased from a first-step column, a literal, or a parameter. A
column the first step does not carry is NULL (recorded below).

Built: 7 twins. Dropped (not C_S_* targets): 19. Failed: 0.

## Twins

### sp_snow_pub_ECI_ADR_C_S_ECI_PTY_RLE_ADDR.sql -> C_S_ECI_PTY_RLE_ADDR

- Kept steps: `s10_src`. P_RUN_TS: YES.
- WHERE gate dropped: `WHERE score = '100' AND uq_addr`.
- Columns set to NULL (no first-step source): ROWID_OBJECT (kept verbatim), DELETED_IND (kept verbatim), DELETED_DATE (kept verbatim), DELETED_BY (kept verbatim), CREATOR (kept verbatim), PERIOD_REFERENCE_TIME (kept verbatim), PSTL_BRCD (kept verbatim), RGN_CD (kept verbatim), COUNTY (via s50_ready), LCTN_CRDNT_DESC (kept verbatim), FLR_NUM (kept verbatim), EFF_END_DT (kept verbatim).
- Column map:
  - `PKEY_SRC_OBJECT` <- `PTY_RLE_FK || '|' || NVL(MSTR_ADDR_TP, '') || '|'
                   || NVL(LPAD(TO_VARCHAR(ID_FAMILY_ADDRESS), 10, '0'), '') || '|'
                   || NVL(TRIM(UPPER(ADDRESS1)), '') || '|' || NVL(TRIM(UPPER(ADDRESS2)), '') || '|'
                   || NVL(UPPER(CITY_NAME), '') || '|' || NVL(UPPER(STATE_ABBREV), '') || '|'
                   || NVL(ZIP_CODE, '') || '|' || NVL(ZIP_SFX, '')` (via s50_ready; was `pkey_src_object`)
  - `ROWID_OBJECT` <- `NULL` (kept verbatim; was `NULL`)
  - `DELETED_IND` <- `NULL` (kept verbatim; was `NULL`)
  - `DELETED_DATE` <- `NULL` (kept verbatim; was `NULL`)
  - `DELETED_BY` <- `NULL` (kept verbatim; was `NULL`)
  - `PERIOD_START_DATE` <- `LAST_UPDATE_DATE` (via s50_ready; was `LAST_UPDATE_DATE`)
  - `VERSION_SEQ` <- `1` (via s50_ready; was `version_seq`)
  - `UPDATED_BY` <- `'m_Tgt_C_S_ECI_Pty_Addr'` (via s50_ready; was `mapping_name`)
  - `CREATE_DATE` <- `LAST_UPDATE_DATE` (via s50_ready; was `LAST_UPDATE_DATE`)
  - `CREATOR` <- `NULL` (kept verbatim; was `NULL`)
  - `ADDR_TP` <- `MSTR_ADDR_TP` (via s50_ready; was `mstr_addr_tp`)
  - `LAST_UPDATE_DATE` <- `:P_RUN_TS` (via s50_ready; was `run_ts`)
  - `PREF_LVL` <- `'Primary'` (via s50_ready; was `pref_lvl`)
  - `LOC_IDN` <- `TO_VARCHAR(TRUNC(ID)) || '|' || TO_VARCHAR(TRUNC(ID_FAMILY_ADDRESS))` (via s50_ready; was `loc_idn`)
  - `SRC_ROWID` <- `PTY_RLE_FK || '|' || NVL(MSTR_ADDR_TP, '') || '|'
                   || NVL(LPAD(TO_VARCHAR(ID_FAMILY_ADDRESS), 10, '0'), '') || '|'
                   || NVL(TRIM(UPPER(ADDRESS1)), '') || '|' || NVL(TRIM(UPPER(ADDRESS2)), '') || '|'
                   || NVL(UPPER(CITY_NAME), '') || '|' || NVL(UPPER(STATE_ABBREV), '') || '|'
                   || NVL(ZIP_CODE, '') || '|' || NVL(ZIP_SFX, '')` (via s50_ready; was `pkey_src_object`)
  - `HUB_STATE_IND` <- `1` (via s50_ready; was `hub_state_ind`)
  - `HIERARCHY_CODE` <- `'Member'` (via s50_ready; was `hierarchy_code`)
  - `HM_REL_TP_CD` <- `'Member Addr'` (via s50_ready; was `hm_rel_tp_cd`)
  - `PERIOD_REFERENCE_TIME` <- `NULL` (kept verbatim; was `NULL`)
  - `ADDR_LN_1` <- `(ADDRESS1::VARCHAR)` (via s50_ready; was `hold_line1`)
  - `ADDR_LN_2` <- `(ADDRESS1::VARCHAR)` (via s50_ready; was `hold_line2`)
  - `CITY` <- `CITY_NAME::VARCHAR` (via s50_ready; was `a_city`)
  - `PSTL_CD` <- `SUBSTR(TRIM(NVL(ZIP_CODE, '') || IFF(ZIP_SFX IS NOT NULL, '-' || ZIP_SFX, '')), 1, 5)::VARCHAR` (via s50_ready; was `a_zip_cd_5`)
  - `CNTRY_CD` <- `'US'::VARCHAR` (via s50_ready; was `a_country`)
  - `VLDTN_MSG` <- `NULL::VARCHAR` (via s50_ready; was `a_match_code`)
  - `LATTD` <- `0::NUMBER(38, 6)` (via s50_ready; was `a_latitude`)
  - `LNGTD` <- `0::NUMBER(38, 6)` (via s50_ready; was `a_longitude`)
  - `PSTL_BRCD` <- `NULL` (kept verbatim; was `NULL`)
  - `RGN_CD` <- `NULL` (kept verbatim; was `NULL`)
  - `COUNTY` <- `NULL` (via s50_ready; was `a_county_fips`)
  - `LCTN_CRDNT_DESC` <- `NULL` (kept verbatim; was `NULL`)
  - `MLBLTY_SCR` <- `NULL::VARCHAR` (via s50_ready; was `a_mailability_score`)
  - `STATE` <- `(SUBSTR(TRIM(NVL(ZIP_CODE, '') || IFF(ZIP_SFX IS NOT NULL, '-' || ZIP_SFX, '')), 1, 5))::VARCHAR` (via s50_ready; was `a_state_fips`)
  - `RSDNTL_DLVRY_IND` <- `NULL::VARCHAR` (via s50_ready; was `a_residential`)
  - `ORG_DESC` <- `NULL::VARCHAR` (via s50_ready; was `a_org_descriptor`)
  - `ADDR_TP_CD` <- `NULL::VARCHAR` (via s50_ready; was `a_address_type`)
  - `ORG_NM` <- `NULL::VARCHAR` (via s50_ready; was `a_org_name`)
  - `FLR_NUM` <- `NULL` (kept verbatim; was `NULL`)
  - `BLDNG_NM` <- `NULL::VARCHAR` (via s50_ready; was `a_building_name`)
  - `GEOCD_STS_CD` <- `NULL::VARCHAR` (via s50_ready; was `a_geocoding_status`)
  - `SUB_BLDG_NM` <- `NULL::VARCHAR` (via s50_ready; was `a_sub_building_complete`)
  - `SUB_BLDG_DESC` <- `NULL::VARCHAR` (via s50_ready; was `a_sub_building_descriptor`)
  - `BLDG_NMBR` <- `NULL::VARCHAR` (via s50_ready; was `a_building_number`)
  - `SRC_ADDR_LN_1` <- `ADDRESS1` (via s50_ready; was `ADDRESS1`)
  - `SRC_ADDR_LN_2` <- `ADDRESS2` (via s50_ready; was `ADDRESS2`)
  - `SRC_CITY` <- `CITY_NAME` (via s50_ready; was `CITY_NAME`)
  - `SRC_COUNTY` <- `COUNTY_NAME` (via s50_ready; was `COUNTY_NAME`)
  - `SRC_STATE` <- `STATE_ABBREV` (via s50_ready; was `STATE_ABBREV`)
  - `SRC_CNTRY` <- `'US'` (via s50_ready; was `src_cntry`)
  - `SRC_PSTL_CD` <- `ZIP_CODE` (via s50_ready; was `ZIP_CODE`)
  - `SRC_PSTL_CD_EXT` <- `ZIP_SFX` (via s50_ready; was `ZIP_SFX`)
  - `EFF_STRT_DT` <- `LAST_UPDATE_DATE` (via s50_ready; was `LAST_UPDATE_DATE`)
  - `EFF_END_DT` <- `NULL` (kept verbatim; was `NULL`)
  - `PTY_RLE_FK` <- `PTY_RLE_FK` (via s50_ready; was `pty_rle_fk`)
  - `SRC_LAST_UPD_DT` <- `LAST_UPDATE_DATE` (via s50_ready; was `LAST_UPDATE_DATE`)
  - `PSTL_CD_EXT` <- `SUBSTR(TRIM(NVL(ZIP_CODE, '') || IFF(ZIP_SFX IS NOT NULL, '-' || ZIP_SFX, '')), 7, 4)::VARCHAR` (via s50_ready; was `a_zip_cd_4_extn`)

### sp_snow_pub_ECI_ALT_C_S_ECI_PTY_RLE_ALT_ID.sql -> C_S_ECI_PTY_RLE_ALT_ID

- Kept steps: `s10_src`. P_RUN_TS: YES.
- WHERE gate dropped: `WHERE grp_valid AND uq_alt_id`.
- Column map:
  - `PTY_RLE_FK` <- `PTY_REL_FK` (via s40_ready; was `PTY_REL_FK`)
  - `ALT_ID_TP` <- `ALT_ID_TP` (via s40_ready; was `ALT_ID_TP`)
  - `ALT_ID_VAL` <- `ALT_ID_VAL` (via s40_ready; was `ALT_ID_VAL`)
  - `CREATE_DATE` <- `DATE_CREATED` (via s40_ready; was `DATE_CREATED`)
  - `LAST_UPDATE_DATE` <- `:P_RUN_TS` (via s40_ready; was `run_ts`)
  - `PKEY_SRC_OBJECT` <- `PKEY_SRC_OBJECT` (via s40_ready; was `PKEY_SRC_OBJECT`)
  - `SRC_ROWID` <- `TO_VARCHAR(ID) || '|' || ALT_ID_TP` (via s40_ready; was `src_rowid`)
  - `VERSION_SEQ` <- `1` (via s40_ready; was `version_seq`)
  - `STS_CD` <- `'Issued'` (via s40_ready; was `sts_cd`)
  - `HUB_STATE_IND` <- `1` (via s40_ready; was `hub_state_ind`)
  - `SRC_LAST_UPD_DT` <- `NVL(DATE_MODIFIED, DATE_CREATED)` (via s40_ready; was `src_last_upd_dt`)
  - `ALT_ID_TP_FLTR` <- `ALT_ID_TP` (via s40_ready; was `ALT_ID_TP`)
  - `PERIOD_START_DATE` <- `DATE_CREATED` (via s40_ready; was `DATE_CREATED`)

### sp_snow_pub_ECI_PHN_C_S_ECI_PTY_RLE_EADDR.sql -> C_S_ECI_PTY_RLE_EADDR

- Kept steps: `s10_src`. P_RUN_TS: YES.
- WHERE gate dropped: `WHERE grp_email_good AND uq_eaddr`.
- Columns set to NULL (no first-step source): PERIOD_REFERENCE_TIME (kept verbatim), ELEC_ADDR (via s50_ready), USG_TP (kept verbatim).
- Column map:
  - `PKEY_SRC_OBJECT` <- `PKEY_SRC_OBJECT` (via s50_ready; was `pkey_src_object`)
  - `PERIOD_START_DATE` <- `PERIOD_START_DATE` (via s50_ready; was `PERIOD_START_DATE`)
  - `PERIOD_REFERENCE_TIME` <- `NULL` (kept verbatim; was `NULL`)
  - `LAST_UPDATE_DATE` <- `:P_RUN_TS` (via s50_ready; was `run_ts`)
  - `CREATE_DATE` <- `:P_RUN_TS` (via s50_ready; was `run_ts`)
  - `SRC_ROWID` <- `PKEY_SRC_OBJECT` (via s50_ready; was `pkey_src_object`)
  - `PTY_RLE_FK` <- `PTY_RLE_FK` (via s50_ready; was `pty_rle_fk`)
  - `ELEC_ADDR` <- `NULL` (via s50_ready; was `std_email`)
  - `USG_TP` <- `NULL` (kept verbatim; was `NULL`)
  - `ADDR_TP` <- `'001'` (via s50_ready; was `eaddr_addr_tp`)
  - `STS_CD` <- `'Active'` (via s50_ready; was `eaddr_sts_cd`)
  - `IS_VLD` <- `'Y'` (via s50_ready; was `eaddr_is_vld`)
  - `SRC_LAST_UPD_DT` <- `PERIOD_START_DATE` (via s50_ready; was `PERIOD_START_DATE`)
  - `VERSION_SEQ` <- `'1'` (via s50_ready; was `version_seq`)
  - `HUB_STATE_IND` <- `1` (via s50_ready; was `hub_state_ind`)

### sp_snow_pub_ECI_PHN_C_S_ECI_PTY_RLE_PHN.sql -> C_S_ECI_PTY_RLE_PHN

- Kept steps: `s10_src`. P_RUN_TS: YES.
- WHERE gate dropped: `WHERE grp_phone_good AND uq_phn`.
- Column map:
  - `PKEY_SRC_OBJECT` <- `PKEY_SRC_OBJECT` (via s50_ready; was `pkey_src_object`)
  - `PERIOD_START_DATE` <- `PERIOD_START_DATE` (via s50_ready; was `PERIOD_START_DATE`)
  - `VERSION_SEQ` <- `'1'` (via s50_ready; was `version_seq`)
  - `LAST_UPDATE_DATE` <- `:P_RUN_TS` (via s50_ready; was `run_ts`)
  - `CREATE_DATE` <- `:P_RUN_TS` (via s50_ready; was `run_ts`)
  - `SRC_ROWID` <- `SRC_ROWID` (via s50_ready; was `src_rowid`)
  - `PTY_RLE_FK` <- `PTY_RLE_FK` (via s50_ready; was `pty_rle_fk`)
  - `PHN_TP` <- `PHONE_TP` (via s50_ready; was `PHONE_TP`)
  - `USG_TP` <- `USG_TP` (via s50_ready; was `USG_TP`)
  - `PHN_NUM` <- `(IFF(LENGTH(PHONE_EMAIL) = 7, '000' || PHONE_EMAIL, PHONE_EMAIL))` (via s50_ready; was `std_phone`)
  - `PREF_LVL` <- `PREF_LVL` (via s50_ready; was `PREF_LVL`)
  - `SRC_LAST_UPD_DT` <- `PERIOD_START_DATE` (via s50_ready; was `PERIOD_START_DATE`)
  - `PHN_NUM_EXT` <- `WORK_EXT` (via s50_ready; was `WORK_EXT`)
  - `HUB_STATE_IND` <- `1` (via s50_ready; was `hub_state_ind`)

### sp_snow_pub_ECI_PTY_C_S_ECI_PTY.sql -> C_S_ECI_PTY

- Kept steps: `s10_src`. P_RUN_TS: YES.
- WHERE gate dropped: `WHERE uq_pty`.
- Columns set to NULL (no first-step source): ETHNCTY (column MSTR_CODE_VALUE not produced by lkp_cv), PRFRD_LANG_CD (column MSTR_CODE_VALUE not produced by lkp_cv).
- Column map:
  - `PKEY_SRC_OBJECT` <- `TRIM(PKEY_SRC_OBJECT)` (via s50_ready; was `pkey_trim`)
  - `VERSION_SEQ` <- `1` (via s50_ready; was `version_seq`)
  - `LAST_UPDATE_DATE` <- `:P_RUN_TS` (via s50_ready; was `run_ts`)
  - `UPDATED_BY` <- `MODIFIED_BY` (via s50_ready; was `MODIFIED_BY`)
  - `CREATE_DATE` <- `DATE_CREATED` (via s50_ready; was `DATE_CREATED`)
  - `CREATOR` <- `CREATED_BY` (via s50_ready; was `CREATED_BY`)
  - `SRC_ROWID` <- `TRIM(PKEY_SRC_OBJECT)` (via s50_ready; was `pkey_trim`)
  - `PTY_BO_CLASS_CD` <- `'Indv'` (via s50_ready; was `pty_bo_class_cd`)
  - `PRFX_NM` <- `NULL::VARCHAR` (via s50_ready; was `std_prfx_name`)
  - `FULL_NM` <- `TRIM(NVL(((INITCAP(FIRST_NAME, ' '))), '')
                            || (' ' || TRIM(((INITCAP(MIDDLE_INITIAL, ' ')))))
                            || ' '
                            || NVL(LTRIM(((INITCAP(LAST_NAME, ' ')))), ''))::VARCHAR` (via s50_ready; was `std_full_name`)
  - `LST_NM` <- `((INITCAP(LAST_NAME, ' ')))::VARCHAR` (via s50_ready; was `std_lst_name`)
  - `MDL_NM` <- `((INITCAP(MIDDLE_INITIAL, ' ')))::VARCHAR` (via s50_ready; was `std_mdl_name`)
  - `FRST_NM` <- `((INITCAP(FIRST_NAME, ' ')))::VARCHAR` (via s50_ready; was `std_first_name`)
  - `GNDR_CD` <- `CASE WHEN PARTY_TYPE IN ('I', 'Indv', 'INDV', 'HCP') AND LEFT(GENDER, 1) IN ('B', 'U') THEN NULL
                 WHEN PARTY_TYPE IN ('I', 'Indv', 'INDV', 'HCP') AND LEFT(GENDER, 1) = 'M' THEN '1'
                 WHEN PARTY_TYPE IN ('I', 'Indv', 'INDV', 'HCP') AND LEFT(GENDER, 1) = 'F' THEN '2'
                 ELSE NULL END::VARCHAR` (via s50_ready; was `mdm_gender_code`)
  - `BIRTH_DT` <- `IFF(DOB IS NULL, DOB, NULL)` (via s50_ready; was `std_birth_date`)
  - `SRC_FULL_NM` <- `NVL(SRC_FULL_NAME, NVL(TRIM(FIRST_NAME), '') || ' ' || NVL(TRIM(LAST_NAME), ''))::VARCHAR` (via s50_ready; was `std_src_full_name`)
  - `SRC_LAST_UPD_DT` <- `DATE_MODIFIED` (via s50_ready; was `DATE_MODIFIED`)
  - `BIRTH_WGHT_GRMS` <- `BIRTH_WT_LB * 453.6 + BIRTH_WT_OZ * 28.35` (via s50_ready; was `birth_wght_grms`)
  - `HUB_STATE_IND` <- `1` (via s50_ready; was `hub_state_ind`)
  - `SRC_ETHNCTY` <- `ETHNICITY` (via s50_ready; was `ETHNICITY`)
  - `ETHNCTY` <- `NULL` (column MSTR_CODE_VALUE not produced by lkp_cv; was `ethnicity_mstr`)
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
                 ELSE NULL END::VARCHAR` (via s50_ready; was `mdm_race_cd`)
  - `PRFRD_LANG_CD` <- `NULL` (column MSTR_CODE_VALUE not produced by lkp_cv; was `language_mstr`)
  - `SRC_PRFRD_LANG_CD` <- `LANGUAGE_CD` (via s50_ready; was `LANGUAGE_CD`)
  - `SRC_RACE_CD` <- `'WH' || NVL(TO_VARCHAR(RACE_WHITE), '') || 'AA' || NVL(TO_VARCHAR(RACE_AA), '')
            || 'AS' || NVL(TO_VARCHAR(RACE_ASIAN), '') || 'PI' || NVL(TO_VARCHAR(RACE_PI), '')
            || 'NA' || NVL(TO_VARCHAR(RACE_AN), '')::VARCHAR` (via s50_ready; was `src_race_ind_list`)
  - `PERIOD_START_DATE` <- `DATE_MODIFIED` (via s50_ready; was `DATE_MODIFIED`)

### sp_snow_pub_ECI_PTY_C_S_ECI_PTY_RLE.sql -> C_S_ECI_PTY_RLE

- Kept steps: `s10_src`. P_RUN_TS: YES.
- WHERE gate dropped: `WHERE uq_rle`.
- Column map:
  - `PKEY_SRC_OBJECT` <- `TRIM(PKEY_SRC_OBJECT) || '|' || 'Member'` (via s50_ready; was `rle_pkey`)
  - `LAST_UPDATE_DATE` <- `:P_RUN_TS` (via s50_ready; was `run_ts`)
  - `CREATOR` <- `CREATED_BY` (via s50_ready; was `CREATED_BY`)
  - `CREATE_DATE` <- `DATE_CREATED` (via s50_ready; was `DATE_CREATED`)
  - `VERSION_SEQ` <- `1` (via s50_ready; was `version_seq`)
  - `PTY_FK` <- `TRIM(PKEY_SRC_OBJECT)` (via s50_ready; was `pkey_trim`)
  - `SRC_LAST_UPD_DT` <- `DATE_MODIFIED` (via s50_ready; was `DATE_MODIFIED`)
  - `RLE_BO_CLASS_CD` <- `'Member'` (via s50_ready; was `rle_bo_class_cd`)
  - `PERIOD_START_DATE` <- `DATE_CREATED` (via s50_ready; was `DATE_CREATED`)
  - `HUB_STATE_IND` <- `1` (via s50_ready; was `hub_state_ind`)
  - `SRC_ROWID` <- `TRIM(PKEY_SRC_OBJECT) || '|' || 'Member'` (via s50_ready; was `rle_pkey`)

### sp_snow_pub_ECI_REL_C_S_ECI_PTY_RLE_REL.sql -> C_S_ECI_PTY_RLE_REL

- Kept steps: `s10_src`. P_RUN_TS: YES.
- WHERE gate dropped: `WHERE mstr_ref_code IS NOT NULL AND uq_rel`.
- Columns set to NULL (no first-step source): PKEY_SRC_OBJECT (via s40_ready), SRC_ROWID (via s40_ready), REL_TP (via s40_ready).
- Column map:
  - `PTY_RLE_FK_1` <- `IFF(RELATION_DIRECTION = 'To Child', (LPAD(TO_VARCHAR(ID_FAMILY), 10, '0') || 'F'), (LPAD(TO_VARCHAR(ID_CHILD), 10, '0'))) || '|Member'` (via s40_ready; was `rel_fk_1`)
  - `PTY_RLE_FK_2` <- `IFF(RELATION_DIRECTION = 'To Child', (LPAD(TO_VARCHAR(ID_CHILD), 10, '0')), (LPAD(TO_VARCHAR(ID_FAMILY), 10, '0') || 'F')) || '|Member'` (via s40_ready; was `rel_fk_2`)
  - `PKEY_SRC_OBJECT` <- `NULL` (via s40_ready; was `rel_src_key`)
  - `VERSION_SEQ` <- `1` (via s40_ready; was `version_seq`)
  - `SRC_ROWID` <- `NULL` (via s40_ready; was `rel_src_key`)
  - `HUB_STATE_IND` <- `1` (via s40_ready; was `hub_state_ind`)
  - `REL_TYPE_CODE` <- `'Member Relationship'` (via s40_ready; was `rel_type_code`)
  - `HIERARCHY_CODE` <- `'Member'` (via s40_ready; was `hierarchy_code`)
  - `REL_TP` <- `NULL` (via s40_ready; was `mstr_ref_code`)
  - `SRC_LAST_UPD_DT` <- `DATE_MODIFIED` (via s40_ready; was `DATE_MODIFIED`)
  - `LAST_UPDATE_DATE` <- `:P_RUN_TS` (via s40_ready; was `run_ts`)
  - `UPDATED_BY` <- `'m_Tgt_C_S_ECI_Pty_Rle_Rel'` (via s40_ready; was `mapping_name`)
  - `CREATE_DATE` <- `DATE_MODIFIED` (via s40_ready; was `DATE_MODIFIED`)
  - `CREATOR` <- `'m_Tgt_C_S_ECI_Pty_Rle_Rel'` (via s40_ready; was `mapping_name`)
  - `PERIOD_START_DATE` <- `DATE_CREATED` (via s40_ready; was `DATE_CREATED`)

## Dropped (not C_S_* targets)

- sp_snow_pub_ECI_ADR_DQM_ADDRESS.sql -> DQM_ADDRESS
- sp_snow_pub_ECI_ADR_EXC_STG_BAD_REC_MEMB.sql -> EXC_STG_BAD_REC_MEMB
- sp_snow_pub_ECI_ALT_EXC_STG_BAD_REC_MEMB_MEDICAID.sql -> EXC_STG_BAD_REC_MEMB
- sp_snow_pub_ECI_ALT_EXC_STG_BAD_REC_MEMB_SSN.sql -> EXC_STG_BAD_REC_MEMB
- sp_snow_pub_ECI_PHN_EXC_STG_BAD_REC_MEMB_EMAIL.sql -> EXC_STG_BAD_REC_MEMB
- sp_snow_pub_ECI_PHN_EXC_STG_BAD_REC_MEMB_PHONE.sql -> EXC_STG_BAD_REC_MEMB
- sp_snow_pub_ECI_PTY_EXC_STG_BAD_REC_MEMB_BIRTH.sql -> EXC_STG_BAD_REC_MEMB
- sp_snow_pub_ECI_PTY_EXC_STG_BAD_REC_MEMB_ETHNICITY.sql -> EXC_STG_BAD_REC_MEMB
- sp_snow_pub_ECI_PTY_EXC_STG_BAD_REC_MEMB_GENDER.sql -> EXC_STG_BAD_REC_MEMB
- sp_snow_pub_ECI_PTY_EXC_STG_BAD_REC_MEMB_LANGUAGE.sql -> EXC_STG_BAD_REC_MEMB
- sp_snow_pub_ECI_PTY_EXC_STG_BAD_REC_MEMB_RACE.sql -> EXC_STG_BAD_REC_MEMB
- sp_snow_pub_ECI_REL_EXC_STG_BAD_REC_MEMB.sql -> EXC_STG_BAD_REC_MEMB
- sp_snow_pub_ECI_RFA_STG_ECI_D_FAMILY_ADDRESS.sql -> STG_ECI_D_FAMILY_ADDRESS
- sp_snow_pub_ECI_RFM_STG_ECI_D_MEDICAID.sql -> STG_ECI_D_MEDICAID
- sp_snow_pub_ECI_RFP_STG_ECI_D_FAMILY_PHONE.sql -> STG_ECI_D_FAMILY_PHONE
- sp_snow_pub_ECI_VAL_EXC_STG_BAD_REC_MEMB.sql -> EXC_STG_BAD_REC_MEMB
- sp_snow_pub_ECI_VAL_STG_ECI_PTY_INACTIVE_LOG_DEACTIVATION.sql -> STG_ECI_PTY_INACTIVE_LOG
- sp_snow_pub_ECI_VAL_STG_ECI_PTY_INACTIVE_LOG_REACTIVATION.sql -> STG_ECI_PTY_INACTIVE_LOG
- sp_snow_pub_ECI_VAL_STG_ECI_PTY_INACTIVE_STS.sql -> STG_ECI_PTY_INACTIVE_STS

