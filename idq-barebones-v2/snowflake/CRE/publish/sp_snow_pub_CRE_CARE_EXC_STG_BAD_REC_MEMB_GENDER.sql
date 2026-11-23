-- ============================================================================
-- sp_snow_pub_CRE_CARE_EXC_STG_BAD_REC_MEMB_GENDER  --  BARE-BONES PUBLISH BRANCH (CRE)
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
CREATE OR REPLACE PROCEDURE sp_snow_pub_CRE_CARE_EXC_STG_BAD_REC_MEMB_GENDER ()
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
    INSERT INTO EXC_STG_BAD_REC_MEMB
           (SRC_SYS, SRC_SYS_ID_1, RUN_DATE, GENDER, ATTRIBUTE_NAME, ATTRIBUTE_VALUE, MAPPING_NAME,
            EXCEPTION_TYPE, EXCEPTION_CODE, EXCEPTION_DESC)
    SELECT src_sys, CARE_ID, run_ts, SEX, attr_gender, SEX, mapping_name, gender_exception_type,
           gender_exception_code, gender_exception_description
      FROM WRK_CRE_CARE_S5_KEYED
     WHERE grp_gender;
    RETURN SQLROWCOUNT;
END;
$$;
