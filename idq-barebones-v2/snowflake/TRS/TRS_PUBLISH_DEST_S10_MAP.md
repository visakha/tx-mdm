# TRS publish_dest S10-only map

S10-only twins: ONLY the first (source) step is inlined as a CTE;
later steps and the WHERE gate are dropped. Each target column is
aliased from a first-step column, a literal, or a parameter. A
column the first step does not carry is NULL (recorded below).

Built: 14 twins. Dropped (not C_S_* targets): 24. Failed: 0.

## Twins

### sp_snow_pub_TRS_ADDR2_C_S_TRS_PTY_RLE_ADDR.sql -> C_S_TRS_PTY_RLE_ADDR

- Kept steps: `s10_dedup`. P_RUN_TS: YES.
- WHERE gate dropped: `WHERE score = '100' AND uq_addr`.
- Columns set to NULL (no first-step source): PKEY_SRC_OBJECT (via s50_ready), ROWID_OBJECT (kept verbatim), DELETED_IND (kept verbatim), DELETED_DATE (kept verbatim), DELETED_BY (kept verbatim), UPDATED_BY (kept verbatim), SRC_ROWID (via s50_ready), HUB_STATE_IND (kept verbatim), ADDR_TP (via s50_ready), PTY_RLE_FK (via s50_ready), USG_TP (kept verbatim), ADDR_LN_1 (via s50_ready), ADDR_LN_2 (via s50_ready), CITY (via s50_ready), PSTL_CD (via s50_ready), PSTL_CD_EXT (via s50_ready), CNTRY_CD (via s50_ready), CRDNT_SYS (kept verbatim), LATTD (via s50_ready), LNGTD (via s50_ready), PSTL_BRCD (kept verbatim), FLR_NUM (via s50_ready), BLDNG_NM (via s50_ready), COUNTY (via s50_ready), STATE (via s50_ready), LCTN_CRDNT_DESC (kept verbatim), VLDTN_MSG (via s50_ready), RGN_CD (kept verbatim), MLBLTY_SCR (via s50_ready), ADDR_TP_CD (via s50_ready), ORG_DESC (via s50_ready), ORG_NM (via s50_ready), GEOCD_STS_CD (via s50_ready), SUB_BLDG_NM (via s50_ready), BLDG_NMBR (via s50_ready), SUB_BLDG_DESC (via s50_ready), RSDNTL_DLVRY_IND (via s50_ready), SRC_ADDR_LN_1 (via s50_ready), SRC_ADDR_LN_2 (via s50_ready), SRC_CITY (via s50_ready), SRC_COUNTY (via s50_ready), SRC_STATE (via s50_ready), SRC_CNTRY (via s50_ready), SRC_PSTL_CD (via s50_ready), SRC_PSTL_CD_EXT (via s50_ready), CREATOR (kept verbatim), CREATE_DATE (kept verbatim).
- Column map:
  - `PKEY_SRC_OBJECT` <- `NULL` (via s50_ready; was `pkey_pty_rle_addr`)
  - `PERIOD_START_DATE` <- `EFF_BEGIN_DT` (via s50_ready; was `EFF_BEGIN_DT`)
  - `VERSION_SEQ` <- `'1'` (via s50_ready; VERSION_SEQ computed downstream; literal 1; was `version_seq`)
  - `PERIOD_REFERENCE_TIME` <- `IFF(EFF_END_DT IS NOT NULL, :P_RUN_TS, NULL)` (via s50_ready; was `period_reference_time`)
  - `HIERARCHY_CODE` <- `'Member'` (via s50_ready; was `hierarchy_code`)
  - `HM_REL_TP_CD` <- `'Member Addr'` (via s50_ready; was `hm_rel_tp_cd`)
  - `LAST_UPDATE_DATE` <- `:P_RUN_TS` (via s50_ready; was `run_ts`)
  - `ROWID_OBJECT` <- `NULL` (kept verbatim; was `NULL`)
  - `DELETED_IND` <- `NULL` (kept verbatim; was `NULL`)
  - `DELETED_DATE` <- `NULL` (kept verbatim; was `NULL`)
  - `DELETED_BY` <- `NULL` (kept verbatim; was `NULL`)
  - `UPDATED_BY` <- `NULL` (kept verbatim; was `NULL`)
  - `SRC_ROWID` <- `NULL` (via s50_ready; was `src_rowid`)
  - `HUB_STATE_IND` <- `NULL` (kept verbatim; was `NULL`)
  - `PREF_LVL` <- `'       '` (via s50_ready; was `pref_lvl`)
  - `LOC_IDN` <- `NVL(TO_VARCHAR(TRUNC(CASE_NUM)), '') || ' ' || NVL(TO_VARCHAR(TRUNC(EDG_NUM)), '')` (via s50_ready; was `loc_idn`)
  - `ADDR_TP` <- `NULL` (via s50_ready; was `mstr_addr_tp`)
  - `PTY_RLE_FK` <- `NULL` (via s50_ready; was `pty_rle_fk`)
  - `USG_TP` <- `NULL` (kept verbatim; was `NULL`)
  - `ADDR_LN_1` <- `NULL` (via s50_ready; was `hold_line1`)
  - `ADDR_LN_2` <- `NULL` (via s50_ready; was `hold_line2`)
  - `CITY` <- `NULL` (via s50_ready; was `CITY`)
  - `PSTL_CD` <- `NULL` (via s50_ready; was `PSTL_CD`)
  - `PSTL_CD_EXT` <- `NULL` (via s50_ready; was `PSTL_CD_EXT`)
  - `CNTRY_CD` <- `NULL` (via s50_ready; was `CNTRY_CD`)
  - `CRDNT_SYS` <- `NULL` (kept verbatim; was `NULL`)
  - `LATTD` <- `NULL` (via s50_ready; was `LATTD`)
  - `LNGTD` <- `NULL` (via s50_ready; was `LNGTD`)
  - `PSTL_BRCD` <- `NULL` (kept verbatim; was `NULL`)
  - `FLR_NUM` <- `NULL` (via s50_ready; was `FLR_NUM`)
  - `BLDNG_NM` <- `NULL` (via s50_ready; was `BLDNG_NM`)
  - `COUNTY` <- `NULL` (via s50_ready; was `COUNTY`)
  - `STATE` <- `NULL` (via s50_ready; was `STATE`)
  - `LCTN_CRDNT_DESC` <- `NULL` (kept verbatim; was `NULL`)
  - `VLDTN_MSG` <- `NULL` (via s50_ready; was `VLDTN_MSG`)
  - `RGN_CD` <- `NULL` (kept verbatim; was `NULL`)
  - `MLBLTY_SCR` <- `NULL` (via s50_ready; was `MLBLTY_SCR`)
  - `ADDR_TP_CD` <- `NULL` (via s50_ready; was `ADDR_TP_CD`)
  - `ORG_DESC` <- `NULL` (via s50_ready; was `ORG_DESC`)
  - `ORG_NM` <- `NULL` (via s50_ready; was `ORG_NM`)
  - `GEOCD_STS_CD` <- `NULL` (via s50_ready; was `GEOCD_STS_CD`)
  - `SUB_BLDG_NM` <- `NULL` (via s50_ready; was `SUB_BLDG_NM`)
  - `BLDG_NMBR` <- `NULL` (via s50_ready; was `BLDG_NMBR`)
  - `SUB_BLDG_DESC` <- `NULL` (via s50_ready; was `SUB_BLDG_DESC`)
  - `RSDNTL_DLVRY_IND` <- `NULL` (via s50_ready; was `RSDNTL_DLVRY_IND`)
  - `SRC_ADDR_LN_1` <- `NULL` (via s50_ready; was `SRC_ADDR_LN_1`)
  - `SRC_ADDR_LN_2` <- `NULL` (via s50_ready; was `SRC_ADDR_LN_2`)
  - `SRC_CITY` <- `NULL` (via s50_ready; was `SRC_CITY`)
  - `SRC_COUNTY` <- `NULL` (via s50_ready; was `SRC_COUNTY`)
  - `SRC_STATE` <- `NULL` (via s50_ready; was `SRC_STATE`)
  - `SRC_CNTRY` <- `NULL` (via s50_ready; was `SRC_CNTRY`)
  - `SRC_PSTL_CD` <- `NULL` (via s50_ready; was `SRC_PSTL_CD`)
  - `SRC_PSTL_CD_EXT` <- `NULL` (via s50_ready; was `SRC_PSTL_CD_EXT`)
  - `SRC_LAST_UPD_DT` <- `CREATE_DT` (via s50_ready; was `CREATE_DT`)
  - `CREATOR` <- `NULL` (kept verbatim; was `NULL`)
  - `CREATE_DATE` <- `NULL` (kept verbatim; was `NULL`)
  - `EFF_STRT_DT` <- `EFF_BEGIN_DT` (via s50_ready; was `EFF_BEGIN_DT`)
  - `PERIOD_END_DATE` <- `EFF_END_DT` (via s50_ready; was `end_date_50y`)
  - `EFF_END_DT` <- `EFF_END_DT` (via s50_ready; was `end_date_50y`)

