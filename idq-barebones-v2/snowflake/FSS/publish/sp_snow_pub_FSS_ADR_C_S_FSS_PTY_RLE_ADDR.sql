-- ============================================================================
-- BARE-BONES STRIP of the v2.1 config-driven step driver (FSS).
-- Removed: the COMMON.ETL_RUN_CONFIG_TBL GATHER block, all flags /
-- consumed strings / driver-row gate, all sp_etl_checkpoint /
-- sp_etl_job_begin / sp_etl_job_finish / sp_etl_job_fail calls,
-- P_JOB_RUN_ID, P_INPUT_TABLES, l_job_run_id, l_flag_*, l_in_*, l_pub_*,
-- step existence-check / probe blocks, and the seed file (not copied).
-- Kept verbatim: step-5 DROP TABLE IF EXISTS cleanup, step call order,
-- the single publish transaction with branches in order, every step CTAS
-- and every publish INSERT, and the fn_snow_helper36_common summary lines
-- (publish lines now appended inside the transaction, in the same order,
-- reusing l_rows instead of the removed l_pub_* variables, so the
-- returned summary string is unchanged in content and order).
-- NOTE: the v2.1 header below is retained for its business-flow and
-- parity notes; its CONFIG-DRIVEN NOTES / TRANSACTION EDGES / SIGNATURE /
-- FRAMEWORK paragraphs describe the v2.1 code and no longer apply.
-- ============================================================================
-- ============================================================================
-- sp_snow_pub_FSS_ADR_C_S_FSS_PTY_RLE_ADDR  --  BARE-BONES STEP DRIVER (FSS)
--
-- Mapping: m_Tgt_C_S_FSS_Pty_Addr, workflow wf_FSS_Stage_Load.
-- Publish branch STEP_NO 60, checkpoint STEP_NAME PUBLISH_C_S_FSS_PTY_RLE_ADDR.
-- Target: C_S_FSS_PTY_RLE_ADDR. Kind: SPINE. Good addresses.
-- Branch 2 of the original publish, in original order.
--
-- INPUTS
--   Reads ONLY WRK_FSS_ADDR_S4_SCORED (P_INPUT_TABLES default). The INSERT references neither original parameter nor the run timestamp directly, so P_RUN_TS is carried for a uniform driver call signature and is unused in the body (stated, not hidden).
--
-- BUSINESS SQL
--   The INSERT below is the current branch INSERT verbatim: same
--   columns, values and WHERE guard (score = '100' AND uq_addr). No business expression,
--   filter, guard or column list was changed.
--
-- FRAMEWORK RULE
--   NO transaction control and NO checkpoint calls in this proc. The
--   driver calls it inside ONE publish transaction (all branches
--   together, so a publish either lands completely or not at all),
--   COMMITs, and only then checkpoints this branch with the returned
--   row count. Never call a checkpoint between BEGIN TRANSACTION and
--   COMMIT.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_pub_FSS_ADR_C_S_FSS_PTY_RLE_ADDR ()
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
INSERT INTO C_S_FSS_PTY_RLE_ADDR
           (PKEY_SRC_OBJECT, ROWID_OBJECT, DELETED_IND, DELETED_DATE, DELETED_BY, VERSION_SEQ,
            PERIOD_REFERENCE_TIME, LAST_UPDATE_DATE, UPDATED_BY, CREATE_DATE, CREATOR, SRC_ROWID, HUB_STATE_IND,
            PTY_RLE_FK, ADDR_TP, USG_TP, PREF_LVL, HIERARCHY_CODE, HM_REL_TP_CD, LOC_IDN, SRC_LAST_UPD_DT,
            ADDR_LN_1, ADDR_LN_2, BLDNG_NM, FLR_NUM, CITY, COUNTY, STATE, CNTRY_CD, PSTL_CD, PSTL_CD_EXT,
            LCTN_CRDNT_DESC, LATTD, LNGTD, PSTL_BRCD, VLDTN_MSG, RGN_CD, MLBLTY_SCR, ADDR_TP_CD, ORG_DESC,
            ORG_NM, BLDG_NMBR, SUB_BLDG_NM, SUB_BLDG_DESC, GEOCD_STS_CD, RSDNTL_DLVRY_IND, SRC_ADDR_LN_1,
            SRC_ADDR_LN_2, SRC_CITY, SRC_COUNTY, SRC_STATE, SRC_CNTRY, SRC_PSTL_CD, SRC_PSTL_CD_EXT, EFF_STRT_DT,
            EFF_END_DT, PERIOD_START_DATE)
    SELECT pkey_src_object, NULL, NULL, NULL, NULL, version_seq, NULL, run_ts, mapping_name, DT_LAST_UPDATE,
           NULL, pkey_src_object, hub_state_ind, pty_rle_fk, addr_tp, NULL, pref_lvl, hierarchy_code,
           hm_rel_tp_cd, loc_idn, DT_LAST_UPDATE, hold_line1, hold_line2, a_building_name, NULL, a_city,
           a_county_fips, a_state_fips, a_country, a_zip_cd_5, a_zip_cd_4_extn, NULL, a_latitude,
           a_longitude, NULL, a_match_code, NULL, a_mailability_score, a_address_type, a_org_descriptor,
           a_org_name, a_building_number, a_sub_building_complete, a_sub_building_descriptor,
           a_geocoding_status, a_residential, ADDR_LINE1, ADDR_LINE2, ADDR_CITY, CD_CNTY, ADDR_STATE,
           src_cntry, ADDR_ZIP, NULL, DT_LAST_UPDATE, NULL, DT_CREATED
      FROM WRK_FSS_ADDR_S4_SCORED
     WHERE score = '100' AND uq_addr;
    RETURN SQLROWCOUNT;
END;
$$;
