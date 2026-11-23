-- ============================================================================
-- sp_snow_pub_TRS_TOA_EXC_STG_BAD_REC_MEMB_DATES  --  BARE-BONES PUBLISH BRANCH (TRS)
--
-- Mapping: m_Tgt_C_S_TRS_Pty_Rle_TOA, workflow wf_TRS_Stage_Load_1_Ongoing.
-- Target: EXC_STG_BAD_REC_MEMB. Kind: EXCEPTION (Inverted dates).
-- Consumes (v2.1 declared inputs): WRK_TRS_TOA_S40_RANKED.
-- Keeps P_RUN_TS: N. Original params used: none.
--
-- The INSERT below is the v2.1 branch INSERT verbatim. NO transaction
-- control and NO completion calls in this proc: the driver calls it
-- inside ONE publish transaction (all branches together, so a publish
-- either lands completely or not at all). Returns SQLROWCOUNT.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_pub_TRS_TOA_EXC_STG_BAD_REC_MEMB_DATES (
)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
INSERT INTO EXC_STG_BAD_REC_MEMB
           (SRC_SYS_ID_1, SRC_SYS_ID_2, MAPPING_NAME, RUN_DATE, ATTRIBUTE_NAME, PERIOD_START_DATE,
            PERIOD_END_DATE, SRC_SYS, EXCEPTION_DESC, EXCEPTION_TYPE, EXCEPTION_CODE)
    SELECT pkey_src_object, pty_rle_fk, mapping_name, run_ts, attr_dates, BEGIN_DT, END_DT, src_sys,
           date_exc_desc, date_exc_type, date_exc_code
      FROM WRK_TRS_TOA_S40_RANKED
     WHERE grp_dates AND uq_exc_dates;
    RETURN SQLROWCOUNT;
END;
$$;