### sp_snow_pub_TRS_ALT_C_S_TRS_PTY_RLE_ALT_ID.sql -> C_S_TRS_PTY_RLE_ALT_ID

- Kept steps: `s1_src`. P_RUN_TS: YES.
- WHERE gate dropped: `WHERE is_valid AND uq_alt_id`.
- Columns set to NULL (no first-step source): PKEY_SRC_OBJECT (via s4_routed), SRC_ROWID (via s4_routed), PERIOD_START_DATE (via s4_routed), ALT_ID_TP (via s4_routed), ALT_ID_VAL (via s4_routed), ALT_ID_TP_FLTR (via s4_routed), CV_IND (via s4_routed), PTY_RLE_FK (via s4_routed), ROWID_OBJECT (kept verbatim), DELETED_IND (kept verbatim), DELETED_DATE (kept verbatim), DELETED_BY (kept verbatim), PERIOD_END_DATE (kept verbatim), PERIOD_REFERENCE_TIME (kept verbatim), TIMELINE_ACTION (kept verbatim), UPDATED_BY (kept verbatim), CREATE_DATE (via s4_routed), CREATOR (kept verbatim), HUB_STATE_IND (kept verbatim), SRC_LAST_UPD_DT (via s4_routed).
- Column map:
  - `PKEY_SRC_OBJECT` <- `NULL` (via s4_routed; was `pkey_src_object_alt_id`)
  - `SRC_ROWID` <- `NULL` (via s4_routed; was `pkey_src_object_alt_id`)
  - `PERIOD_START_DATE` <- `NULL` (via s4_routed; was `period_start_date`)
  - `VERSION_SEQ` <- `1` (via s4_routed; was `version_seq`)
  - `LAST_UPDATE_DATE` <- `:P_RUN_TS` (kept verbatim; was `:P_RUN_TS`)
  - `ALT_ID_TP` <- `NULL` (via s4_routed; was `alt_id_typ`)
  - `ALT_ID_VAL` <- `NULL` (via s4_routed; was `alt_id_val`)
  - `STS_CD` <- `'      '` (via s4_routed; was `sts_cd`)
  - `ALT_ID_TP_FLTR` <- `NULL` (via s4_routed; was `alt_id_typ`)
  - `CV_IND` <- `NULL` (via s4_routed; was `cv_ind`)
  - `PTY_RLE_FK` <- `NULL` (via s4_routed; was `pty_rle_fk`)
  - `ROWID_OBJECT` <- `NULL` (kept verbatim; was `NULL`)
  - `DELETED_IND` <- `NULL` (kept verbatim; was `NULL`)
  - `DELETED_DATE` <- `NULL` (kept verbatim; was `NULL`)
  - `DELETED_BY` <- `NULL` (kept verbatim; was `NULL`)
  - `PERIOD_END_DATE` <- `NULL` (kept verbatim; was `NULL`)
  - `PERIOD_REFERENCE_TIME` <- `NULL` (kept verbatim; was `NULL`)
  - `TIMELINE_ACTION` <- `NULL` (kept verbatim; was `NULL`)
  - `UPDATED_BY` <- `NULL` (kept verbatim; was `NULL`)
  - `CREATE_DATE` <- `NULL` (via s4_routed; was `period_start_date`)
  - `CREATOR` <- `NULL` (kept verbatim; was `NULL`)
  - `HUB_STATE_IND` <- `NULL` (kept verbatim; was `NULL`)
  - `SRC_LAST_UPD_DT` <- `NULL` (via s4_routed; was `period_start_date`)

### sp_snow_pub_TRS_AUTHREP_C_S_TRS_PTY_MNG_ATTR.sql -> C_S_TRS_PTY_MNG_ATTR

- Kept steps: `s10_payee`. P_RUN_TS: YES.
- WHERE gate dropped: `WHERE VERSION_SEQ = 1) xa ON xa.PKEY_SRC_OBJECT = g.pkey_src_object WHERE g.rn = 1 AND xa.PKEY_SRC_OBJECT IS NULL`.
- Column map:
  - `CREATE_DATE` <- `CREATE_DT` (via s40_agg; was `g.CREATE_DT`)
  - `LAST_UPDATE_DATE` <- `:P_RUN_TS` (kept verbatim; was `:P_RUN_TS`)
  - `MNG_ATTR_TP` <- `:P_ATTR_TP_AUTH_REP` (kept verbatim; was `:P_ATTR_TP_AUTH_REP`)
  - `PTY_FK` <- `TO_VARCHAR(INDV_ID)` (via s40_agg; was `g.pty_pk`)
  - `PERIOD_END_DATE` <- `MAX(EFF_END_DT) OVER (PARTITION BY (TO_VARCHAR(INDV_ID) || ' ' || :P_ATTR_TP_AUTH_REP))` (via s40_agg; was `g.max_eff_end_dt`)
  - `PERIOD_START_DATE` <- `EFF_BEGIN_DT` (via s40_agg; was `g.EFF_BEGIN_DT`)
  - `VERSION_SEQ` <- `1` (kept verbatim; was `1`)
  - `SRC_ROWID` <- `TO_VARCHAR(INDV_ID) || ' ' || :P_ATTR_TP_AUTH_REP` (via s40_agg; was `g.pkey_src_object`)
  - `PKEY_SRC_OBJECT` <- `TO_VARCHAR(INDV_ID) || ' ' || :P_ATTR_TP_AUTH_REP` (via s40_agg; was `g.pkey_src_object`)
  - `SRC_LAST_UPD_DT` <- `CREATE_DT` (via s40_agg; was `g.CREATE_DT`)
  - `MNG_ATTR_VAL` <- `AR_FLAG` (via s40_agg; was `g.AR_FLAG`)

### sp_snow_pub_TRS_MNGSW_C_S_TRS_PTY_MNG_ATTR.sql -> C_S_TRS_PTY_MNG_ATTR

