-- ============================================================================
-- sp_snow_step_TRS_ADDR1_S40_READY  --  BARE-BONES STEP (TRS)
--
-- Mapping: m_Tgt_C_S_TRS_Addr_1, workflow wf_TRS_Stage_Load_1_Ongoing.
-- Step name: READY_TO_PUBLISH. Produces: WRK_TRS_ADDR1_S40_READY.
-- Consumes (v2.1 declared inputs): WRK_TRS_ADDR1_S30_VALIDATED.
-- Original params used: none; plus P_RUN_TS (run timestamp).
--
-- The CTAS below is the v2.1 step SELECT verbatim. The only removals
-- were the work-table existence check and the step completion call.
-- No exception block (errors propagate to the driver handler), no
-- transactions, no target writes. Returns the row count.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_step_TRS_ADDR1_S40_READY (

    P_RUN_TS                 TIMESTAMP_NTZ DEFAULT NULL

)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    l_rows       NUMBER DEFAULT 0;
BEGIN

    -- ---- Step 40: READY_TO_PUBLISH (verbatim from current main)
CREATE OR REPLACE TRANSIENT TABLE WRK_TRS_ADDR1_S40_READY AS
    WITH
    lkp_mc AS (SELECT * FROM TABLE(fn_snow_helper46_common()))
    SELECT v.ADDR_ID, v.av:delivery_address_line1::VARCHAR AS ADDR_LN_1,
           v.av:delivery_address_line2::VARCHAR AS ADDR_LN_2,
           v.av:building_name::VARCHAR AS BLDNG_NM, v.av:sub_building_number::VARCHAR AS FLR_NUM,
           v.av:city::VARCHAR AS CITY, v.av:county_fips_cd::VARCHAR AS COUNTY,
           v.av:state_fips_cd::VARCHAR AS STATE, v.av:country_iso2_char::VARCHAR AS CNTRY_CD,
           v.av:zip_cd_5::VARCHAR AS PSTL_CD, v.av:zip_cd_4_extn::VARCHAR AS PSTL_CD_EXT,
           v.av:geocoding_latitude::NUMBER(38, 6) AS LATTD,
           v.av:geocoding_longitude::NUMBER(38, 6) AS LNGTD,
           v.av:match_code::VARCHAR AS VLDTN_MSG, mc.DESCRIPTION AS VLDTN_DESC,
           v.av:mailability_score::VARCHAR AS MLBLTY_SCR, v.av:address_type::VARCHAR AS ADDR_TP_CD,
           v.av:organization_descriptor::VARCHAR AS ORG_DESC,
           v.av:organization_name::VARCHAR AS ORG_NM, v.av:building_number::VARCHAR AS BLDG_NMBR,
           v.av:sub_building_complete::VARCHAR AS SUB_BLDG_NM,
           v.av:sub_building_descriptor::VARCHAR AS SUB_BLDG_DESC,
           v.av:geocoding_status::VARCHAR AS GEOCD_STS_CD,
           v.av:residential_delivery_indicator::VARCHAR AS RSDNTL_DLVRY_IND,
           v.av:status_info_result_percentage::VARCHAR AS ADDRDR_RSLT_PCT,
           v.av:early_warning_system_return_cd::VARCHAR AS ERLY_WRNG_CD,
           v.av:cass_error_code::VARCHAR AS CASS_ERR_CD,
           v.av:dpv_confirmation::VARCHAR AS DLVRY_PNT_VLDN,
           v.addr_line_1 AS SRC_ADDR_LN_1, v.addr_line_2 AS SRC_ADDR_LN_2,
           v.ADDR_CITY AS SRC_CITY, NULL AS SRC_COUNTY,
           v.ADDR_STATE_CD AS SRC_STATE, 'US' AS SRC_CNTRY,
           v.ADDR_ZIP5 AS SRC_PSTL_CD, v.ADDR_ZIP4 AS SRC_PSTL_CD_EXT,
           v.av:organization_department::VARCHAR AS ORG_DEPT
      FROM WRK_TRS_ADDR1_S30_VALIDATED v
      LEFT JOIN lkp_mc mc ON mc.MATCH_CODE = v.av:status_info_match_code::VARCHAR
      LEFT JOIN (SELECT DISTINCT ADDR_ID FROM STG_TRS_D_UNQ_ADDR) xu ON xu.ADDR_ID = v.ADDR_ID
     WHERE xu.ADDR_ID IS NULL
    QUALIFY ROW_NUMBER() OVER (PARTITION BY v.ADDR_ID ORDER BY v.addr_line_1) = 1;
    SELECT COUNT(*) INTO :l_rows FROM WRK_TRS_ADDR1_S40_READY;
    RETURN :l_rows;
END;$$;
