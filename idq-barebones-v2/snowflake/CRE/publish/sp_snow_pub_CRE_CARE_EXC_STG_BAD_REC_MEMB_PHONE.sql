-- ============================================================================
-- sp_snow_pub_CRE_CARE_EXC_STG_BAD_REC_MEMB_PHONE  --  BARE-BONES PUBLISH BRANCH (CRE)
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
CREATE OR REPLACE PROCEDURE sp_snow_pub_CRE_CARE_EXC_STG_BAD_REC_MEMB_PHONE ()
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
    INSERT INTO EXC_STG_BAD_REC_MEMB
           (SRC_SYS, PRIMARY_PHONE, MAPPING_NAME, RUN_DATE, ATTRIBUTE_NAME, ATTRIBUTE_VALUE, SRC_SYS_ID_1,
            EXCEPTION_CODE, EXCEPTION_TYPE, EXCEPTION_DESC)
    SELECT src_sys, phone_std, mapping_name, run_ts, attr_phone, phone_std, CARE_ID, phone_exception_code,
           phone_exception_type, phone_exception_desc
      FROM WRK_CRE_CARE_S5_KEYED
     WHERE grp_phone_exc;
    RETURN SQLROWCOUNT;
END;
$$;