- Kept steps: `s10_daily`. P_RUN_TS: YES.
- WHERE gate dropped: `WHERE VERSION_SEQ = 1) xa ON xa.PKEY_SRC_OBJECT = t.pkey_src_object WHERE xa.PKEY_SRC_OBJECT IS NULL QUALIFY ROW_NUMBER() OVER (PARTITION BY t.pkey_src_object ORDER BY t.EFF_BEGIN_DT DESC NULLS LAST) = 1`.
- Columns set to NULL (no first-step source): ROWID_OBJECT (kept verbatim), DELETED_IND (kept verbatim), DELETED_DATE (kept verbatim), DELETED_BY (kept verbatim), PERIOD_END_DATE (kept verbatim), PERIOD_REFERENCE_TIME (kept verbatim), TIMELINE_ACTION (kept verbatim), UPDATED_BY (kept verbatim), CREATOR (kept verbatim), HUB_STATE_IND (kept verbatim).
- Column map:
  - `PKEY_SRC_OBJECT` <- `NVL(PTY_PK, '') || ' ' || '                 '` (via s40_attrs; was `t.pkey_src_object`)
  - `ROWID_OBJECT` <- `NULL` (kept verbatim; was `NULL`)
  - `DELETED_IND` <- `NULL` (kept verbatim; was `NULL`)
  - `DELETED_DATE` <- `NULL` (kept verbatim; was `NULL`)
  - `DELETED_BY` <- `NULL` (kept verbatim; was `NULL`)
  - `PERIOD_START_DATE` <- `EFF_BEGIN_DT` (via s40_attrs; was `t.EFF_BEGIN_DT`)
  - `PERIOD_END_DATE` <- `NULL` (kept verbatim; was `NULL`)
  - `MNG_ATTR_TP` <- `'                 '` (via s40_attrs; was `t.ATTR_TYPE`)
  - `MNG_ATTR_VAL` <- `TO_VARCHAR(FILE_CLEARANCE_SW)` (via s40_attrs; was `t.ATTR_VALUE`)
  - `VERSION_SEQ` <- `1` (kept verbatim; was `1`)
  - `PERIOD_REFERENCE_TIME` <- `NULL` (kept verbatim; was `NULL`)
  - `TIMELINE_ACTION` <- `NULL` (kept verbatim; was `NULL`)
  - `UPDATED_BY` <- `NULL` (kept verbatim; was `NULL`)
  - `CREATE_DATE` <- `:P_RUN_TS` (kept verbatim; was `:P_RUN_TS`)
  - `SRC_ROWID` <- `NVL(PTY_PK, '') || ' ' || '                 '` (via s40_attrs; was `t.pkey_src_object`)
  - `CREATOR` <- `NULL` (kept verbatim; was `NULL`)
  - `LAST_UPDATE_DATE` <- `:P_RUN_TS` (kept verbatim; was `:P_RUN_TS`)
  - `SRC_LAST_UPD_DT` <- `CREATE_DT` (via s40_attrs; was `t.SRC_LAST_UPD_DT`)
  - `PTY_FK` <- `PTY_PK` (via s40_attrs; was `t.PTY_PK`)
  - `HUB_STATE_IND` <- `NULL` (kept verbatim; was `NULL`)

### sp_snow_pub_TRS_NM_C_S_TRS_PTY_NM.sql -> C_S_TRS_PTY_NM

- Kept steps: `s10_src`. P_RUN_TS: YES.
- WHERE gate dropped: `WHERE VERSION_SEQ = 1) xn ON xn.PKEY_SRC_OBJECT = d.pkey_src_object WHERE xn.PKEY_SRC_OBJECT IS NULL QUALIFY ROW_NUMBER() OVER (PARTITION BY d.pkey_src_object ORDER BY d.CREATE_DT DESC NULLS LAST, d.full_nm) = 1`.
- Columns set to NULL (no first-step source): ROWID_OBJECT (kept verbatim), DELETED_IND (kept verbatim), DELETED_DATE (kept verbatim), DELETED_BY (kept verbatim), PERIOD_END_DATE (kept verbatim), PERIOD_REFERENCE_TIME (kept verbatim), UPDATED_BY (kept verbatim), CREATOR (kept verbatim), HUB_STATE_IND (kept verbatim).
- Column map:
  - `PTY_FK` <- `PKEY_PTY` (via s40_dedup; was `d.PKEY_PTY`)
  - `SFX_NM` <- `NULL::VARCHAR` (via s40_dedup; was `d.sfx_nm`)
  - `FRST_NM` <- `((INITCAP((FIRST_NAME::VARCHAR), ' ')))::VARCHAR` (via s40_dedup; was `d.frst_nm`)
  - `PFX_NM` <- `NULL::VARCHAR` (via s40_dedup; was `d.prfx_nm`)
  - `LST_NM` <- `((INITCAP((LAST_NAME::VARCHAR), ' ')))::VARCHAR` (via s40_dedup; was `d.lst_nm`)
  - `MDL_NM` <- `((INITCAP((MID_NAME::VARCHAR), ' ')))::VARCHAR` (via s40_dedup; was `d.mdl_nm`)
  - `FULL_NM` <- `TRIM(NVL(((INITCAP((FIRST_NAME::VARCHAR), ' '))), '')
                            || (' ' || TRIM(((INITCAP((MID_NAME::VARCHAR), ' ')))))
                            || ' '
                            || NVL(LTRIM(((INITCAP((LAST_NAME::VARCHAR), ' ')))), ''))::VARCHAR` (via s40_dedup; was `d.full_nm`)
  - `VERSION_SEQ` <- `1` (kept verbatim; was `1`)
  - `LAST_UPDATE_DATE` <- `:P_RUN_TS` (kept verbatim; was `:P_RUN_TS`)
  - `NM_TP` <- `:P_MEMBER_NAME_TYPE_CODE` (kept verbatim; was `:P_MEMBER_NAME_TYPE_CODE`)
  - `SRC_ROWID` <- `NVL(PKEY_PTY, '') || ' ' || :P_MEMBER_NAME_TYPE_CODE || ' ' || NVL(TO_VARCHAR(SEQUENCE_NUM), '')` (via s40_dedup; was `d.pkey_src_object`)
  - `ROWID_OBJECT` <- `NULL` (kept verbatim; was `NULL`)
  - `DELETED_IND` <- `NULL` (kept verbatim; was `NULL`)
  - `DELETED_DATE` <- `NULL` (kept verbatim; was `NULL`)
  - `DELETED_BY` <- `NULL` (kept verbatim; was `NULL`)
  - `PERIOD_END_DATE` <- `NULL` (kept verbatim; was `NULL`)
  - `PERIOD_REFERENCE_TIME` <- `NULL` (kept verbatim; was `NULL`)
  - `UPDATED_BY` <- `NULL` (kept verbatim; was `NULL`)
  - `CREATE_DATE` <- `CREATE_DT` (via s40_dedup; was `d.CREATE_DT`)
  - `CREATOR` <- `NULL` (kept verbatim; was `NULL`)
  - `HUB_STATE_IND` <- `NULL` (kept verbatim; was `NULL`)
  - `SRC_FULL_NM` <- `TRIM(NVL(FIRST_NAME, '') || IFF(MID_NAME IS NOT NULL, ' ' || TRIM(MID_NAME), '')
                    || ' ' || NVL(LTRIM(LAST_NAME), ''))` (via s40_dedup; was `d.src_full_name`)
  - `SRC_LAST_UPD_DT` <- `CREATE_DT` (via s40_dedup; was `d.CREATE_DT`)
  - `PKEY_SRC_OBJECT` <- `NVL(PKEY_PTY, '') || ' ' || :P_MEMBER_NAME_TYPE_CODE || ' ' || NVL(TO_VARCHAR(SEQUENCE_NUM), '')` (via s40_dedup; was `d.pkey_src_object`)
  - `PERIOD_START_DATE` <- `CREATE_DT` (via s40_dedup; was `d.CREATE_DT`)

