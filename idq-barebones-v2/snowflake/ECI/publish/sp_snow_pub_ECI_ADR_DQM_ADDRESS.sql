-- sp_snow_pub_ECI_ADR_DQM_ADDRESS -- BARE-BONES variant (ECI)
-- Mapping: m_Tgt_C_S_ECI_Pty_Addr, workflow wf_ECI_Stage_Load, publish step 60 (PUBLISH_DQM_ADDRESS).
-- Target: DQM_ADDRESS. Consumes: WRK_ECI_ADR_S50_READY.
-- Called by the driver inside the single publish transaction; no gating, no checkpointing.
-- INSERT below is verbatim from the v2.1 publish procedure.
CREATE OR REPLACE PROCEDURE sp_snow_pub_ECI_ADR_DQM_ADDRESS ()
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
    -- ---- Publish branch 60: PUBLISH_DQM_ADDRESS (verbatim from current main)
    INSERT INTO DQM_ADDRESS
           (MLBLTY_SCR, SRC_ADDR_1, SRC_ADDR_2, SRC_CITY, SRC_STATE, SRC_PSTL_CD, SRC_CNTRY, SRC_COUNTY,
            RSLT_ADDR_1, RSLT_ADDR_2, RSLT_CITY, RSLT_PSTL_CD, RSLT_CNTRY, RSLT_COUNTY, COUNTY_FIPS, STATE_FIPS,
            LATTD, LNGTD, GEOCD_STS_CD, RSDNTL_DLVRY_IND, ORG_NM, ORG_DESC, ORG_DEPT, BLDG, SUB_BLDG,
            ADDRDR_MTCH_CD, ADDRDR_RSLT_PCT, ADDRDR_ADDR_TP_CD, ERLY_WRNG_CD, CASS_ERR_CD, DLVRY_PNT_VLDN,
            MDM_ADDR_TP, SRC_SYSTEM, ADDR_SRC_KEY, LOAD_DT, PTY_SRC_KEY, RSLT_STATE)
    SELECT a_mailability_score, ADDRESS1, ADDRESS2, CITY_NAME, STATE_ABBREV, ZIP_CODE, src_cntry, COUNTY_NAME,
           a_line1, a_line2, a_city, a_postcode_complete, a_country, a_county_fips, a_county_fips,
           a_state_fips, a_latitude, a_longitude, a_geocoding_status, a_residential, a_org_name,
           a_org_descriptor, a_org_department, a_building_complete, a_sub_building_complete, a_match_code,
           a_result_pct, a_address_type, a_early_warning, a_cass_error, a_dpv, mstr_addr_tp, src_sys,
           pkey_src_object, run_ts, pty_src_key, a_state_fips
      FROM WRK_ECI_ADR_S50_READY;
    RETURN SQLROWCOUNT;
END;
$$;
