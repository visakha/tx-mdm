-- ============================================================================
-- sp_snow_pub_TRS_TOA_EXC_STG_BAD_REC_MEMB_BAD_VALUE  --  BARE-BONES PUBLISH BRANCH (TRS)
--
-- Mapping: m_Tgt_C_S_TRS_Pty_Rle_TOA, workflow wf_TRS_Stage_Load_1_Ongoing.
-- Target: EXC_STG_BAD_REC_MEMB. Kind: EXCEPTION (Bad value).
-- Consumes (v2.1 declared inputs): WRK_TRS_TOA_S40_RANKED.
-- Keeps P_RUN_TS: N. Original params used: none.
--
-- The INSERT below is the v2.1 branch INSERT verbatim. NO transaction
-- control and NO completion calls in this proc: the driver calls it
-- inside ONE publish transaction (all branches together, so a publish
-- either lands completely or not at all). Returns SQLROWCOUNT.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_pub_TRS_TOA_EXC_STG_BAD_REC_MEMB_BAD_VALUE (
)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
INSERT INTO EXC_STG_BAD_REC_MEMB
           (SRC_SYS, RUN_DATE, ATTRIBUTE_NAME, MAPPING_NAME, PERIOD_START_DATE, PERIOD_END_DATE, EXCEPTION_CODE,
            EXCEPTION_DESC, EXCEPTION_TYPE, ATTRIBUTE_VALUE, SRC_SYS_ID_1, SRC_SYS_ID_2, SRC_SYS_ID_3)
    SELECT src_sys, run_ts, attr_toa, mapping_name, BEGIN_DT, END_DT, toa_exc_code, toa_exc_desc,
           toa_exc_type, TYPE_OF_ASSISTANCE_CD, INDV_ID, EDG_NUM, MCI_CREATE_SEQ
      FROM WRK_TRS_TOA_S40_RANKED
     WHERE grp_bad_value AND uq_exc_toa;
    RETURN SQLROWCOUNT;
END;
$$;
