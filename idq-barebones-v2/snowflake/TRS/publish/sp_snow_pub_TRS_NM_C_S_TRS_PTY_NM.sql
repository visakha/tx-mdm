-- ============================================================================
-- sp_snow_pub_TRS_NM_C_S_TRS_PTY_NM  --  BARE-BONES PUBLISH BRANCH (TRS)
--
-- Mapping: m_Tgt_C_S_TRS_Pty_Nm, workflow wf_TRS_Stage_Load_1_Ongoing.
-- Target: C_S_TRS_PTY_NM. Kind: SPINE (Alias names).
-- Consumes (v2.1 declared inputs): WRK_TRS_NM_S40_DEDUP.
-- Keeps P_RUN_TS: Y. Original params used: P_MEMBER_NAME_TYPE_CODE.
--
-- The INSERT below is the v2.1 branch INSERT verbatim. NO transaction
-- control and NO completion calls in this proc: the driver calls it
-- inside ONE publish transaction (all branches together, so a publish
-- either lands completely or not at all). Returns SQLROWCOUNT.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_pub_TRS_NM_C_S_TRS_PTY_NM (

    P_MEMBER_NAME_TYPE_CODE VARCHAR DEFAULT '002',
    P_RUN_TS       TIMESTAMP_NTZ DEFAULT NULL

)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
INSERT INTO C_S_TRS_PTY_NM
           (PTY_FK, SFX_NM, FRST_NM, PFX_NM, LST_NM, MDL_NM, FULL_NM, VERSION_SEQ, LAST_UPDATE_DATE, NM_TP, SRC_ROWID,
            ROWID_OBJECT, DELETED_IND, DELETED_DATE, DELETED_BY, PERIOD_END_DATE, PERIOD_REFERENCE_TIME, UPDATED_BY,
            CREATE_DATE, CREATOR, HUB_STATE_IND, SRC_FULL_NM, SRC_LAST_UPD_DT, PKEY_SRC_OBJECT, PERIOD_START_DATE)
    SELECT d.PKEY_PTY, d.sfx_nm, d.frst_nm, d.prfx_nm, d.lst_nm, d.mdl_nm, d.full_nm,
           1, :P_RUN_TS, :P_MEMBER_NAME_TYPE_CODE, d.pkey_src_object,
           NULL, NULL, NULL, NULL, NULL, NULL, NULL, d.CREATE_DT, NULL,
           NULL, d.src_full_name, d.CREATE_DT, d.pkey_src_object,
           d.CREATE_DT
      FROM WRK_TRS_NM_S40_DEDUP d
      LEFT JOIN (SELECT DISTINCT PKEY_SRC_OBJECT FROM C_S_TRS_PTY_NM WHERE VERSION_SEQ = 1) xn
             ON xn.PKEY_SRC_OBJECT = d.pkey_src_object
     WHERE xn.PKEY_SRC_OBJECT IS NULL
    QUALIFY ROW_NUMBER() OVER (PARTITION BY d.pkey_src_object ORDER BY d.CREATE_DT DESC NULLS LAST, d.full_nm) = 1;
    RETURN SQLROWCOUNT;
END;
$$;
