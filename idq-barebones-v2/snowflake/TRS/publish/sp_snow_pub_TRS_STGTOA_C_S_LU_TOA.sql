-- ============================================================================
-- sp_snow_pub_TRS_STGTOA_C_S_LU_TOA  --  BARE-BONES PUBLISH BRANCH (TRS)
--
-- Mapping: m_Tgt_C_S_TRS_Stg_TOA, workflow wf_TRS_Stage_Load_TOA.
-- Target: C_S_LU_TOA. Kind: STATUS (TOA catalogue survivors).
-- Consumes (v2.1 declared inputs): WRK_TRS_LUTOA_S20_FINAL.
-- Keeps P_RUN_TS: Y. Original params used: none.
--
-- The INSERT below is the v2.1 branch INSERT verbatim. NO transaction
-- control and NO completion calls in this proc: the driver calls it
-- inside ONE publish transaction (all branches together, so a publish
-- either lands completely or not at all). Returns SQLROWCOUNT.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_pub_TRS_STGTOA_C_S_LU_TOA (

    P_RUN_TS       TIMESTAMP_NTZ DEFAULT NULL

)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
INSERT INTO C_S_LU_TOA
           (PKEY_SRC_OBJECT, ROWID_OBJECT, DELETED_IND, DELETED_DATE, DELETED_BY, PERIOD_START_DATE, PERIOD_END_DATE,
            VERSION_SEQ, PERIOD_REFERENCE_TIME, LAST_UPDATE_DATE, UPDATED_BY, CREATE_DATE, CREATOR, SRC_ROWID,
            HUB_STATE_IND, TOA_CD, TOA_LBL, TOA_DESC, MBR_PRG_CD, EFF_STRT_DT, EFF_END_DT)
    SELECT pkey_src_object, NULL, NULL, NULL, NULL, NULL, NULL,
           1, NULL, :P_RUN_TS, SUBSTR(UPDATE_USER_ID, 1, 50), CREATE_DT, 'admin', SUBSTR(pkey_src_object, 1, 30),
           1, pkey_src_object, SUBSTR(toa_lbl, 1, 100), SUBSTR(TOA_DESC, 1, 250), mbr_prg_cd, EFF_BEGIN_DT, EFF_END_DT
      FROM WRK_TRS_LUTOA_S20_FINAL;
    RETURN SQLROWCOUNT;
END;
$$;
