-- ============================================================================
-- sp_snow_pub_CRE_CARE_EXC_STG_BAD_REC_MEMB_LAST_NAME  --  BARE-BONES PUBLISH BRANCH (CRE)
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
CREATE OR REPLACE PROCEDURE sp_snow_pub_CRE_CARE_EXC_STG_BAD_REC_MEMB_LAST_NAME ()
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
    INSERT INTO EXC_STG_BAD_REC_MEMB
           (SRC_SYS, SRC_SYS_ID_1, RUN_DATE, FIRST_NAME, MAPPING_NAME, BIRTH_DATE, GENDER, ADDRESS_LINE_1,
            ADDRESS_CITY, ADDRESS_COUNTY, ADDRESS_STATE, ADDRESS_ZIP, ADDRESS_ZIP_EXT, ATTRIBUTE_NAME, LAST_NAME,
            SUFFIX, ATTRIBUTE_VALUE, EXCEPTION_CODE, EXCEPTION_DESC, EXCEPTION_TYPE)
    SELECT src_sys, CARE_ID, run_ts, std_first_name, mapping_name, BIRTH_DT, SEX, STREET, CITY, CNTY, STATE,
           ZIP, ZIPSUF, attr_last_name, std_lst_name, std_sfx_name, LASTNM, ln_exception_code,
           ln_exception_desc, ln_exception_type
      FROM WRK_CRE_CARE_S5_KEYED
     WHERE grp_last_name AND uq_last_name;
    RETURN SQLROWCOUNT;
END;
$$;