### sp_snow_pub_TRS_PHN_C_S_TRS_PTY_RLE_EADDR.sql -> C_S_TRS_PTY_RLE_EADDR

- Kept steps: `s1_src`. P_RUN_TS: YES.
- WHERE gate dropped: `WHERE rn = 1 AND uq_tgt`.
- Columns set to NULL (no first-step source): PKEY_SRC_OBJECT (via s7_versions), ROWID_OBJECT (kept verbatim), DELETED_IND (kept verbatim), DELETED_DATE (kept verbatim), DELETED_BY (kept verbatim), PERIOD_START_DATE (via s7_versions), PERIOD_REFERENCE_TIME (kept verbatim), TIMELINE_ACTION (kept verbatim), UPDATED_BY (kept verbatim), CREATE_DATE (via s7_versions), CREATOR (kept verbatim), SRC_ROWID (via s7_versions), HUB_STATE_IND (kept verbatim), PTY_RLE_FK (via s7_versions), ELEC_ADDR (via s7_versions), USG_TP (kept verbatim), PERIOD_END_DATE (kept verbatim), SRC_LAST_UPD_DT (via s7_versions).
- Column map:
  - `PKEY_SRC_OBJECT` <- `NULL` (via s7_versions; was `pkey_src_object`)
  - `ROWID_OBJECT` <- `NULL` (kept verbatim; was `NULL`)
  - `DELETED_IND` <- `NULL` (kept verbatim; was `NULL`)
  - `DELETED_DATE` <- `NULL` (kept verbatim; was `NULL`)
  - `DELETED_BY` <- `NULL` (kept verbatim; was `NULL`)
  - `PERIOD_START_DATE` <- `NULL` (via s7_versions; was `period_start_date`)
  - `VERSION_SEQ` <- `'1'` (via s7_versions; VERSION_SEQ computed downstream; literal 1; was `version_seq`)
  - `PERIOD_REFERENCE_TIME` <- `NULL` (kept verbatim; was `NULL`)
  - `TIMELINE_ACTION` <- `NULL` (kept verbatim; was `NULL`)
  - `LAST_UPDATE_DATE` <- `:P_RUN_TS` (kept verbatim; was `:P_RUN_TS`)
  - `UPDATED_BY` <- `NULL` (kept verbatim; was `NULL`)
  - `CREATE_DATE` <- `NULL` (via s7_versions; was `period_start_date`)
  - `CREATOR` <- `NULL` (kept verbatim; was `NULL`)
  - `SRC_ROWID` <- `NULL` (via s7_versions; was `pkey_src_object`)
  - `HUB_STATE_IND` <- `NULL` (kept verbatim; was `NULL`)
  - `PTY_RLE_FK` <- `NULL` (via s7_versions; was `pty_rle_fk`)
  - `ELEC_ADDR` <- `NULL` (via s7_versions; was `elec_addr`)
  - `USG_TP` <- `NULL` (kept verbatim; was `NULL`)
  - `ADDR_TP` <- `'001'` (kept verbatim; was `'001'`)
  - `STS_CD` <- `'Active'` (kept verbatim; was `'Active'`)
  - `IS_VLD` <- `'Y'` (kept verbatim; was `'Y'`)
  - `PERIOD_END_DATE` <- `NULL` (kept verbatim; was `NULL`)
  - `SRC_LAST_UPD_DT` <- `NULL` (via s7_versions; was `period_start_date`)

### sp_snow_pub_TRS_PHN_C_S_TRS_PTY_RLE_PHN.sql -> C_S_TRS_PTY_RLE_PHN

- Kept steps: `s1_src`. P_RUN_TS: YES.
- WHERE gate dropped: `WHERE rn = 1 AND uq_tgt`.
- Columns set to NULL (no first-step source): PKEY_SRC_OBJECT (via s5_versions), ROWID_OBJECT (kept verbatim), DELETED_IND (kept verbatim), DELETED_DATE (kept verbatim), DELETED_BY (kept verbatim), PERIOD_START_DATE (via s5_versions), PERIOD_REFERENCE_TIME (kept verbatim), TIMELINE_ACTION (kept verbatim), UPDATED_BY (kept verbatim), CREATE_DATE (via s5_versions), CREATOR (kept verbatim), SRC_ROWID (via s5_versions), HUB_STATE_IND (kept verbatim), PTY_RLE_FK (via s5_versions), USG_TP (via s5_versions), PHN_TP (via s5_versions), PHN_NUM (via s5_versions), PREF_LVL (via s5_versions), PERIOD_END_DATE (kept verbatim), SRC_LAST_UPD_DT (via s5_versions).
- Column map:
  - `PKEY_SRC_OBJECT` <- `NULL` (via s5_versions; was `pkey_src_object`)
  - `ROWID_OBJECT` <- `NULL` (kept verbatim; was `NULL`)
  - `DELETED_IND` <- `NULL` (kept verbatim; was `NULL`)
  - `DELETED_DATE` <- `NULL` (kept verbatim; was `NULL`)
  - `DELETED_BY` <- `NULL` (kept verbatim; was `NULL`)
  - `PERIOD_START_DATE` <- `NULL` (via s5_versions; was `period_start_date`)
  - `VERSION_SEQ` <- `'1'` (via s5_versions; VERSION_SEQ computed downstream; literal 1; was `version_seq`)
  - `PERIOD_REFERENCE_TIME` <- `NULL` (kept verbatim; was `NULL`)
  - `TIMELINE_ACTION` <- `NULL` (kept verbatim; was `NULL`)
  - `LAST_UPDATE_DATE` <- `:P_RUN_TS` (kept verbatim; was `:P_RUN_TS`)
  - `UPDATED_BY` <- `NULL` (kept verbatim; was `NULL`)
  - `CREATE_DATE` <- `NULL` (via s5_versions; was `period_start_date`)
  - `CREATOR` <- `NULL` (kept verbatim; was `NULL`)
  - `SRC_ROWID` <- `NULL` (via s5_versions; was `pkey_src_object`)
  - `HUB_STATE_IND` <- `NULL` (kept verbatim; was `NULL`)
  - `PTY_RLE_FK` <- `NULL` (via s5_versions; was `pty_rle_fk`)
  - `USG_TP` <- `NULL` (via s5_versions; was `usg_tp`)
  - `PHN_TP` <- `NULL` (via s5_versions; was `phn_tp`)
  - `PHN_NUM` <- `NULL` (via s5_versions; was `phn_num`)
  - `PREF_LVL` <- `NULL` (via s5_versions; was `pref_lvl`)
  - `PERIOD_END_DATE` <- `NULL` (kept verbatim; was `NULL`)
  - `SRC_LAST_UPD_DT` <- `NULL` (via s5_versions; was `period_start_date`)

### sp_snow_pub_TRS_PLN_C_S_TRS_PTY_RLE_PLN.sql -> C_S_TRS_PTY_RLE_PLN

