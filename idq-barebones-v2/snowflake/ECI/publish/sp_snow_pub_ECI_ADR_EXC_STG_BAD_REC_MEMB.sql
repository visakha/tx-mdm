-- sp_snow_pub_ECI_ADR_EXC_STG_BAD_REC_MEMB -- BARE-BONES variant (ECI)
-- Mapping: m_Tgt_C_S_ECI_Pty_Addr, workflow wf_ECI_Stage_Load, publish step 80 (PUBLISH_EXC_STG_BAD_REC_MEMB).
-- Target: EXC_STG_BAD_REC_MEMB. Consumes: WRK_ECI_ADR_S50_READY.
-- Called by the driver inside the single publish transaction; no gating, no checkpointing.
-- INSERT below is verbatim from the v2.1 publish procedure.
CREATE OR REPLACE PROCEDURE sp_snow_pub_ECI_ADR_EXC_STG_BAD_REC_MEMB ()
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
    -- ---- Publish branch 80: PUBLISH_EXC_STG_BAD_REC_MEMB (verbatim from current main)
    INSERT INTO EXC_STG_BAD_REC_MEMB
           (SRC_SYS, ADDRESS_DR_ERROR_CODE, ADDRESS_DR_ERROR_DESC, ADDRESS_DR_MAILABILITY_SCORE,
            ATTRIBUTE_NAME, ATTRIBUTE_VALUE, MAPPING_NAME, ADDRESS_TYPE, PERIOD_START_DATE, PERIOD_END_DATE,
            EXCEPTION_CODE, EXCEPTION_DESC, RUN_DATE, EXCEPTION_TYPE, ADDRESS_LINE_1, ADDRESS_LINE_2,
            ADDRESS_CITY, ADDRESS_COUNTY, ADDRESS_STATE, ADDRESS_ZIP, ADDRESS_ZIP_EXT, ADDRESS_COUNTRY,
            SRC_SYS_ID_1, SRC_SYS_ID_2, SRC_SYS_ID_3)
    SELECT src_sys, a_match_code, a_match_code_description, a_mailability_score, exc_attribute_name,
           exc_attribute_value, mapping_name, ADDRESS_CD, LAST_UPDATE_DATE, NULL, exc_code, exc_desc,
           run_ts, exc_type, ADDRESS1, ADDRESS2, CITY_NAME, COUNTY_NAME, STATE_ABBREV, ZIP_CODE, ZIP_SFX,
           src_cntry, ID, ID_FAMILY_ADDRESS, SOURCE_TABLE
      FROM WRK_ECI_ADR_S50_READY
     WHERE score = '40' AND uq_addr_exc;
    RETURN SQLROWCOUNT;
END;
$$;
