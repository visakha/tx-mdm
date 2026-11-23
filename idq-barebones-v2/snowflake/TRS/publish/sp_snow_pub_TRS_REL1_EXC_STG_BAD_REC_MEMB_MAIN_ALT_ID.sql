-- ============================================================================
-- sp_snow_pub_TRS_REL1_EXC_STG_BAD_REC_MEMB_MAIN_ALT_ID  --  BARE-BONES PUBLISH BRANCH (TRS)
--
-- Mapping: m_Tgt_C_S_TRS_Pty_Rle_Rel_1_Mem_To_Mem, workflow wf_TRS_Stage_Load_1_Ongoing.
-- Target: EXC_STG_BAD_REC_MEMB. Kind: EXCEPTION (Invalid main alt id).
-- Consumes (v2.1 declared inputs): WRK_TRS_REL1_S3_ROUTER.
-- Keeps P_RUN_TS: Y. Original params used: none.
--
-- The INSERT below is the v2.1 branch INSERT verbatim. NO transaction
-- control and NO completion calls in this proc: the driver calls it
-- inside ONE publish transaction (all branches together, so a publish
-- either lands completely or not at all). Returns SQLROWCOUNT.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_pub_TRS_REL1_EXC_STG_BAD_REC_MEMB_MAIN_ALT_ID (

    P_RUN_TS       TIMESTAMP_NTZ DEFAULT NULL

)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    c_mapping VARCHAR DEFAULT 'm_Tgt_C_S_TRS_Pty_Rle_Rel_1_Mem_To_Mem';
BEGIN
INSERT INTO EXC_STG_BAD_REC_MEMB
           (SRC_SYS, RUN_DATE, MAPPING_NAME, SRC_SYS_ID_1, SRC_SYS_ID_2, SRC_SYS_ID_3, PERIOD_START_DATE,
            PERIOD_END_DATE, EXCEPTION_DESC, EXCEPTION_TYPE, EXCEPTION_CODE)
    SELECT 'TRS', :P_RUN_TS, :c_mapping, INDV_ID, REF_INDV_ID, rel_type_code, EFF_BEGIN_DT, EFF_END_DT,
           exc_member_desc, exc_member_type, exc_member_code
      FROM WRK_TRS_REL1_S3_ROUTER
     WHERE pty_rle_fk_1 IS NULL AND uq_exc_member;
    RETURN SQLROWCOUNT;
END;
$$;
