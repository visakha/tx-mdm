-- ============================================================================
-- sp_snow_step_CRE_CARE_S40_FLAT  --  BARE-BONES STEP (CRE)
--
-- Mapping: m_Tgt_C_S_CRE_CARE_Clients, workflow wf_CRE_Stage_Load_Ongoing, step 40.
-- Produces WRK_CRE_CARE_S4_FLAT; consumes WRK_CRE_CARE_S3_RANKED.
-- Original parameters used: P_RLE_BO_CLASS_CD_MEMBER, P_DEFAULT_NONUS_STATE_CD.
--
-- Bare-bones variant: no P_JOB_RUN_ID, no P_INPUT_TABLES, no
-- existence check, no checkpoint call. The CTAS below is the
-- v2.1 step SELECT verbatim; only the dropped parameters and
-- framework blocks were removed. No exception block (errors
-- propagate to the driver handler), no transaction, no target write.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_step_CRE_CARE_S40_FLAT (
    P_RLE_BO_CLASS_CD_MEMBER     VARCHAR DEFAULT 'Member',
    P_DEFAULT_NONUS_STATE_CD     VARCHAR DEFAULT '99',
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
    -- ---- Step 40: FLAT_ADDR_ALTID (verbatim from current main)
    CREATE OR REPLACE TRANSIENT TABLE WRK_CRE_CARE_S4_FLAT AS
    WITH
    lkp_exc AS (SELECT * FROM TABLE(fn_snow_helper40_common())),
    lkp_mc  AS (SELECT * FROM TABLE(fn_snow_helper46_common())),
    -- lkp_ALT_ID_MSTR_REF_CODE: LOOKUP_CODE_VALUE of SRC_SYS CRE by source value (no code-type filter), any row
    alt_tp AS (
        SELECT l.SRC_CODE_VALUE, l.MSTR_REF_CODE, l.MSTR_REF_LABEL, l.SRC_SYS
          FROM LOOKUP_CODE_VALUE l
         WHERE l.SRC_SYS = 'CRE' AND l.SRC_CODE_VALUE IN ('CARE ID', 'Medicaid ID', 'SSN')
       QUALIFY ROW_NUMBER() OVER (PARTITION BY l.SRC_CODE_VALUE ORDER BY l.CODE_TYPE) = 1
    )
    SELECT d.*,
           d.CARE_ID                                                               AS pty_key,
           NVL(d.CARE_ID, '') || '|' || :P_RLE_BO_CLASS_CD_MEMBER                  AS rle_key,
           NVL(d.CARE_ID, '') || '|Member'                                         AS member_rle_fk,
           /* TIMELINE: EXP_VALID_MEMBERS, EXP_PTY_HOLD / EXP_PTY_RLE_HOLD */
           IFF(d.end_dated, DATEADD(day, -1, d.CARE_LASTUP_DT), d.CARE_LASTUP_DT)  AS period_start,
           IFF(d.end_dated, d.CARE_LASTUP_DT, NULL)                                AS period_end,
           IFF(d.end_dated, 2, NULL)                                               AS timeline_action,
           IFF(d.end_dated, DATEADD(day, -1, d.CARE_LASTUP_DT), NULL)              AS period_reference_time,
           IFF(d.end_dated, DATEADD(hour, -1, :P_RUN_TS), :P_RUN_TS)               AS last_update,
           IFF(d.end_dated, DATEADD(day, 1, DATEADD(day, -1, d.CARE_LASTUP_DT)), NULL) AS pty_period_end,
           IFF(d.end_dated, DATEADD(day, -1, d.CARE_LASTUP_DT), NULL)              AS pty_period_reference_time,
           NVL(d.CARE_LASTUP_DT, d.INSERT_DATE)                                    AS src_last_update,
           d.gd:mdm_gender_code::VARCHAR                                           AS mdm_gender_code,
           d.gd:exception_code::VARCHAR                                            AS gender_exception_code,
           xg.EXCEPTION_DESC                                                       AS gender_exception_description,
           xg.EXCEPTION_TYPE                                                       AS gender_exception_type,
           xs.EXCEPTION_DESC                                                       AS suffix_exception_desc,
           xs.EXCEPTION_TYPE                                                       AS suffix_exception_type,
           xe.EXCEPTION_CODE AS ethnicity_exception_code, xe.EXCEPTION_DESC AS ethnicity_exception_desc,
           xe.EXCEPTION_TYPE AS ethnicity_exception_type,
           xr.EXCEPTION_CODE AS race_exception_code, xr.EXCEPTION_DESC AS race_exception_desc,
           xr.EXCEPTION_TYPE AS race_exception_type,
           xp.EXCEPTION_CODE AS phone_exception_code, xp.EXCEPTION_DESC AS phone_exception_desc,
           xp.EXCEPTION_TYPE AS phone_exception_type,
           NVL(d.CARE_ID, '') || '|Member|Telephone|001|' || NVL(d.phone_std, '')  AS phn_key,
           /* VALIDATION: RTR_VALID_ADDRESS / RTR_VALID_NON_US_ADDRESSES */
           IFF(d.addr_us,
               NVL((TRUNC(TRY_TO_NUMBER(d.av:mailability_score::VARCHAR)) >= 3
                    OR LEFT(d.av:match_code::VARCHAR, 1) NOT IN ('I', 'N'))
                   AND d.av:state_fips_cd::VARCHAR IS NOT NULL, FALSE),
               d.CITY IS NOT NULL AND d.STREET IS NOT NULL)                       AS addr_valid,
           IFF(d.addr_us, d.av:delivery_address_line1::VARCHAR, INITCAP(d.STREET)) AS a_line1,
           IFF(d.addr_us, d.av:delivery_address_line2::VARCHAR, NULL)             AS a_line2,
           IFF(d.addr_us, d.av:city::VARCHAR, INITCAP(d.CITY))                    AS a_city,
           IFF(d.addr_us, d.av:state_fips_cd::VARCHAR, :P_DEFAULT_NONUS_STATE_CD) AS a_state,
           IFF(d.addr_us, d.av:county_fips_cd::VARCHAR, d.CNTY)                   AS a_county_fips,
           IFF(d.addr_us, d.av:country_iso2_char::VARCHAR, 'ZZ')                  AS a_country,
           IFF(d.addr_us, d.av:zip_cd_5::VARCHAR, d.ZIP)                          AS a_postcode,
           IFF(d.addr_us, d.av:zip_cd_4_extn::VARCHAR, d.ZIPSUF)                  AS a_postcode_ext,
           d.av:geocoding_latitude::NUMBER(38, 6)                                  AS a_latitude,
           d.av:geocoding_longitude::NUMBER(38, 6)                                 AS a_longitude,
           d.av:mailability_score::VARCHAR                                         AS a_mailability_score,
           d.av:match_code::VARCHAR                                                AS a_match_code,
           d.av:address_type::VARCHAR                                              AS a_address_type,
           d.av:sub_building_number::VARCHAR                                       AS a_sub_building_number,
           d.av:sub_building_descriptor::VARCHAR                                   AS a_sub_building_descriptor,
           d.av:sub_building_complete::VARCHAR                                     AS a_sub_building_complete,
           d.av:building_number::VARCHAR                                           AS a_building_number,
           d.av:building_name::VARCHAR                                             AS a_building_name,
           d.av:residential_delivery_indicator::VARCHAR                           AS a_residential,
           d.av:geocoding_status::VARCHAR                                          AS a_geocoding_status,
           d.av:organization_name::VARCHAR                                         AS a_org_name,
           d.av:organization_descriptor::VARCHAR                                   AS a_org_descriptor,
           TRY_TO_NUMBER(d.av:mailability_score::VARCHAR)                          AS a_dr_mailability_score,
           mc.DESCRIPTION                                                          AS a_dr_error_desc,
           d.av:match_code::VARCHAR                                                AS a_dr_error_code,
           NVL(d.STREET, '') || ' ' || '' || ' ' || NVL(d.CITY, '') || ' ' || NVL(d.STATE, '') || ' '
           || NVL(d.ZIP, '')                                                       AS addr_attribute_value,
           xa.EXCEPTION_CODE AS addr_exception_code, xa.EXCEPTION_DESC AS addr_exception_desc,
           xa.EXCEPTION_TYPE AS addr_exception_type,
           -- NRML_ALT_ID occurrences and lkp_ALT_ID_MSTR_REF_CODE
           d.ci:id_value::VARCHAR                                                  AS care_alt_id,
           t1.MSTR_REF_CODE                                                        AS care_tp_cd,
           d.md:id_value::VARCHAR                                                  AS medicaid_alt_id,
           d.md:exception_code::VARCHAR                                            AS medicaid_exception_code,
           xm.EXCEPTION_DESC AS medicaid_exception_desc, xm.EXCEPTION_TYPE AS medicaid_exception_type,
           t2.MSTR_REF_CODE AS medicaid_tp_cd, t2.MSTR_REF_LABEL AS medicaid_tp_lbl,
           t2.SRC_SYS AS medicaid_tp_sys,
           /* VALIDATION: exp_validate_ssn + Lkp_EXC_LOOKUP_CODE_VALUE_SSN (looked-up code) */
           xn.EXCEPTION_CODE AS ssn_exception_code, xn.EXCEPTION_DESC AS ssn_exception_desc,
           xn.EXCEPTION_TYPE AS ssn_exception_type,
           t3.MSTR_REF_CODE AS ssn_tp_cd, t3.MSTR_REF_LABEL AS ssn_tp_lbl, t3.SRC_SYS AS ssn_tp_sys
      FROM WRK_CRE_CARE_S3_RANKED d
      LEFT JOIN lkp_exc xg ON xg.EXCEPTION_CODE = d.gd:exception_code::VARCHAR
      LEFT JOIN lkp_exc xs ON xs.EXCEPTION_CODE = d.suffix_exception_code
      LEFT JOIN lkp_exc xe ON xe.EXCEPTION_CODE = fn_snow_helper18_common(d.ethnicity_mstr, 'Invalid_Ethnicity')
      LEFT JOIN lkp_exc xr ON xr.EXCEPTION_CODE = fn_snow_helper18_common(d.race_mstr, 'Invalid_Race')
      LEFT JOIN lkp_exc xp ON xp.EXCEPTION_CODE = d.phone_code
      LEFT JOIN lkp_exc xm ON xm.EXCEPTION_CODE = d.md:exception_code::VARCHAR
      LEFT JOIN lkp_exc xn ON xn.EXCEPTION_CODE = IFF(d.sn:ssn_status::VARCHAR = 'Invalid'
                                                      AND d.ssn_out IS NOT NULL, 'Invalid_SSN', NULL)
      LEFT JOIN lkp_exc xa ON xa.EXCEPTION_CODE = 'Invalid_Address'
      LEFT JOIN lkp_mc mc ON mc.MATCH_CODE = d.av:match_code::VARCHAR
      LEFT JOIN alt_tp t1 ON t1.SRC_CODE_VALUE = 'CARE ID'
      LEFT JOIN alt_tp t2 ON t2.SRC_CODE_VALUE = 'Medicaid ID'
      LEFT JOIN alt_tp t3 ON t3.SRC_CODE_VALUE = 'SSN';
    SELECT COUNT(*) INTO :l_rows FROM WRK_CRE_CARE_S4_FLAT;
    RETURN :l_rows;
END;
$$;
