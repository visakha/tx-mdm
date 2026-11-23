# TTF publish_dest S10-only map

S10-only twins: ONLY the first (source) step is inlined as a CTE;
later steps and the WHERE gate are dropped. Each target column is
aliased from a first-step column, a literal, or a parameter. A
column the first step does not carry is NULL (recorded below).

Built: 4 twins. Dropped (not C_S_* targets): 9. Failed: 0.

## Twins

### sp_snow_pub_TTF_ALT_C_S_TTF_PTY_RLE_ALT_ID.sql -> C_S_TTF_PTY_RLE_ALT_ID

- Kept steps: `s1_keys`. P_RUN_TS: YES.
- WHERE gate dropped: `none`.
- Column map:
  - `PKEY_SRC_OBJECT` <- `PKEY_SRC_OBJECT` (via s2_dedup; was `k.pkey_src_object`)
  - `HUB_STATE_IND` <- `1` (kept verbatim; was `1`)
  - `SRC_ROWID` <- `PKEY_SRC_OBJECT` (via s2_dedup; was `k.pkey_src_object`)
  - `LAST_UPDATE_DATE` <- `:P_RUN_TS` (kept verbatim; was `:P_RUN_TS`)
  - `VERSION_SEQ` <- `1` (kept verbatim; was `1 /* TIMELINE: VERSION_SEQ */`)
  - `CREATE_DATE` <- `SUBMITDATE` (via s2_dedup; was `k.SUBMITDATE`)
  - `PTY_RLE_FK` <- `NVL(PTY_SRC_KEY, '') || '|Member'` (expression kept; was `NVL(k.PTY_SRC_KEY, '') || '|Member'`)
  - `ALT_ID_TP` <- `'024'` (kept verbatim; was `'024'`)
  - `ALT_ID_VAL` <- `PTY_SRC_KEY` (via s2_dedup; was `k.PTY_SRC_KEY`)
  - `ALT_ID_TP_FLTR` <- `'024'` (kept verbatim; was `'024'`)
  - `STS_CD` <- `'Issued'` (kept verbatim; was `'Issued'`)
  - `PERIOD_START_DATE` <- `:P_RUN_TS` (kept verbatim; was `:P_RUN_TS /* TIMELINE: $sys.MappingRunStartTime */`)
  - `SRC_LAST_UPD_DT` <- `SUBMITDATE` (via s2_dedup; was `k.SUBMITDATE`)

### sp_snow_pub_TTF_PHN_C_S_TTF_PTY_RLE_PHN.sql -> C_S_TTF_PTY_RLE_PHN

- Kept steps: `s1_src`. P_RUN_TS: YES.
- WHERE gate dropped: `WHERE phone_exception_code IS NULL AND uq_phn`.
- Column map:
  - `PKEY_SRC_OBJECT` <- `PHN_PKEY` (via s3_routed; was `phn_pkey`)
  - `PERIOD_START_DATE` <- `SUBMITDATE` (via s3_routed; was `SUBMITDATE`)
  - `VERSION_SEQ` <- `'1'` (via s3_routed; was `version_seq`)
  - `LAST_UPDATE_DATE` <- `:P_RUN_TS` (via s3_routed; was `run_ts`)
  - `SRC_ROWID` <- `PHN_PKEY` (via s3_routed; was `phn_pkey`)
  - `HUB_STATE_IND` <- `1` (via s3_routed; was `hub_state_ind`)
  - `PTY_RLE_FK` <- `NVL(PTY_SRC_KEY, '') || '|Member'` (via s3_routed; was `pty_rle_fk`)
  - `PHN_TP` <- `'Telephone'` (via s3_routed; was `phn_tp`)
  - `USG_TP` <- `'001'` (via s3_routed; was `usg_tp`)
  - `PHN_NUM` <- `STD_PHONE` (via s3_routed; was `std_phone`)
  - `PREF_LVL` <- `'Primary'` (via s3_routed; was `pref_lvl`)
  - `SRC_LAST_UPD_DT` <- `SUBMITDATE` (via s3_routed; was `SUBMITDATE`)

