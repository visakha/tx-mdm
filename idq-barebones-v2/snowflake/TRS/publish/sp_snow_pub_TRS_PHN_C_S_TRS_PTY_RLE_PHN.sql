-- ============================================================================
-- sp_snow_pub_TRS_PHN_C_S_TRS_PTY_RLE_PHN  --  BARE-BONES PUBLISH BRANCH (TRS)
--
-- Mapping: m_Tgt_C_S_TRS_Pty_Rle_Phn_And_EAddr, workflow wf_TRS_Stage_Load_1_Ongoing.
-- Target: C_S_TRS_PTY_RLE_PHN. Kind: SPINE (Valid phones).
-- Consumes (v2.1 declared inputs): WRK_TRS_PHN_S5_VERSIONS.
-- Keeps P_RUN_TS: Y. Original params used: none.
--
-- The INSERT below is the v2.1 branch INSERT verbatim. NO transaction
-- control and NO completion calls in this proc: the driver calls it
-- inside ONE publish transaction (all branches together, so a publish
-- either lands completely or not at all). Returns SQLROWCOUNT.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_pub_TRS_PHN_C_S_TRS_PTY_RLE_PHN (

    P_RUN_TS       TIMESTAMP_NTZ DEFAULT NULL

)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
INSERT INTO C_S_TRS_PTY_RLE_PHN
           (PKEY_SRC_OBJECT, ROWID_OBJECT, DELETED_IND, DELETED_DATE, DELETED_BY, PERIOD_START_DATE, VERSION_SEQ,
            PERIOD_REFERENCE_TIME, TIMELINE_ACTION, LAST_UPDATE_DATE, UPDATED_BY, CREATE_DATE, CREATOR, SRC_ROWID,
            HUB_STATE_IND, PTY_RLE_FK, USG_TP, PHN_TP, PHN_NUM, PREF_LVL, PERIOD_END_DATE, SRC_LAST_UPD_DT)
    SELECT pkey_src_object, NULL, NULL, NULL, NULL, period_start_date, version_seq, NULL, NULL, :P_RUN_TS, NULL,
           period_start_date, NULL, pkey_src_object, NULL, pty_rle_fk, usg_tp, phn_tp, phn_num, pref_lvl,
           NULL, period_start_date
      FROM WRK_TRS_PHN_S5_VERSIONS
     WHERE rn = 1 AND uq_tgt;
    RETURN SQLROWCOUNT;
END;
$$;