- Kept steps: `s10_src`. P_RUN_TS: YES.
- WHERE gate dropped: `WHERE pln_mstr_cd IS NOT NULL AND rn_key = 1 AND uq_pln`.
- Columns set to NULL (no first-step source): PKEY_SRC_OBJECT (via s30_ranked), PLN_FK (via s30_ranked), UPDATED_BY (kept verbatim), CREATOR (kept verbatim), HUB_STATE_IND (kept verbatim), ROWID_OBJECT (kept verbatim), DELETED_IND (kept verbatim), DELETED_DATE (kept verbatim), DELETED_BY (kept verbatim), SRC_ROWID (via s30_ranked).
- Column map:
  - `PKEY_SRC_OBJECT` <- `NULL` (via s30_ranked; was `pkey_prty_rl_plan`)
  - `PERIOD_START_DATE` <- `BEGIN_DT` (via s30_ranked; was `BEGIN_DT`)
  - `PERIOD_END_DATE` <- `END_DT` (via s30_ranked; was `END_DT`)
  - `VERSION_SEQ` <- `1` (via s30_ranked; was `version_seq`)
  - `LAST_UPDATE_DATE` <- `:P_RUN_TS` (via s30_ranked; was `run_ts`)
  - `PTY_RLE_FK` <- `TO_VARCHAR(INDV_ID) || '       '` (via s30_ranked; was `pty_rle_fk`)
  - `PLN_FK` <- `NULL` (via s30_ranked; was `pln_mstr_cd`)
  - `UPDATED_BY` <- `NULL` (kept verbatim; was `NULL`)
  - `CREATOR` <- `NULL` (kept verbatim; was `NULL`)
  - `HUB_STATE_IND` <- `NULL` (kept verbatim; was `NULL`)
  - `ROWID_OBJECT` <- `NULL` (kept verbatim; was `NULL`)
  - `DELETED_IND` <- `NULL` (kept verbatim; was `NULL`)
  - `DELETED_DATE` <- `NULL` (kept verbatim; was `NULL`)
  - `DELETED_BY` <- `NULL` (kept verbatim; was `NULL`)
  - `SRC_ROWID` <- `NULL` (via s30_ranked; was `pkey_prty_rl_plan`)
  - `CREATE_DATE` <- `:P_RUN_TS` (via s30_ranked; was `run_ts`)
  - `SRC_LAST_UPD_DT` <- `CREATE_DT` (via s30_ranked; was `CREATE_DT`)

### sp_snow_pub_TRS_PTY_C_S_TRS_PTY.sql -> C_S_TRS_PTY

- Kept steps: `s1_src`. P_RUN_TS: YES.
- WHERE gate dropped: `WHERE rn_pty = 1 AND uq_pty`.
- Columns set to NULL (no first-step source): ROWID_OBJECT (kept verbatim), DELETED_IND (kept verbatim), DELETED_DATE (kept verbatim), DELETED_BY (kept verbatim), SFX_NM (via s4_dedup), PRFX_NM (via s4_dedup), PERIOD_REFERENCE_TIME (kept verbatim), TIMELINE_ACTION (kept verbatim), UPDATED_BY (kept verbatim), CREATE_DATE (kept verbatim), CREATOR (kept verbatim), HUB_STATE_IND (kept verbatim), FLAG_SRC (kept verbatim), PERIOD_END_DATE (kept verbatim), RACE_CD (via s4_dedup), ETHNCTY (via s4_dedup).
- Column map:
  - `PKEY_SRC_OBJECT` <- `TRIM((IFF(SRC_TBL = 'DC_INDV', TO_VARCHAR(INDV_ID) || ' ' || 'DC_INDV',
                       TO_VARCHAR(INDV_ID))))` (via s4_dedup; was `pkey_trim`)
  - `ROWID_OBJECT` <- `NULL` (kept verbatim; was `NULL`)
  - `DELETED_IND` <- `NULL` (kept verbatim; was `NULL`)
  - `DELETED_DATE` <- `NULL` (kept verbatim; was `NULL`)
  - `DELETED_BY` <- `NULL` (kept verbatim; was `NULL`)
  - `GNDR_CD` <- `CASE WHEN '    ' IN ('I', 'Indv', 'INDV', 'HCP') AND LEFT(GENDER_CD, 1) IN ('B', 'U') THEN NULL
                 WHEN '    ' IN ('I', 'Indv', 'INDV', 'HCP') AND LEFT(GENDER_CD, 1) = 'M' THEN '1'
                 WHEN '    ' IN ('I', 'Indv', 'INDV', 'HCP') AND LEFT(GENDER_CD, 1) = 'F' THEN '2'
                 ELSE NULL END::VARCHAR` (via s4_dedup; was `mdm_gender_code`)
  - `SFX_NM` <- `NULL` (via s4_dedup; was `std_sfx_name`)
  - `PTY_BO_CLASS_CD` <- `:P_PTY_BO_CLASS_CD_MEMBER` (kept verbatim; was `:P_PTY_BO_CLASS_CD_MEMBER`)
  - `FRST_NM` <- `((INITCAP(FIRST_NAME, ' ')))::VARCHAR` (via s4_dedup; was `std_first_name`)
  - `PRFX_NM` <- `NULL` (via s4_dedup; was `std_prfx_name`)
  - `LST_NM` <- `((INITCAP(LAST_NAME, ' ')))::VARCHAR` (via s4_dedup; was `std_lst_name`)
  - `MDL_NM` <- `((INITCAP(MID_NAME, ' ')))::VARCHAR` (via s4_dedup; was `std_mdl_name`)
  - `FULL_NM` <- `TRIM(NVL(((INITCAP(FIRST_NAME, ' '))), '')
                            || (' ' || TRIM(((INITCAP(MID_NAME, ' ')))))
                            || ' '
                            || NVL(LTRIM(((INITCAP(LAST_NAME, ' ')))), ''))::VARCHAR` (via s4_dedup; was `std_full_name`)
  - `BIRTH_DT` <- `IFF(DOB_DT IS NULL, DOB_DT, NULL)` (via s4_dedup; was `std_birth_date`)
  - `VERSION_SEQ` <- `1` (kept verbatim; was `1`)
  - `PERIOD_REFERENCE_TIME` <- `NULL` (kept verbatim; was `NULL`)
  - `TIMELINE_ACTION` <- `NULL` (kept verbatim; was `NULL`)
  - `LAST_UPDATE_DATE` <- `:P_RUN_TS` (kept verbatim; was `:P_RUN_TS`)
  - `UPDATED_BY` <- `NULL` (kept verbatim; was `NULL`)
  - `CREATE_DATE` <- `NULL` (kept verbatim; was `NULL`)
  - `CREATOR` <- `NULL` (kept verbatim; was `NULL`)
  - `HUB_STATE_IND` <- `NULL` (kept verbatim; was `NULL`)
  - `FLAG_SRC` <- `NULL` (kept verbatim; was `NULL`)
  - `DEATH_DT` <- `DEATH_DT` (via s4_dedup; was `DEATH_DT`)
  - `SRC_FULL_NM` <- `TRIM(NVL(FIRST_NAME, '') || IFF(MID_NAME IS NOT NULL, ' ' || TRIM(MID_NAME), '')
                        || ' ' || NVL(LTRIM(LAST_NAME), ''))` (via s4_dedup; was `src_full_name`)
  - `PERIOD_START_DATE` <- `CREATE_DT` (via s4_dedup; was `CREATE_DT`)
  - `PERIOD_END_DATE` <- `NULL` (kept verbatim; was `NULL`)
  - `SRC_LAST_UPD_DT` <- `CREATE_DT` (via s4_dedup; was `CREATE_DT`)
  - `SRC_ROWID` <- `TRIM((IFF(SRC_TBL = 'DC_INDV', TO_VARCHAR(INDV_ID) || ' ' || 'DC_INDV',
                       TO_VARCHAR(INDV_ID))))` (via s4_dedup; was `pkey_trim`)
  - `RACE_CD` <- `NULL` (via s4_dedup; was `race_mstr`)
  - `ETHNCTY` <- `NULL` (via s4_dedup; was `ethnicity_mstr`)
  - `SRC_ETHNCTY` <- `ETHNICITY_CD` (via s4_dedup; was `ETHNICITY_CD`)
  - `SRC_RACE_CD` <- `RACE_CD` (via s4_dedup; was `RACE_CD`)