### sp_snow_pub_TTF_PTY_C_S_TTF_PTY.sql -> C_S_TTF_PTY

- Kept steps: `s1_active`. P_RUN_TS: YES.
- WHERE gate dropped: `WHERE uq_pty`.
- Columns set to NULL (no first-step source): ETHNCTY (column MSTR_CODE_VALUE not produced by lkp_cv), RACE_CD (column MSTR_CODE_VALUE not produced by lkp_cv), PRFRD_LANG_CD (kept verbatim), SFX_NM (kept verbatim).
- Column map:
  - `PKEY_SRC_OBJECT` <- `TRIM(PTY_SRC_KEY)` (via s4_routed; was `pkey_trim`)
  - `VERSION_SEQ` <- `1` (via s4_routed; was `version_seq`)
  - `LAST_UPDATE_DATE` <- `:P_RUN_TS` (via s4_routed; was `run_ts`)
  - `CREATE_DATE` <- `SUBMITDATE` (via s4_routed; was `SUBMITDATE`)
  - `SRC_ROWID` <- `TRIM(PTY_SRC_KEY)` (via s4_routed; was `pkey_trim`)
  - `HUB_STATE_IND` <- `1` (via s4_routed; was `hub_state_ind`)
  - `PTY_BO_CLASS_CD` <- `'Indv'` (via s4_routed; was `pty_bo_class_cd`)
  - `PRFX_NM` <- `NULL::VARCHAR` (via s4_routed; was `std_prfx_name`)
  - `FRST_NM` <- `((INITCAP(FIRSTNAME, ' ')))::VARCHAR` (via s4_routed; was `std_first_name`)
  - `MDL_NM` <- `((INITCAP(MIDDLENAME, ' ')))::VARCHAR` (via s4_routed; was `std_mdl_name`)
  - `LST_NM` <- `((INITCAP(LASTNAME, ' ')))::VARCHAR` (via s4_routed; was `std_lst_name`)
  - `FULL_NM` <- `TRIM(NVL(((INITCAP(FIRSTNAME, ' '))), '')
                            || (' ' || TRIM(((INITCAP(MIDDLENAME, ' ')))))
                            || ' '
                            || NVL(LTRIM(((INITCAP(LASTNAME, ' ')))), ''))::VARCHAR` (via s4_routed; was `std_full_name`)
  - `GNDR_CD` <- `CASE WHEN 'Indv' IN ('I', 'Indv', 'INDV', 'HCP') AND LEFT(GENDER, 1) IN ('B', 'U') THEN NULL
                 WHEN 'Indv' IN ('I', 'Indv', 'INDV', 'HCP') AND LEFT(GENDER, 1) = 'M' THEN '1'
                 WHEN 'Indv' IN ('I', 'Indv', 'INDV', 'HCP') AND LEFT(GENDER, 1) = 'F' THEN '2'
                 ELSE NULL END::VARCHAR` (via s4_routed; was `mdm_gender_code`)
  - `SRC_FULL_NM` <- `NVL(TRIM(NVL(FIRSTNAME, '') || IFF(MIDDLENAME IS NOT NULL, ' ' || TRIM(MIDDLENAME), '')
                        || ' ' || NVL(LTRIM(LASTNAME), '')), NVL(TRIM(FIRSTNAME), '') || ' ' || NVL(TRIM(LASTNAME), ''))::VARCHAR` (via s4_routed; was `std_src_full_name`)
  - `ETHNCTY` <- `NULL` (column MSTR_CODE_VALUE not produced by lkp_cv; was `ethnicity_mstr`)
  - `SRC_ETHNCTY` <- `ETHNICITY` (via s4_routed; was `ethnicity`)
  - `RACE_CD` <- `NULL` (column MSTR_CODE_VALUE not produced by lkp_cv; was `race_mstr`)
  - `SRC_RACE_CD` <- `RACEETHNICITYID` (via s4_routed; was `RACEETHNICITYID`)
  - `SRC_LAST_UPD_DT` <- `SUBMITDATE` (via s4_routed; was `SUBMITDATE`)
  - `PRFRD_LANG_CD` <- `NULL` (kept verbatim; was `NULL`)
  - `SFX_NM` <- `NULL` (kept verbatim; was `NULL`)
  - `PERIOD_START_DATE` <- `:P_RUN_TS` (via s4_routed; was `run_ts`)
  - `BIRTH_DT` <- `IFF(DOB IS NULL, DOB, NULL)` (via s4_routed; was `std_birth_date`)

