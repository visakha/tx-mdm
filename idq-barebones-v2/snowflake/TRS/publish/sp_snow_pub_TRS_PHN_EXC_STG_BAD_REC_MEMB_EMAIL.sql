-- ============================================================================
-- sp_snow_pub_TRS_PHN_EXC_STG_BAD_REC_MEMB_EMAIL  --  BARE-BONES PUBLISH BRANCH (TRS)
--
-- Mapping: m_Tgt_C_S_TRS_Pty_Rle_Phn_And_EAddr, workflow wf_TRS_Stage_Load_1_Ongoing.
-- Target: EXC_STG_BAD_REC_MEMB. Kind: EXCEPTION (Invalid emails).
-- Consumes (v2.1 declared inputs): WRK_TRS_PHN_S6_EMAILS.
-- Keeps P_RUN_TS: Y. Original params used: none.
--
-- The INSERT below is the v2.1 branch INSERT verbatim. NO transaction
-- control and NO completion calls in this proc: the driver calls it
-- inside ONE publish transaction (all branches together, so a publish
-- either lands completely or not at all). Returns SQLROWCOUNT.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_pub_TRS_PHN_EXC_STG_BAD_REC_MEMB_EMAIL (

    P_RUN_TS       TIMESTAMP_NTZ DEFAULT NULL

)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    c_mapping VARCHAR DEFAULT 'm_Tgt_C_S_TRS_Pty_Rle_Phn_And_EAddr';
BEGIN
INSERT INTO EXC_STG_BAD_REC_MEMB
           (SRC_SYS, SRC_SYS_ID_1, EXCEPTION_CODE, EXCEPTION_DESC, RUN_DATE, EMAIL, MAPPING_NAME, EXCEPTION_TYPE,
            PERIOD_START_DATE, ATTRIBUTE_VALUE, ATTRIBUTE_NAME, SRC_SYS_ID_2)
    SELECT 'TRS', TO_VARCHAR(INDV_ID), em_exc_code, em_exc_desc, :P_RUN_TS, EMAIL, :c_mapping, em_exc_type,
           CREATE_DT, EMAIL, 'Email', TO_VARCHAR(CASE_NUM)
      FROM WRK_TRS_PHN_S6_EMAILS
     WHERE em_exc_code IS NOT NULL AND uq_exc;
    RETURN SQLROWCOUNT;
END;
$$;
