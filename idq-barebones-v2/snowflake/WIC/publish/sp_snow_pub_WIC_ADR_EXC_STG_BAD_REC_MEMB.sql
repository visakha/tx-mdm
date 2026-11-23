-- ============================================================================
-- sp_snow_pub_WIC_ADR_EXC_STG_BAD_REC_MEMB  --  BARE-BONES STEP DRIVER VARIANT (WIC)
--
-- Mapping: m_Tgt_C_S_WIC_Pty_Addr, workflow wf_WIC_Stage_Load.
-- Target: EXC_STG_BAD_REC_MEMB. Kind: EXCEPTION (exception addresses).
-- WHERE guard: score = '40' AND uq_addr_exc.
-- Reads ONLY WRK_WIC_ADDR_S40_SCORED. Reads the run_ts / mapping_name columns materialised in the final step; it takes no parameters.
--
-- Bare-bones variant: stripped of config gating, job tracking and
-- input checks; the INSERT below is unchanged business SQL. No
-- transaction control in this proc: the driver calls it inside ONE
-- publish transaction covering all branches.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_pub_WIC_ADR_EXC_STG_BAD_REC_MEMB (
)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
    INSERT INTO EXC_STG_BAD_REC_MEMB
           (SRC_SYS, ADDRESS_DR_ERROR_CODE, ADDRESS_DR_ERROR_DESC, ADDRESS_DR_MAILABILITY_SCORE,
            ATTRIBUTE_NAME, ATTRIBUTE_VALUE, MAPPING_NAME, ADDRESS_TYPE, PERIOD_START_DATE, PERIOD_END_DATE,
            EXCEPTION_CODE, EXCEPTION_DESC, RUN_DATE, EXCEPTION_TYPE, ADDRESS_LINE_1, ADDRESS_LINE_2,
            ADDRESS_CITY, ADDRESS_COUNTY, ADDRESS_STATE, ADDRESS_ZIP, ADDRESS_ZIP_EXT, ADDRESS_COUNTRY,
            SRC_SYS_ID_1, SRC_SYS_ID_2, SRC_SYS_ID_3)
    SELECT src_sys, a_match_code, a_match_code_description, a_mailability_score, exc_attribute_name,
           exc_attribute_value, mapping_name, addr_tp, DATE_ADDRESS_VALID_FROM, NULL, exc_code, exc_desc,
           run_ts, exc_type, ADDRESS1, ADDRESS2, CITY, COUNTY, NULL, ZIP_CODE, NULL, src_cntry, ID, FID,
           SOURCE_TABLE
      FROM WRK_WIC_ADDR_S40_SCORED
     WHERE score = '40' AND uq_addr_exc;
    RETURN SQLROWCOUNT;
END;
$$;
