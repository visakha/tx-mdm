-- ============================================================================
-- sp_snow_pub_TRS_REL2_C_S_TRS_PTY_RLE_REL_PROV  --  BARE-BONES PUBLISH BRANCH (TRS)
--
-- Mapping: m_Tgt_C_S_TRS_Pty_Rle_Rel_2_Mem_To_PCP, workflow wf_TRS_Stage_Load_1_Ongoing.
-- Target: C_S_TRS_PTY_RLE_REL_PROV. Kind: SPINE (Valid PCP relationships).
-- Consumes (v2.1 declared inputs): WRK_TRS_REL2_S6_TIMELINE.
-- Keeps P_RUN_TS: Y. Original params used: P_PCP_REL_TP.
--
-- The INSERT below is the v2.1 branch INSERT verbatim. NO transaction
-- control and NO completion calls in this proc: the driver calls it
-- inside ONE publish transaction (all branches together, so a publish
-- either lands completely or not at all). Returns SQLROWCOUNT.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_pub_TRS_REL2_C_S_TRS_PTY_RLE_REL_PROV (

    P_PCP_REL_TP VARCHAR DEFAULT '100',
    P_RUN_TS       TIMESTAMP_NTZ DEFAULT NULL

)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
INSERT INTO C_S_TRS_PTY_RLE_REL_PROV
           (PKEY_SRC_OBJECT, PERIOD_START_DATE, PERIOD_END_DATE, VERSION_SEQ, LAST_UPDATE_DATE, CREATE_DATE,
            SRC_ROWID, HUB_STATE_IND, PTY_RLE_FK_1, PTY_RLE_FK_2, REL_TYPE_CODE, HIERARCHY_CODE, REL_TP,
            SRC_LAST_UPD_DT, PERIOD_REFERENCE_TIME, TIMELINE_ACTION, ROWID_OBJECT, DELETED_IND, DELETED_DATE,
            DELETED_BY, UPDATED_BY, CREATOR)
    SELECT pkey_src_object, BEGIN_DT, tl_period_end_date, tl_version_seq, :P_RUN_TS, NULL, pkey_src_object,
           tl_hub_state_ind, pty_rle_fk_1, pty_rle_fk_2, rel_type_code, 'Member', :P_PCP_REL_TP, CREATE_DT,
           tl_period_end_date, tl_timeline_action, NULL, NULL, NULL, NULL, NULL, NULL
      FROM WRK_TRS_REL2_S6_TIMELINE
     WHERE uq_rel;
    RETURN SQLROWCOUNT;
END;
$$;