### sp_snow_pub_TRS_PTY_C_S_TRS_PTY_RLE.sql -> C_S_TRS_PTY_RLE

- Kept steps: `s1_src`. P_RUN_TS: YES.
- WHERE gate dropped: `WHERE rn_pty = 1 AND uq_rle`.
- Columns set to NULL (no first-step source): ROWID_OBJECT (kept verbatim), DELETED_IND (kept verbatim), DELETED_DATE (kept verbatim), DELETED_BY (kept verbatim), PERIOD_END_DATE (kept verbatim), TIMELINE_ACTION (kept verbatim), PERIOD_REFERENCE_TIME (kept verbatim), UPDATED_BY (kept verbatim), CREATE_DATE (kept verbatim), CREATOR (kept verbatim), HUB_STATE_IND (kept verbatim).
- Column map:
  - `PTY_FK` <- `TRIM((IFF(SRC_TBL = 'DC_INDV', TO_VARCHAR(INDV_ID) || ' ' || 'DC_INDV',
                       TO_VARCHAR(INDV_ID))))` (via s4_dedup; was `pkey_trim`)
  - `PKEY_SRC_OBJECT` <- `(TRIM((IFF(SRC_TBL = 'DC_INDV', TO_VARCHAR(INDV_ID) || ' ' || 'DC_INDV',
                       TO_VARCHAR(INDV_ID))))) || '|' || :P_RLE_BO_CLASS_CD_MEMBER` (expression kept; was `pkey_trim || '|' || :P_RLE_BO_CLASS_CD_MEMBER`)
  - `ROWID_OBJECT` <- `NULL` (kept verbatim; was `NULL`)
  - `DELETED_IND` <- `NULL` (kept verbatim; was `NULL`)
  - `DELETED_DATE` <- `NULL` (kept verbatim; was `NULL`)
  - `DELETED_BY` <- `NULL` (kept verbatim; was `NULL`)
  - `RLE_BO_CLASS_CD` <- `:P_RLE_BO_CLASS_CD_MEMBER` (kept verbatim; was `:P_RLE_BO_CLASS_CD_MEMBER`)
  - `VERSION_SEQ` <- `1` (kept verbatim; was `1`)
  - `PERIOD_END_DATE` <- `NULL` (kept verbatim; was `NULL`)
  - `PERIOD_START_DATE` <- `CREATE_DT` (via s4_dedup; was `CREATE_DT`)
  - `TIMELINE_ACTION` <- `NULL` (kept verbatim; was `NULL`)
  - `PERIOD_REFERENCE_TIME` <- `NULL` (kept verbatim; was `NULL`)
  - `UPDATED_BY` <- `NULL` (kept verbatim; was `NULL`)
  - `CREATE_DATE` <- `NULL` (kept verbatim; was `NULL`)
  - `CREATOR` <- `NULL` (kept verbatim; was `NULL`)
  - `SRC_LAST_UPD_DT` <- `CREATE_DT` (via s4_dedup; was `CREATE_DT`)
  - `HUB_STATE_IND` <- `NULL` (kept verbatim; was `NULL`)
  - `SRC_ROWID` <- `(TRIM((IFF(SRC_TBL = 'DC_INDV', TO_VARCHAR(INDV_ID) || ' ' || 'DC_INDV',
                       TO_VARCHAR(INDV_ID))))) || '|' || :P_RLE_BO_CLASS_CD_MEMBER` (expression kept; was `pkey_trim || '|' || :P_RLE_BO_CLASS_CD_MEMBER`)
  - `LAST_UPDATE_DATE` <- `:P_RUN_TS` (kept verbatim; was `:P_RUN_TS`)

### sp_snow_pub_TRS_REL1_C_S_TRS_PTY_RLE_REL.sql -> C_S_TRS_PTY_RLE_REL

- Kept steps: `s1_src`. P_RUN_TS: YES.
- WHERE gate dropped: `WHERE uq_rel`.
- Columns set to NULL (no first-step source): PKEY_SRC_OBJECT (via s6_timeline), ROWID_OBJECT (kept verbatim), DELETED_IND (kept verbatim), DELETED_DATE (kept verbatim), DELETED_BY (kept verbatim), UPDATED_BY (kept verbatim), CREATOR (kept verbatim), SRC_ROWID (via s6_timeline), REL_TYPE_CODE (read from real table, not the chain), HIERARCHY_CODE (read from real table, not the chain), REL_TP (via s6_timeline).
- Column map:
  - `PKEY_SRC_OBJECT` <- `NULL` (via s6_timeline; was `pkey_src_object`)
  - `ROWID_OBJECT` <- `NULL` (kept verbatim; was `NULL`)
  - `DELETED_IND` <- `NULL` (kept verbatim; was `NULL`)
  - `DELETED_DATE` <- `NULL` (kept verbatim; was `NULL`)
  - `DELETED_BY` <- `NULL` (kept verbatim; was `NULL`)
  - `PERIOD_START_DATE` <- `EFF_BEGIN_DT` (via s6_timeline; was `EFF_BEGIN_DT`)
  - `PERIOD_END_DATE` <- `EFF_BEGIN_DT` (via s6_timeline; was `tl_period_end_date`)
  - `VERSION_SEQ` <- `'1'` (via s6_timeline; VERSION_SEQ computed downstream; literal 1; was `tl_version_seq`)
  - `PERIOD_REFERENCE_TIME` <- `EFF_BEGIN_DT` (via s6_timeline; was `tl_period_end_date`)
  - `TIMELINE_ACTION` <- `IFF(EFF_BEGIN_DT IS NOT NULL, 2, NULL)` (via s6_timeline; was `tl_timeline_action`)
  - `LAST_UPDATE_DATE` <- `:P_RUN_TS` (kept verbatim; was `:P_RUN_TS`)
  - `UPDATED_BY` <- `NULL` (kept verbatim; was `NULL`)
  - `CREATE_DATE` <- `CREATE_DT` (via s6_timeline; was `CREATE_DT`)
  - `CREATOR` <- `NULL` (kept verbatim; was `NULL`)
  - `SRC_ROWID` <- `NULL` (via s6_timeline; was `pkey_src_object`)
  - `HUB_STATE_IND` <- `1` (via s6_timeline; HUB_STATE_IND computed downstream; literal 1; was `tl_hub_state_ind`)
  - `PTY_RLE_FK_1` <- `IFF(PTY_PKEY IS NULL, NULL, TRIM(PTY_PKEY) || '       ')` (via s6_timeline; was `pty_rle_fk_1`)
  - `PTY_RLE_FK_2` <- `IFF(REF_PTY_PKEY IS NULL, NULL, TRIM(REF_PTY_PKEY) || '       ')` (via s6_timeline; was `pty_rle_fk_2`)
  - `REL_TYPE_CODE` <- `NULL` (read from real table, not the chain; was `rel_type_code_label`)
  - `HIERARCHY_CODE` <- `NULL` (read from real table, not the chain; was `hierarchy_code`)
  - `REL_TP` <- `NULL` (via s6_timeline; was `rel_type_code`)
  - `SRC_LAST_UPD_DT` <- `IFF(CREATE_DT IS NOT NULL AND UPDATE_DT IS NOT NULL, GREATEST(CREATE_DT, UPDATE_DT),
                   NVL(CREATE_DT, UPDATE_DT))` (via s6_timeline; was `src_last_upd_dt`)

