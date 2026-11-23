-- ============================================================================
-- sp_snow_pub_TRS_PTY_C_S_TRS_PTY_RLE  --  BARE-BONES PUBLISH BRANCH (TRS)
--
-- Mapping: m_Tgt_C_S_TRS_Pty_OnGoing, workflow wf_TRS_Stage_Load_1_Ongoing.
-- Target: C_S_TRS_PTY_RLE. Kind: SPINE (Valid roles).
-- Consumes (v2.1 declared inputs): WRK_TRS_PTY_S4_DEDUP.
-- Keeps P_RUN_TS: Y. Original params used: P_RLE_BO_CLASS_CD_MEMBER.
--
-- The INSERT below is the v2.1 branch INSERT verbatim. NO transaction
-- control and NO completion calls in this proc: the driver calls it
-- inside ONE publish transaction (all branches together, so a publish
-- either lands completely or not at all). Returns SQLROWCOUNT.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_pub_TRS_PTY_C_S_TRS_PTY_RLE (

    P_RLE_BO_CLASS_CD_MEMBER VARCHAR DEFAULT 'Member',
    P_RUN_TS       TIMESTAMP_NTZ DEFAULT NULL

)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
INSERT INTO C_S_TRS_PTY_RLE
           (PTY_FK, PKEY_SRC_OBJECT, ROWID_OBJECT, DELETED_IND, DELETED_DATE, DELETED_BY, RLE_BO_CLASS_CD,
            VERSION_SEQ, PERIOD_END_DATE, PERIOD_START_DATE, TIMELINE_ACTION, PERIOD_REFERENCE_TIME, UPDATED_BY,
            CREATE_DATE, CREATOR, SRC_LAST_UPD_DT, HUB_STATE_IND, SRC_ROWID, LAST_UPDATE_DATE)
    SELECT pkey_trim, pkey_trim || '|' || :P_RLE_BO_CLASS_CD_MEMBER, NULL, NULL, NULL, NULL,
           :P_RLE_BO_CLASS_CD_MEMBER, 1, NULL, CREATE_DT, NULL,
           NULL, NULL, NULL, NULL, CREATE_DT, NULL, pkey_trim || '|' || :P_RLE_BO_CLASS_CD_MEMBER, :P_RUN_TS
      FROM WRK_TRS_PTY_S4_DEDUP
     WHERE rn_pty = 1 AND uq_rle;
    RETURN SQLROWCOUNT;
END;
$$;
