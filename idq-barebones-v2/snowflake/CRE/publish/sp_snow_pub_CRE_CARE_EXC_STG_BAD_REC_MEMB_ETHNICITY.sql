-- ============================================================================
-- sp_snow_pub_CRE_CARE_EXC_STG_BAD_REC_MEMB_ETHNICITY  --  BARE-BONES PUBLISH BRANCH (CRE)
--
-- Mapping: m_Tgt_C_S_CRE_CARE_Clients, workflow wf_CRE_Stage_Load_Ongoing.
-- Target: EXC_STG_BAD_REC_MEMB. Consumes WRK_CRE_CARE_S5_KEYED only.
--
-- Bare-bones variant: no parameters. P_RUN_TS is NOT kept: the
-- INSERT reads the run_ts / mapping_name columns materialised
-- in step 50, and references neither an original parameter nor
-- the run timestamp directly. The INSERT below is the v2.1
-- branch INSERT verbatim. No transaction control, no checkpoint.
-- The driver calls it inside ONE publish transaction.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_pub_CRE_CARE_EXC_STG_BAD_REC_MEMB_ETHNICITY ()
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
    INSERT INTO EXC_STG_BAD_REC_MEMB
           (SRC_SYS, SRC_SYS_ID_1, RUN_DATE, ATTRIBUTE_NAME, ATTRIBUTE_VALUE, MAPPING_NAME, EXCEPTION_CODE,
            EXCEPTION_TYPE, EXCEPTION_DESC)
    SELECT src_sys, pty_key, run_ts, attr_fedeth, FEDETH, mapping_name, ethnicity_exception_code,
           ethnicity_exception_type, ethnicity_exception_desc
      FROM WRK_CRE_CARE_S5_KEYED
     WHERE grp_ethnicity;
    RETURN SQLROWCOUNT;
END;
$$;
