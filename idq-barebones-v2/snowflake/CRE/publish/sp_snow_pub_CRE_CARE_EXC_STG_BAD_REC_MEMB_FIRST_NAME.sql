-- ============================================================================
-- sp_snow_pub_CRE_CARE_EXC_STG_BAD_REC_MEMB_FIRST_NAME  --  BARE-BONES PUBLISH BRANCH (CRE)
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
CREATE OR REPLACE PROCEDURE sp_snow_pub_CRE_CARE_EXC_STG_BAD_REC_MEMB_FIRST_NAME ()
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
    INSERT INTO EXC_STG_BAD_REC_MEMB
           (SRC_SYS_ID_1, RUN_DATE, MAPPING_NAME, FIRST_NAME, LAST_NAME, ATTRIBUTE_NAME, GENDER, BIRTH_DATE,
            SUFFIX, SRC_SYS, ATTRIBUTE_VALUE, EXCEPTION_TYPE, EXCEPTION_DESC, EXCEPTION_CODE)
    SELECT CARE_ID, run_ts, mapping_name, std_first_name, std_lst_name, attr_first_name, SEX, BIRTH_DT,
           std_sfx_name, src_sys, FIRSTNM, fn_exception_type, fn_exception_desc, fn_exception_code
      FROM WRK_CRE_CARE_S5_KEYED
     WHERE grp_first_name AND uq_first_name;
    RETURN SQLROWCOUNT;
END;
$$;
