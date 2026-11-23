-- ============================================================================
-- sp_snow_pub_TRS_TOA_C_S_TRS_PTY_RLE_TOA  --  BARE-BONES PUBLISH BRANCH (TRS)
--
-- Mapping: m_Tgt_C_S_TRS_Pty_Rle_TOA, workflow wf_TRS_Stage_Load_1_Ongoing.
-- Target: C_S_TRS_PTY_RLE_TOA. Kind: SPINE (Valid TOA rows).
-- Consumes (v2.1 declared inputs): WRK_TRS_TOA_S40_RANKED.
-- Keeps P_RUN_TS: N. Original params used: none.
--
-- The INSERT below is the v2.1 branch INSERT verbatim. NO transaction
-- control and NO completion calls in this proc: the driver calls it
-- inside ONE publish transaction (all branches together, so a publish
-- either lands completely or not at all). Returns SQLROWCOUNT.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_pub_TRS_TOA_C_S_TRS_PTY_RLE_TOA (
)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
INSERT INTO C_S_TRS_PTY_RLE_TOA
           (PKEY_SRC_OBJECT, ROWID_OBJECT, DELETED_IND, DELETED_DATE, DELETED_BY, PERIOD_START_DATE,
            PERIOD_END_DATE, VERSION_SEQ, PERIOD_REFERENCE_TIME, LAST_UPDATE_DATE, UPDATED_BY, CREATE_DATE,
            CREATOR, SRC_ROWID, HUB_STATE_IND, TOA_SOURCE, TOA_FK, EFF_STRT_DT, EFF_END_DT, PTY_RLE_FK, EDG_NUM,
            CASE_NUM, SGMNT_KEY, CNVRT_DT, CNVRT_SYS_CD, INDV_ID, PRTCPNT_STS_CD, SRC_LAST_UPD_DT)
    SELECT pkey_src_object, NULL, NULL, NULL, NULL, BEGIN_DT, END_DT, VERSION_SEQ, NULL, run_ts, NULL,
           CREATE_DT, NULL, pkey_src_object, NULL, toa_source, toa_cd, BEGIN_DT, END_DT, pty_rle_fk, EDG_NUM,
           CASE_NUM, sgmnt_key, CONVERT_DT, SYSTEM_CD, PTY_PK, PART_STATUS_CD, CREATE_DT
      FROM WRK_TRS_TOA_S40_RANKED
     WHERE NOT grp_bad_value AND NOT grp_dates AND uq_toa;
    RETURN SQLROWCOUNT;
END;
$$;
