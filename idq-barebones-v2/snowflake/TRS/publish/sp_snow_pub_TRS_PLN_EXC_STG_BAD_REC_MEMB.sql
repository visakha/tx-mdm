-- ============================================================================
-- sp_snow_pub_TRS_PLN_EXC_STG_BAD_REC_MEMB  --  BARE-BONES PUBLISH BRANCH (TRS)
--
-- Mapping: m_Tgt_C_S_TRS_Pty_Rle_Pln, workflow wf_TRS_Stage_Load_1_Ongoing.
-- Target: EXC_STG_BAD_REC_MEMB. Kind: EXCEPTION (Invalid plans).
-- Consumes (v2.1 declared inputs): WRK_TRS_PLN_S30_RANKED.
-- Keeps P_RUN_TS: N. Original params used: none.
--
-- The INSERT below is the v2.1 branch INSERT verbatim. NO transaction
-- control and NO completion calls in this proc: the driver calls it
-- inside ONE publish transaction (all branches together, so a publish
-- either lands completely or not at all). Returns SQLROWCOUNT.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_pub_TRS_PLN_EXC_STG_BAD_REC_MEMB (
)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
INSERT INTO EXC_STG_BAD_REC_MEMB
           (SRC_SYS, SRC_SYS_ID_1, EXCEPTION_TYPE, EXCEPTION_DESC, EXCEPTION_CODE, ATTRIBUTE_VALUE,
            ATTRIBUTE_NAME, MAPPING_NAME, RUN_DATE, PERIOD_START_DATE, SRC_SYS_ID_2)
    SELECT src_sys, INDV_ID, exc_type, exc_desc, exc_code, MC_PLAN, attr_plan, mapping_name, run_ts,
           BEGIN_DT, begin_dt_text
      FROM WRK_TRS_PLN_S30_RANKED
     WHERE pln_mstr_cd IS NULL AND rn_invalid = 1;
    RETURN SQLROWCOUNT;
END;
$$;
