-- ============================================================================
-- sp_snow_pub_WIC_ADR_DQM_ADDRESS  --  BARE-BONES STEP DRIVER VARIANT (WIC)
--
-- Mapping: m_Tgt_C_S_WIC_Pty_Addr, workflow wf_WIC_Stage_Load.
-- Target: DQM_ADDRESS. Kind: VALIDATION (every active address (address-quality table).
-- WHERE guard: (unconditional).
-- Reads ONLY WRK_WIC_ADDR_S40_SCORED. Reads the run_ts / mapping_name columns materialised in the final step; it takes no parameters.
--
-- Bare-bones variant: stripped of config gating, job tracking and
-- input checks; the INSERT below is unchanged business SQL. No
-- transaction control in this proc: the driver calls it inside ONE
-- publish transaction covering all branches.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_pub_WIC_ADR_DQM_ADDRESS (
)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
    INSERT INTO DQM_ADDRESS
           (MLBLTY_SCR, SRC_ADDR_1, SRC_ADDR_2, SRC_CITY, SRC_STATE, SRC_PSTL_CD, SRC_CNTRY, SRC_COUNTY,
            RSLT_ADDR_1, RSLT_ADDR_2, RSLT_CITY, RSLT_PSTL_CD, RSLT_CNTRY, RSLT_COUNTY, COUNTY_FIPS, STATE_FIPS,
            LATTD, LNGTD, GEOCD_STS_CD, RSDNTL_DLVRY_IND, ORG_NM, ORG_DESC, ORG_DEPT, BLDG, SUB_BLDG,
            ADDRDR_MTCH_CD, ADDRDR_RSLT_PCT, ADDRDR_ADDR_TP_CD, ERLY_WRNG_CD, CASS_ERR_CD, DLVRY_PNT_VLDN,
            MDM_ADDR_TP, SRC_SYSTEM, ADDR_SRC_KEY, LOAD_DT, PTY_SRC_KEY, RSLT_STATE)
    SELECT a_mailability_score, ADDRESS1, ADDRESS2, CITY, NULL, ZIP_CODE, src_cntry, COUNTY,
           a_line1, a_line2, a_city, a_postcode_complete, a_country, a_county_fips, a_county_fips,
           a_state_fips, a_latitude, a_longitude, a_geocoding_status, a_residential, a_org_name,
           a_org_descriptor, a_org_department, a_building_complete, a_sub_building_complete, a_match_code,
           a_result_pct, a_address_type, a_early_warning, a_cass_error, a_dpv, addr_tp, src_sys,
           pkey_src_object, run_ts, dqm_pty_src_key, a_state_fips
      FROM WRK_WIC_ADDR_S40_SCORED;
    RETURN SQLROWCOUNT;
END;
$$;
