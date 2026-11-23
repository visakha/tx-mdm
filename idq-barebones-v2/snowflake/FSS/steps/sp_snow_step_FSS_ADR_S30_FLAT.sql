-- ============================================================================
-- BARE-BONES STRIP of the v2.1 config-driven step driver (FSS).
-- Removed: the COMMON.ETL_RUN_CONFIG_TBL GATHER block, all flags /
-- consumed strings / driver-row gate, all sp_etl_checkpoint /
-- sp_etl_job_begin / sp_etl_job_finish / sp_etl_job_fail calls,
-- P_JOB_RUN_ID, P_INPUT_TABLES, l_job_run_id, l_flag_*, l_in_*, l_pub_*,
-- step existence-check / probe blocks, and the seed file (not copied).
-- Kept verbatim: step-5 DROP TABLE IF EXISTS cleanup, step call order,
-- the single publish transaction with branches in order, every step CTAS
-- and every publish INSERT, and the fn_snow_helper36_common summary lines
-- (publish lines now appended inside the transaction, in the same order,
-- reusing l_rows instead of the removed l_pub_* variables, so the
-- returned summary string is unchanged in content and order).
-- NOTE: the v2.1 header below is retained for its business-flow and
-- parity notes; its CONFIG-DRIVEN NOTES / TRANSACTION EDGES / SIGNATURE /
-- FRAMEWORK paragraphs describe the v2.1 code and no longer apply.
-- ============================================================================
-- ============================================================================
-- sp_snow_step_FSS_ADR_S30_FLAT  --  BARE-BONES STEP DRIVER (FSS)
--
-- Mapping: m_Tgt_C_S_FSS_Pty_Addr, workflow wf_FSS_Stage_Load, step 30.
-- Step name (checkpoint): FLAT.
--
-- WHAT THIS STEP PRODUCES
--   WRK_FSS_ADDR_S3_FLAT: Validation result flattened into plain columns, match-code description resolved.
--
-- INPUTS / DEPENDENCY DECLARATION
--   P_INPUT_TABLES lists WORK-TABLE inputs only (default: 'WRK_FSS_ADDR_S2_VALIDATED').
--   Snowflake cannot parameterise table names in static SQL, so
--   P_INPUT_TABLES is a dependency declaration + runtime check, NOT
--   dynamic SQL: the CTAS below still names its sources literally, as
--   in the current main procedure.
--
-- BUSINESS SQL
--   The CTAS below is the current step-30 SELECT verbatim. Only
--   substitution: :l_run_ts -> :P_RUN_TS (not used by this step),
--   :c_mapping -> the local constant below (used by the checkpoint).
--   No business expression, filter, guard or column list was changed.
--   Original parameters used by this step: none.
--
-- FRAMEWORK
--   No exception block (errors propagate to the driver handler), no
--   transactions, no target writes. This proc writes its own checkpoint
--   in the v2 10-argument form (TARGET_TABLE NULL, as in the current
--   main's step checkpoints; row count survives in the RETURN value
--   and the driver's helper36 summary line).
--   P_JOB_RUN_ID is present in every new proc in this refactor.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_step_FSS_ADR_S30_FLAT (
    P_RUN_TS       TIMESTAMP_NTZ
)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    l_rows       NUMBER DEFAULT 0;
BEGIN

    -- ---- Step 30: FLAT (verbatim from current main)
CREATE OR REPLACE TRANSIENT TABLE WRK_FSS_ADDR_S3_FLAT AS
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
      FROM WRK_FSS_ADDR_S2_VALIDATED v
      LEFT JOIN lkp_mc mc ON mc.MATCH_CODE = v.av:status_info_match_code::VARCHAR;
    SELECT COUNT(*) INTO :l_rows FROM WRK_FSS_ADDR_S3_FLAT;
    RETURN :l_rows;
END;
$$;
