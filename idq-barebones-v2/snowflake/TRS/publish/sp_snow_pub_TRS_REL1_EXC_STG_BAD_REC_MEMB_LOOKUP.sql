-- ============================================================================
-- sp_snow_pub_TRS_REL1_EXC_STG_BAD_REC_MEMB_LOOKUP  --  BARE-BONES PUBLISH BRANCH (TRS)
--
-- Mapping: m_Tgt_C_S_TRS_Pty_Rle_Rel_1_Mem_To_Mem, workflow wf_TRS_Stage_Load_1_Ongoing.
-- Target: EXC_STG_BAD_REC_MEMB. Kind: EXCEPTION (Invalid lookup).
-- Consumes (v2.1 declared inputs): WRK_TRS_REL1_S3_ROUTER.
-- Keeps P_RUN_TS: Y. Original params used: none.
--
-- The INSERT below is the v2.1 branch INSERT verbatim. NO transaction
-- control and NO completion calls in this proc: the driver calls it
-- inside ONE publish transaction (all branches together, so a publish
-- either lands completely or not at all). Returns SQLROWCOUNT.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_pub_TRS_REL1_EXC_STG_BAD_REC_MEMB_LOOKUP (

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
           (SRC_SYS, SRC_SYS_ID_1, SRC_SYS_ID_2, MAPPING_NAME, RUN_DATE, SRC_SYS_ID_3, ATTRIBUTE_VALUE,
            ATTRIBUTE_NAME, PERIOD_START_DATE, PERIOD_END_DATE, EXCEPTION_TYPE, EXCEPTION_DESC, EXCEPTION_CODE)
    SELECT 'TRS', INDV_ID, REF_INDV_ID, :c_mapping, :P_RUN_TS, RELATIONSHIP_TYPE_CD, RELATIONSHIP_TYPE_CD,
           attr_rel_type, EFF_BEGIN_DT, EFF_END_DT, exc_type_type, exc_type_desc, exc_type_lkp_code
      FROM WRK_TRS_REL1_S3_ROUTER
     WHERE rel_type_code IS NULL AND uq_exc_type;
    RETURN SQLROWCOUNT;
END;
$$;
