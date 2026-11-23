-- ============================================================================
-- sp_snow_pub_CRE_CARE_EXC_STG_BAD_REC_MEMB_ADDR  --  BARE-BONES PUBLISH BRANCH (CRE)
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
CREATE OR REPLACE PROCEDURE sp_snow_pub_CRE_CARE_EXC_STG_BAD_REC_MEMB_ADDR ()
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
    INSERT INTO EXC_STG_BAD_REC_MEMB
           (SRC_SYS, RUN_DATE, MAPPING_NAME, ADDRESS_DR_MAILABILITY_SCORE, ADDRESS_DR_ERROR_DESC,
            ADDRESS_DR_ERROR_CODE, ATTRIBUTE_NAME, ATTRIBUTE_VALUE, SRC_SYS_ID_1, ADDRESS_LINE_1, ADDRESS_CITY,
            ADDRESS_COUNTY, ADDRESS_STATE, ADDRESS_ZIP, ADDRESS_ZIP_EXT, ADDRESS_COUNTRY, EXCEPTION_CODE,
            EXCEPTION_DESC, EXCEPTION_TYPE)
    SELECT src_sys, run_ts, mapping_name, a_dr_mailability_score, a_dr_error_desc, a_dr_error_code,
           attr_address, addr_attribute_value, CARE_ID, STREET, CITY, CNTY, STATE, ZIP, ZIPSUF, src_cntry,
           addr_exception_code, addr_exception_desc, addr_exception_type
      FROM WRK_CRE_CARE_S5_KEYED
     WHERE grp_addr_exc;
    RETURN SQLROWCOUNT;
END;
$$;
