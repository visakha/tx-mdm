-- ============================================================================
-- sp_snow_pub_TRS_REL1_EXC_STG_BAD_REC_MEMB_DATES  --  BARE-BONES PUBLISH BRANCH (TRS)
--
-- Mapping: m_Tgt_C_S_TRS_Pty_Rle_Rel_1_Mem_To_Mem, workflow wf_TRS_Stage_Load_1_Ongoing.
-- Target: EXC_STG_BAD_REC_MEMB. Kind: EXCEPTION (Period dates reversed).
-- Consumes (v2.1 declared inputs): WRK_TRS_REL1_S3_ROUTER.
-- Keeps P_RUN_TS: Y. Original params used: none.
--
-- The INSERT below is the v2.1 branch INSERT verbatim. NO transaction
-- control and NO completion calls in this proc: the driver calls it
-- inside ONE publish transaction (all branches together, so a publish
-- either lands completely or not at all). Returns SQLROWCOUNT.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_pub_TRS_REL1_EXC_STG_BAD_REC_MEMB_DATES (

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
           (SRC_SYS, SRC_SYS_ID_1, SRC_SYS_ID_2, MAPPING_NAME, RUN_DATE, SRC_SYS_ID_3, ATTRIBUTE_NAME,
            PERIOD_START_DATE, PERIOD_END_DATE, EXCEPTION_CODE, EXCEPTION_DESC, EXCEPTION_TYPE)
    SELECT 'TRS', INDV_ID, REF_INDV_ID, :c_mapping, :P_RUN_TS, RELATIONSHIP_TYPE_CD, attr_dates,
           EFF_BEGIN_DT, EFF_END_DT, exc_dates_code, exc_dates_desc, exc_dates_type
      FROM WRK_TRS_REL1_S3_ROUTER
     WHERE dates_reversed AND uq_exc_dates;
    RETURN SQLROWCOUNT;
END;
$$;
