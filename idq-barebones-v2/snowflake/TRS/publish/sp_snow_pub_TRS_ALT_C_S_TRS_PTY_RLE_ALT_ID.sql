-- ============================================================================
-- sp_snow_pub_TRS_ALT_C_S_TRS_PTY_RLE_ALT_ID  --  BARE-BONES PUBLISH BRANCH (TRS)
--
-- Mapping: m_Tgt_C_S_TRS_Pty_Rle_Alt_Id, workflow wf_TRS_Stage_Load_1_Ongoing.
-- Target: C_S_TRS_PTY_RLE_ALT_ID. Kind: SPINE (Valid alt ids).
-- Consumes (v2.1 declared inputs): WRK_TRS_ALT_S4_ROUTED.
-- Keeps P_RUN_TS: Y. Original params used: none.
--
-- The INSERT below is the v2.1 branch INSERT verbatim. NO transaction
-- control and NO completion calls in this proc: the driver calls it
-- inside ONE publish transaction (all branches together, so a publish
-- either lands completely or not at all). Returns SQLROWCOUNT.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_pub_TRS_ALT_C_S_TRS_PTY_RLE_ALT_ID (

    P_RUN_TS       TIMESTAMP_NTZ DEFAULT NULL

)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
INSERT INTO C_S_TRS_PTY_RLE_ALT_ID
           (PKEY_SRC_OBJECT, SRC_ROWID, PERIOD_START_DATE, VERSION_SEQ, LAST_UPDATE_DATE, ALT_ID_TP, ALT_ID_VAL,
            STS_CD, ALT_ID_TP_FLTR, CV_IND, PTY_RLE_FK, ROWID_OBJECT, DELETED_IND, DELETED_DATE, DELETED_BY,
            PERIOD_END_DATE, PERIOD_REFERENCE_TIME, TIMELINE_ACTION, UPDATED_BY, CREATE_DATE, CREATOR,
            HUB_STATE_IND, SRC_LAST_UPD_DT)
    SELECT pkey_src_object_alt_id, pkey_src_object_alt_id, period_start_date, version_seq, :P_RUN_TS,
           alt_id_typ, alt_id_val, sts_cd, alt_id_typ, cv_ind, pty_rle_fk, NULL, NULL, NULL, NULL, NULL,
           NULL, NULL, NULL, period_start_date, NULL, NULL, period_start_date
      FROM WRK_TRS_ALT_S4_ROUTED
     WHERE is_valid AND uq_alt_id;
    RETURN SQLROWCOUNT;
END;
$$;
