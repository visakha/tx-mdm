-- ============================================================================
-- sp_snow_pub_TRS_REL2_EXC_STG_BAD_REC_MEMB_DEFAULT  --  BARE-BONES PUBLISH BRANCH (TRS)
--
-- Mapping: m_Tgt_C_S_TRS_Pty_Rle_Rel_2_Mem_To_PCP, workflow wf_TRS_Stage_Load_1_Ongoing.
-- Target: EXC_STG_BAD_REC_MEMB. Kind: EXCEPTION (Default exception).
-- Consumes (v2.1 declared inputs): WRK_TRS_REL2_S3_ROUTER.
-- Keeps P_RUN_TS: Y. Original params used: none.
--
-- The INSERT below is the v2.1 branch INSERT verbatim. NO transaction
-- control and NO completion calls in this proc: the driver calls it
-- inside ONE publish transaction (all branches together, so a publish
-- either lands completely or not at all). Returns SQLROWCOUNT.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_pub_TRS_REL2_EXC_STG_BAD_REC_MEMB_DEFAULT (

    P_RUN_TS       TIMESTAMP_NTZ DEFAULT NULL

)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    c_mapping VARCHAR DEFAULT 'm_Tgt_C_S_TRS_Pty_Rle_Rel_2_Mem_To_PCP';
BEGIN
INSERT INTO EXC_STG_BAD_REC_MEMB
           (SRC_SYS, RUN_DATE, MAPPING_NAME, EXCEPTION_CODE, EXCEPTION_DESC, EXCEPTION_TYPE, PERIOD_START_DATE,
            PERIOD_END_DATE, SRC_SYS_ID_1, SRC_SYS_ID_2, ATTRIBUTE_VALUE, ATTRIBUTE_NAME)
    SELECT 'TRS', :P_RUN_TS, :c_mapping, exc_default_code, exc_default_desc, exc_default_type, BEGIN_DT,
           END_DT, INDV_ID, PROVIDER_NUM, PROVIDER_NUM, attr_provider
      FROM WRK_TRS_REL2_S3_ROUTER
     WHERE NOT is_valid AND NOT dates_reversed AND uq_exc_default;
    RETURN SQLROWCOUNT;
END;
$$;