### sp_snow_pub_TTF_PTY_C_S_TTF_PTY_RLE.sql -> C_S_TTF_PTY_RLE

- Kept steps: `s1_active`. P_RUN_TS: YES.
- WHERE gate dropped: `WHERE uq_rle`.
- Column map:
  - `PKEY_SRC_OBJECT` <- `TRIM(PTY_SRC_KEY) || '|' || 'Member'` (via s4_routed; was `rle_pkey`)
  - `PERIOD_START_DATE` <- `SUBMITDATE` (via s4_routed; was `SUBMITDATE`)
  - `VERSION_SEQ` <- `1` (via s4_routed; was `version_seq`)
  - `LAST_UPDATE_DATE` <- `:P_RUN_TS` (via s4_routed; was `run_ts`)
  - `CREATE_DATE` <- `SUBMITDATE` (via s4_routed; was `SUBMITDATE`)
  - `SRC_ROWID` <- `TRIM(PTY_SRC_KEY) || '|' || 'Member'` (via s4_routed; was `rle_pkey`)
  - `HUB_STATE_IND` <- `1` (via s4_routed; was `hub_state_ind`)
  - `PTY_FK` <- `TRIM(PTY_SRC_KEY)` (via s4_routed; was `pkey_trim`)
  - `RLE_BO_CLASS_CD` <- `'Member'` (via s4_routed; was `rle_bo_class_cd`)
  - `SRC_LAST_UPD_DT` <- `SUBMITDATE` (via s4_routed; was `SUBMITDATE`)

## Dropped (not C_S_* targets)

- sp_snow_pub_TTF_PHN_EXC_STG_BAD_REC_MEMB.sql -> EXC_STG_BAD_REC_MEMB
- sp_snow_pub_TTF_PTY_EXC_STG_BAD_REC_MEMB_BIRTH.sql -> EXC_STG_BAD_REC_MEMB
- sp_snow_pub_TTF_PTY_EXC_STG_BAD_REC_MEMB_ETHNICITY.sql -> EXC_STG_BAD_REC_MEMB
- sp_snow_pub_TTF_PTY_EXC_STG_BAD_REC_MEMB_GENDER.sql -> EXC_STG_BAD_REC_MEMB
- sp_snow_pub_TTF_PTY_EXC_STG_BAD_REC_MEMB_RACE.sql -> EXC_STG_BAD_REC_MEMB
- sp_snow_pub_TTF_VAL_EXC_STG_BAD_REC_MEMB.sql -> EXC_STG_BAD_REC_MEMB
- sp_snow_pub_TTF_VAL_STG_TTF_PTY_INACTIVE_LOG_DEACTIVATION.sql -> STG_TTF_PTY_INACTIVE_LOG
- sp_snow_pub_TTF_VAL_STG_TTF_PTY_INACTIVE_LOG_REACTIVATION.sql -> STG_TTF_PTY_INACTIVE_LOG
- sp_snow_pub_TTF_VAL_STG_TTF_PTY_INACTIVE_STS.sql -> STG_TTF_PTY_INACTIVE_STS

