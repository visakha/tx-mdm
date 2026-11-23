-- ============================================================================
-- sp_snow_pub_TRS_REL1_C_S_TRS_PTY_RLE_REL  --  BARE-BONES PUBLISH BRANCH (TRS)
--
-- Mapping: m_Tgt_C_S_TRS_Pty_Rle_Rel_1_Mem_To_Mem, workflow wf_TRS_Stage_Load_1_Ongoing.
-- Target: C_S_TRS_PTY_RLE_REL. Kind: SPINE (Valid relationships).
-- Consumes (v2.1 declared inputs): WRK_TRS_REL1_S6_TIMELINE.
-- Keeps P_RUN_TS: Y. Original params used: none.
--
-- The INSERT below is the v2.1 branch INSERT verbatim. NO transaction
-- control and NO completion calls in this proc: the driver calls it
-- inside ONE publish transaction (all branches together, so a publish
-- either lands completely or not at all). Returns SQLROWCOUNT.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_pub_TRS_REL1_C_S_TRS_PTY_RLE_REL (

    P_RUN_TS       TIMESTAMP_NTZ DEFAULT NULL

)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
INSERT INTO C_S_TRS_PTY_RLE_REL
           (PKEY_SRC_OBJECT, ROWID_OBJECT, DELETED_IND, DELETED_DATE, DELETED_BY, PERIOD_START_DATE,
            PERIOD_END_DATE, VERSION_SEQ, PERIOD_REFERENCE_TIME, TIMELINE_ACTION, LAST_UPDATE_DATE, UPDATED_BY,
            CREATE_DATE, CREATOR, SRC_ROWID, HUB_STATE_IND, PTY_RLE_FK_1, PTY_RLE_FK_2, REL_TYPE_CODE,
            HIERARCHY_CODE, REL_TP, SRC_LAST_UPD_DT)
    SELECT pkey_src_object, NULL, NULL, NULL, NULL, EFF_BEGIN_DT, tl_period_end_date, tl_version_seq,
           tl_period_end_date, tl_timeline_action, :P_RUN_TS, NULL, CREATE_DT, NULL, pkey_src_object,
           tl_hub_state_ind, pty_rle_fk_1, pty_rle_fk_2, rel_type_code_label, hierarchy_code, rel_type_code,
           src_last_upd_dt
      FROM WRK_TRS_REL1_S6_TIMELINE
     WHERE uq_rel;
    RETURN SQLROWCOUNT;
END;
$$;
