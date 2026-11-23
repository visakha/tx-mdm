-- ============================================================================
-- sp_snow_pub_TRS_ADDR2_EXC_STG_BAD_REC_MEMB  --  BARE-BONES PUBLISH BRANCH (TRS)
--
-- Mapping: m_Tgt_C_S_TRS_Addr_2, workflow wf_TRS_Stage_Load_1_Ongoing.
-- Target: EXC_STG_BAD_REC_MEMB. Kind: EXCEPTION (Score 40 exceptions).
-- Consumes (v2.1 declared inputs): WRK_TRS_ADDR2_S50_READY.
-- Keeps P_RUN_TS: N. Original params used: none.
--
-- The INSERT below is the v2.1 branch INSERT verbatim. NO transaction
-- control and NO completion calls in this proc: the driver calls it
-- inside ONE publish transaction (all branches together, so a publish
-- either lands completely or not at all). Returns SQLROWCOUNT.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_pub_TRS_ADDR2_EXC_STG_BAD_REC_MEMB (
)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
INSERT INTO EXC_STG_BAD_REC_MEMB
           (SRC_SYS, ADDRESS_DR_ERROR_CODE, ADDRESS_DR_ERROR_DESC, ADDRESS_DR_MAILABILITY_SCORE, ATTRIBUTE_NAME,
            ATTRIBUTE_VALUE, MAPPING_NAME, ADDRESS_TYPE, PERIOD_START_DATE, PERIOD_END_DATE, RUN_DATE,
            ADDRESS_LINE_1, ADDRESS_LINE_2, ADDRESS_CITY, ADDRESS_COUNTY, ADDRESS_STATE, ADDRESS_ZIP,
            ADDRESS_ZIP_EXT, ADDRESS_COUNTRY, SRC_SYS_ID_1, SRC_SYS_ID_2, SRC_SYS_ID_3, EXCEPTION_CODE,
            EXCEPTION_DESC, EXCEPTION_TYPE)
    SELECT src_sys, VLDTN_MSG, VLDTN_DESC, MLBLTY_SCR, exc_attribute_name, exc_attribute_value, mapping_name,
           ADDR_TYPE_CD, EFF_BEGIN_DT, EFF_END_DT, run_ts, SRC_ADDR_LN_1, SRC_ADDR_LN_2, SRC_CITY,
           SRC_COUNTY, SRC_STATE, SRC_PSTL_CD, SRC_PSTL_CD_EXT, SRC_CNTRY, INDV_ID, CASE_NUM, EDG_NUM,
           exc_code, exc_desc, exc_type
      FROM WRK_TRS_ADDR2_S50_READY
     WHERE score = '40' AND uq_addr_exc;
    RETURN SQLROWCOUNT;
END;
$$;
