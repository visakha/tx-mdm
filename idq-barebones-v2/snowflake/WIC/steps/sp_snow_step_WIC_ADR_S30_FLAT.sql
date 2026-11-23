-- ============================================================================
-- sp_snow_step_WIC_ADR_S30_FLAT  --  BARE-BONES STEP DRIVER VARIANT (WIC)
--
-- Mapping: m_Tgt_C_S_WIC_Pty_Addr, workflow wf_WIC_Stage_Load.
-- Step 30: FLAT.
-- Produces: WRK_WIC_ADDR_S30_FLAT -- Validation result pulled out into flat columns; match-code description resolved.
-- Consumes: WRK_WIC_ADDR_S20_VALIDATED
--
-- Bare-bones variant: stripped of config gating, job tracking and
-- input checks; the CTAS below is unchanged business SQL. The driver
-- passes the run timestamp; steps that do not use it still declare it
-- so every step call has the same shape.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_step_WIC_ADR_S30_FLAT (
    P_RUN_TS                 TIMESTAMP_NTZ
)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    l_rows NUMBER DEFAULT 0;
BEGIN
    CREATE OR REPLACE TRANSIENT TABLE WRK_WIC_ADDR_S30_FLAT AS
    WITH
    lkp_mc AS (SELECT * FROM TABLE(fn_snow_helper46_common()))
    SELECT v.*,
           v.av:delivery_address_line1::VARCHAR          AS a_line1,
           v.av:delivery_address_line2::VARCHAR          AS a_line2,
           v.av:city::VARCHAR                            AS a_city,
           v.av:postcode_complete::VARCHAR               AS a_postcode_complete,
           v.av:zip_cd_5::VARCHAR                        AS a_zip_cd_5,
           v.av:zip_cd_4_extn::VARCHAR                   AS a_zip_cd_4_extn,
           v.av:country_iso2_char::VARCHAR               AS a_country,
           v.av:mailability_score::VARCHAR               AS a_mailability_score,
           v.av:match_code::VARCHAR                      AS a_match_code,
           mc.DESCRIPTION                                AS a_match_code_description,
           fn_snow_helper04_common(v.av:status_info_result_percentage::VARCHAR, 2) AS a_result_pct,
           v.av:address_type::VARCHAR                    AS a_address_type,
           v.av:county_fips_cd::VARCHAR                  AS a_county_fips,
           v.av:state_fips_cd::VARCHAR                   AS a_state_fips,
           v.av:geocoding_latitude::NUMBER(38, 6)        AS a_latitude,
           v.av:geocoding_longitude::NUMBER(38, 6)       AS a_longitude,
           v.av:geocoding_status::VARCHAR                AS a_geocoding_status,
           v.av:residential_delivery_indicator::VARCHAR  AS a_residential,
           v.av:organization_name::VARCHAR               AS a_org_name,
           v.av:organization_descriptor::VARCHAR         AS a_org_descriptor,
           v.av:organization_department::VARCHAR         AS a_org_department,
           v.av:building_complete::VARCHAR               AS a_building_complete,
           v.av:building_name::VARCHAR                   AS a_building_name,
           v.av:building_number::VARCHAR                 AS a_building_number,
           v.av:sub_building_complete::VARCHAR           AS a_sub_building_complete,
           v.av:sub_building_descriptor::VARCHAR         AS a_sub_building_descriptor,
           v.av:early_warning_system_return_cd::VARCHAR  AS a_early_warning,
           v.av:cass_error_code::VARCHAR                 AS a_cass_error,
           v.av:dpv_confirmation::VARCHAR                AS a_dpv
      FROM WRK_WIC_ADDR_S20_VALIDATED v
      LEFT JOIN lkp_mc mc ON mc.MATCH_CODE = v.av:status_info_match_code::VARCHAR;;
    SELECT COUNT(*) INTO :l_rows FROM WRK_WIC_ADDR_S30_FLAT;
    RETURN :l_rows;
END;
$$;