### sp_snow_pub_TRS_REL2_C_S_TRS_PTY_RLE_REL_PROV.sql -> C_S_TRS_PTY_RLE_REL_PROV

- Kept steps: `s1_src`. P_RUN_TS: YES.
- WHERE gate dropped: `WHERE uq_rel`.
- Columns set to NULL (no first-step source): PKEY_SRC_OBJECT (via s6_timeline), CREATE_DATE (kept verbatim), SRC_ROWID (via s6_timeline), PTY_RLE_FK_2 (via s6_timeline), REL_TYPE_CODE (via s6_timeline), ROWID_OBJECT (kept verbatim), DELETED_IND (kept verbatim), DELETED_DATE (kept verbatim), DELETED_BY (kept verbatim), UPDATED_BY (kept verbatim), CREATOR (kept verbatim).
- Column map:
  - `PKEY_SRC_OBJECT` <- `NULL` (via s6_timeline; was `pkey_src_object`)
  - `PERIOD_START_DATE` <- `BEGIN_DT` (via s6_timeline; was `BEGIN_DT`)
  - `PERIOD_END_DATE` <- `BEGIN_DT` (via s6_timeline; was `tl_period_end_date`)
  - `VERSION_SEQ` <- `'1'` (via s6_timeline; VERSION_SEQ computed downstream; literal 1; was `tl_version_seq`)
  - `LAST_UPDATE_DATE` <- `:P_RUN_TS` (kept verbatim; was `:P_RUN_TS`)
  - `CREATE_DATE` <- `NULL` (kept verbatim; was `NULL`)
  - `SRC_ROWID` <- `NULL` (via s6_timeline; was `pkey_src_object`)
  - `HUB_STATE_IND` <- `1` (via s6_timeline; HUB_STATE_IND computed downstream; literal 1; was `tl_hub_state_ind`)
  - `PTY_RLE_FK_1` <- `IFF(PTY_PK IS NULL, NULL, TRIM(PTY_PK) || '       ')` (via s6_timeline; was `pty_rle_fk_1`)
  - `PTY_RLE_FK_2` <- `NULL` (via s6_timeline; was `pty_rle_fk_2`)
  - `REL_TYPE_CODE` <- `NULL` (via s6_timeline; was `rel_type_code`)
  - `HIERARCHY_CODE` <- `'Member'` (kept verbatim; was `'Member'`)
  - `REL_TP` <- `:P_PCP_REL_TP` (kept verbatim; was `:P_PCP_REL_TP`)
  - `SRC_LAST_UPD_DT` <- `CREATE_DT` (via s6_timeline; was `CREATE_DT`)
  - `PERIOD_REFERENCE_TIME` <- `BEGIN_DT` (via s6_timeline; was `tl_period_end_date`)
  - `TIMELINE_ACTION` <- `IFF(BEGIN_DT IS NOT NULL, 2, NULL)` (via s6_timeline; was `tl_timeline_action`)
  - `ROWID_OBJECT` <- `NULL` (kept verbatim; was `NULL`)
  - `DELETED_IND` <- `NULL` (kept verbatim; was `NULL`)
  - `DELETED_DATE` <- `NULL` (kept verbatim; was `NULL`)
  - `DELETED_BY` <- `NULL` (kept verbatim; was `NULL`)
  - `UPDATED_BY` <- `NULL` (kept verbatim; was `NULL`)
  - `CREATOR` <- `NULL` (kept verbatim; was `NULL`)

### sp_snow_pub_TRS_STGTOA_C_S_LU_TOA.sql -> C_S_LU_TOA

- Kept steps: `s10_keyed`. P_RUN_TS: YES.
- WHERE gate dropped: `none`.
- Columns set to NULL (no first-step source): ROWID_OBJECT (kept verbatim), DELETED_IND (kept verbatim), DELETED_DATE (kept verbatim), DELETED_BY (kept verbatim), PERIOD_START_DATE (kept verbatim), PERIOD_END_DATE (kept verbatim), PERIOD_REFERENCE_TIME (kept verbatim).
- Column map:
  - `PKEY_SRC_OBJECT` <- `PKEY_SRC_OBJECT` (via s20_final; was `pkey_src_object`)
  - `ROWID_OBJECT` <- `NULL` (kept verbatim; was `NULL`)
  - `DELETED_IND` <- `NULL` (kept verbatim; was `NULL`)
  - `DELETED_DATE` <- `NULL` (kept verbatim; was `NULL`)
  - `DELETED_BY` <- `NULL` (kept verbatim; was `NULL`)
  - `PERIOD_START_DATE` <- `NULL` (kept verbatim; was `NULL`)
  - `PERIOD_END_DATE` <- `NULL` (kept verbatim; was `NULL`)
  - `VERSION_SEQ` <- `1` (kept verbatim; was `1`)
  - `PERIOD_REFERENCE_TIME` <- `NULL` (kept verbatim; was `NULL`)
  - `LAST_UPDATE_DATE` <- `:P_RUN_TS` (kept verbatim; was `:P_RUN_TS`)
  - `UPDATED_BY` <- `SUBSTR(UPDATE_USER_ID, 1, 50)` (expression kept; was `SUBSTR(UPDATE_USER_ID, 1, 50)`)
  - `CREATE_DATE` <- `CREATE_DT` (via s20_final; was `CREATE_DT`)
  - `CREATOR` <- `'admin'` (kept verbatim; was `'admin'`)
  - `SRC_ROWID` <- `SUBSTR(PKEY_SRC_OBJECT, 1, 30)` (expression kept; was `SUBSTR(pkey_src_object, 1, 30)`)
  - `HUB_STATE_IND` <- `1` (kept verbatim; was `1`)
  - `TOA_CD` <- `PKEY_SRC_OBJECT` (via s20_final; was `pkey_src_object`)
  - `TOA_LBL` <- `SUBSTR(TOA_LBL, 1, 100)` (expression kept; was `SUBSTR(toa_lbl, 1, 100)`)
  - `TOA_DESC` <- `SUBSTR(TOA_DESC, 1, 250)` (expression kept; was `SUBSTR(TOA_DESC, 1, 250)`)
  - `MBR_PRG_CD` <- `MBR_PRG_CD` (via s20_final; was `mbr_prg_cd`)
  - `EFF_STRT_DT` <- `EFF_BEGIN_DT` (via s20_final; was `EFF_BEGIN_DT`)
  - `EFF_END_DT` <- `EFF_END_DT` (via s20_final; was `EFF_END_DT`)

### sp_snow_pub_TRS_TOA_C_S_TRS_PTY_RLE_TOA.sql -> C_S_TRS_PTY_RLE_TOA

