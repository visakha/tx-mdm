-- ============================================================================
-- sp_snow_pub_CRE_CARE_C_S_CRE_PTY_RLE_ADDR  --  BARE-BONES PUBLISH BRANCH (CRE)
--
-- Mapping: m_Tgt_C_S_CRE_CARE_Clients, workflow wf_CRE_Stage_Load_Ongoing.
-- Target: C_S_CRE_PTY_RLE_ADDR. Consumes WRK_CRE_CARE_S5_KEYED only.
--
-- Bare-bones variant: no parameters. P_RUN_TS is NOT kept: the
-- INSERT reads the run_ts / mapping_name columns materialised
-- in step 50, and references neither an original parameter nor
-- the run timestamp directly. The INSERT below is the v2.1
-- branch INSERT verbatim. No transaction control, no checkpoint.
-- The driver calls it inside ONE publish transaction.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_pub_CRE_CARE_C_S_CRE_PTY_RLE_ADDR ()
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
    INSERT INTO C_S_CRE_PTY_RLE_ADDR
           (PKEY_SRC_OBJECT, SRC_ROWID, VERSION_SEQ, LAST_UPDATE_DATE, PERIOD_START_DATE, PERIOD_END_DATE,
            PERIOD_REFERENCE_TIME, TIMELINE_ACTION, CREATE_DATE, HIERARCHY_CODE, PREF_LVL, ADDR_TP, HM_REL_TP_CD,
            ADDR_LN_1, ADDR_LN_2, CITY, COUNTY, STATE, CNTRY_CD, PSTL_CD, PSTL_CD_EXT, LATTD, LNGTD, MLBLTY_SCR,
            PTY_RLE_FK, USG_TP, SRC_ADDR_LN_1, SRC_CITY, SRC_COUNTY, SRC_STATE, SRC_CNTRY, SRC_PSTL_CD,
            SRC_PSTL_CD_EXT, SRC_LAST_UPD_DT, FLR_NUM, ADDR_TP_CD, SUB_BLDG_DESC, SUB_BLDG_NM, BLDG_NMBR,
            BLDNG_NM, RSDNTL_DLVRY_IND, GEOCD_STS_CD, ORG_NM, ORG_DESC, VLDTN_MSG)
    SELECT addr_key, addr_src_rowid, version_seq_num, last_update, period_start, period_end,
           period_reference_time, timeline_action, last_update, hierarchy_code, pref_lvl, addr_tp,
           hm_rel_tp_cd, a_line1, a_line2, a_city, a_county, a_state, a_country, a_postcode, a_postcode_ext,
           a_latitude, a_longitude, a_mailability_score, rle_key, addr_tp, STREET, CITY, CNTY, STATE,
           src_cntry, ZIP, ZIPSUF, CARE_LASTUP_DT, a_sub_building_number, a_address_type,
           a_sub_building_descriptor, a_sub_building_complete, a_building_number, a_building_name,
           a_residential, a_geocoding_status, a_org_name, a_org_descriptor, a_match_code
      FROM WRK_CRE_CARE_S5_KEYED
     WHERE grp_addr AND uq_addr;
    RETURN SQLROWCOUNT;
END;
$$;