- Kept steps: `s10_raw`. P_RUN_TS: YES.
- WHERE gate dropped: `WHERE NOT grp_bad_value AND NOT grp_dates AND uq_toa`.
- Columns set to NULL (no first-step source): PKEY_SRC_OBJECT (via s40_ranked), ROWID_OBJECT (kept verbatim), DELETED_IND (kept verbatim), DELETED_DATE (kept verbatim), DELETED_BY (kept verbatim), PERIOD_REFERENCE_TIME (kept verbatim), UPDATED_BY (kept verbatim), CREATOR (kept verbatim), SRC_ROWID (via s40_ranked), HUB_STATE_IND (kept verbatim), TOA_FK (via s40_ranked).
- Column map:
  - `PKEY_SRC_OBJECT` <- `NULL` (via s40_ranked; was `pkey_src_object`)
  - `ROWID_OBJECT` <- `NULL` (kept verbatim; was `NULL`)
  - `DELETED_IND` <- `NULL` (kept verbatim; was `NULL`)
  - `DELETED_DATE` <- `NULL` (kept verbatim; was `NULL`)
  - `DELETED_BY` <- `NULL` (kept verbatim; was `NULL`)
  - `PERIOD_START_DATE` <- `BEGIN_DT` (via s40_ranked; was `BEGIN_DT`)
  - `PERIOD_END_DATE` <- `END_DT` (via s40_ranked; was `END_DT`)
  - `VERSION_SEQ` <- `VERSION_SEQ` (via s40_ranked; was `VERSION_SEQ`)
  - `PERIOD_REFERENCE_TIME` <- `NULL` (kept verbatim; was `NULL`)
  - `LAST_UPDATE_DATE` <- `:P_RUN_TS` (via s40_ranked; was `run_ts`)
  - `UPDATED_BY` <- `NULL` (kept verbatim; was `NULL`)
  - `CREATE_DATE` <- `CREATE_DT` (via s40_ranked; was `CREATE_DT`)
  - `CREATOR` <- `NULL` (kept verbatim; was `NULL`)
  - `SRC_ROWID` <- `NULL` (via s40_ranked; was `pkey_src_object`)
  - `HUB_STATE_IND` <- `NULL` (kept verbatim; was `NULL`)
  - `TOA_SOURCE` <- `DECODE(SRC_TBL, '             ', '    ', '            ', '     ')` (via s40_ranked; was `toa_source`)
  - `TOA_FK` <- `NULL` (via s40_ranked; was `toa_cd`)
  - `EFF_STRT_DT` <- `BEGIN_DT` (via s40_ranked; was `BEGIN_DT`)
  - `EFF_END_DT` <- `END_DT` (via s40_ranked; was `END_DT`)
  - `PTY_RLE_FK` <- `INDV_ID || '       '` (via s40_ranked; was `pty_rle_fk`)
  - `EDG_NUM` <- `EDG_NUM` (via s40_ranked; was `EDG_NUM`)
  - `CASE_NUM` <- `CASE_NUM` (via s40_ranked; was `CASE_NUM`)
  - `SGMNT_KEY` <- `NVL(TO_VARCHAR(EDG_NUM), '') || ' ' || NVL(TO_VARCHAR(PROGRAM_CD), '') || ' '
               || NVL(TO_VARCHAR(MCI_CREATE_SEQ), '')` (via s40_ranked; was `sgmnt_key`)
  - `CNVRT_DT` <- `CONVERT_DT` (via s40_ranked; was `CONVERT_DT`)
  - `CNVRT_SYS_CD` <- `SYSTEM_CD` (via s40_ranked; was `SYSTEM_CD`)
  - `INDV_ID` <- `PTY_PK` (via s40_ranked; was `PTY_PK`)
  - `PRTCPNT_STS_CD` <- `PART_STATUS_CD` (via s40_ranked; was `PART_STATUS_CD`)
  - `SRC_LAST_UPD_DT` <- `CREATE_DT` (via s40_ranked; was `CREATE_DT`)

## Dropped (not C_S_* targets)

- sp_snow_pub_TRS_ADDR1_STG_TRS_D_UNQ_ADDR.sql -> STG_TRS_D_UNQ_ADDR
- sp_snow_pub_TRS_ADDR2_DQM_ADDRESS.sql -> DQM_ADDRESS
- sp_snow_pub_TRS_ADDR2_EXC_STG_BAD_REC_MEMB.sql -> EXC_STG_BAD_REC_MEMB
- sp_snow_pub_TRS_ALT_EXC_STG_BAD_REC_MEMB.sql -> EXC_STG_BAD_REC_MEMB
- sp_snow_pub_TRS_PHN_EXC_STG_BAD_REC_MEMB_EMAIL.sql -> EXC_STG_BAD_REC_MEMB
- sp_snow_pub_TRS_PHN_EXC_STG_BAD_REC_MEMB_PHONE.sql -> EXC_STG_BAD_REC_MEMB
- sp_snow_pub_TRS_PLN_EXC_STG_BAD_REC_MEMB.sql -> EXC_STG_BAD_REC_MEMB
- sp_snow_pub_TRS_PTYDEACT_STG_TRS_DEACTIVED_MEMBERS.sql -> STG_TRS_DEACTIVED_MEMBERS
- sp_snow_pub_TRS_PTY_EXC_STG_BAD_REC_MEMB_BIRTH.sql -> EXC_STG_BAD_REC_MEMB
- sp_snow_pub_TRS_PTY_EXC_STG_BAD_REC_MEMB_DEATH.sql -> EXC_STG_BAD_REC_MEMB
- sp_snow_pub_TRS_PTY_EXC_STG_BAD_REC_MEMB_ETHNICITY.sql -> EXC_STG_BAD_REC_MEMB
- sp_snow_pub_TRS_PTY_EXC_STG_BAD_REC_MEMB_GENDER.sql -> EXC_STG_BAD_REC_MEMB
- sp_snow_pub_TRS_PTY_EXC_STG_BAD_REC_MEMB_NAME.sql -> EXC_STG_BAD_REC_MEMB
- sp_snow_pub_TRS_PTY_EXC_STG_BAD_REC_MEMB_RACE.sql -> EXC_STG_BAD_REC_MEMB
- sp_snow_pub_TRS_PTY_STG_TRS_VALID_MEMBERS.sql -> STG_TRS_VALID_MEMBERS
- sp_snow_pub_TRS_REL1_EXC_STG_BAD_REC_MEMB_DATES.sql -> EXC_STG_BAD_REC_MEMB
- sp_snow_pub_TRS_REL1_EXC_STG_BAD_REC_MEMB_LOOKUP.sql -> EXC_STG_BAD_REC_MEMB
- sp_snow_pub_TRS_REL1_EXC_STG_BAD_REC_MEMB_MAIN_ALT_ID.sql -> EXC_STG_BAD_REC_MEMB
- sp_snow_pub_TRS_REL1_EXC_STG_BAD_REC_MEMB_REF_ALT_ID.sql -> EXC_STG_BAD_REC_MEMB
- sp_snow_pub_TRS_REL2_EXC_STG_BAD_REC_MEMB_DATES.sql -> EXC_STG_BAD_REC_MEMB
- sp_snow_pub_TRS_REL2_EXC_STG_BAD_REC_MEMB_DEFAULT.sql -> EXC_STG_BAD_REC_MEMB
- sp_snow_pub_TRS_RELDEACT_STG_TRS_DEACTIVATED_RELATIONSHIPS.sql -> STG_TRS_DEACTIVATED_RELATIONSHIPS
- sp_snow_pub_TRS_TOA_EXC_STG_BAD_REC_MEMB_BAD_VALUE.sql -> EXC_STG_BAD_REC_MEMB
- sp_snow_pub_TRS_TOA_EXC_STG_BAD_REC_MEMB_DATES.sql -> EXC_STG_BAD_REC_MEMB

