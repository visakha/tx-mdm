-- ============================================================================
-- sp_snow_step_TRS_PTY_S20_DQ  --  BARE-BONES STEP (TRS)
--
-- Mapping: m_Tgt_C_S_TRS_Pty_OnGoing, workflow wf_TRS_Stage_Load_1_Ongoing.
-- Step name: DQ_STANDARDISE_VALIDATE. Produces: WRK_TRS_PTY_S2_DQ.
-- Consumes (v2.1 declared inputs): WRK_TRS_PTY_S1_SRC.
-- Original params used: P_DC_INDV_TBL_SRC; plus P_RUN_TS (run timestamp).
--
-- The CTAS below is the v2.1 step SELECT verbatim. The only removals
-- were the work-table existence check and the step completion call.
-- No exception block (errors propagate to the driver handler), no
-- transactions, no target writes. Returns the row count.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_step_TRS_PTY_S20_DQ (

    P_DC_INDV_TBL_SRC VARCHAR DEFAULT 'DC_INDV',
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

    -- ---- Step 20: DQ_STANDARDISE_VALIDATE (verbatim from current main)
CREATE OR REPLACE TRANSIENT TABLE WRK_TRS_PTY_S2_DQ AS
    WITH
    lkp_cv   AS (SELECT * FROM TABLE(fn_snow_helper41_common())),
    lkp_junk AS (SELECT * FROM TABLE(fn_snow_helper43_common())),
    lkp_exc  AS (SELECT * FROM TABLE(fn_snow_helper40_common())),
    dq AS (
        SELECT s.*,
               IFF(s.SRC_TBL = :P_DC_INDV_TBL_SRC, TO_VARCHAR(s.INDV_ID) || '|' || :P_DC_INDV_TBL_SRC,
                   TO_VARCHAR(s.INDV_ID))                                                     AS pkey_src_object,
               TRIM(NVL(s.FIRST_NAME, '') || IFF(s.MID_NAME IS NOT NULL, ' ' || TRIM(s.MID_NAME), '')
                    || ' ' || NVL(LTRIM(s.LAST_NAME), ''))                                    AS src_full_name,
               fn_snow_helper15_common(s.FIRST_NAME, s.MID_NAME, s.LAST_NAME,
                   TRIM(NVL(s.FIRST_NAME, '') || IFF(s.MID_NAME IS NOT NULL, ' ' || TRIM(s.MID_NAME), '')
                        || ' ' || NVL(LTRIM(s.LAST_NAME), '')),
                   s.PREFIX_NAME, s.SUFX_NAME, pfx.MSTR_CODE_VALUE, sfx.MSTR_CODE_VALUE,
                   jf.NAME IS NOT NULL, jl.NAME IS NOT NULL)                                  AS nm,
               fn_snow_helper17_common(s.GENDER_CD, 'Indv', 'TRS')                            AS gd,
               fn_snow_helper16_common(s.DOB_DT, 'Indv', 'TRS', :P_RUN_TS)                    AS birth_exception_code,
               rc.MSTR_CODE_VALUE                                                             AS race_mstr,
               et.MSTR_CODE_VALUE                                                             AS ethnicity_mstr,
               IFF(s.DEATH_DT > :P_RUN_TS, 'Invalid_Death_Date', NULL)                        AS death_exception_code
          FROM WRK_TRS_PTY_S1_SRC s
          LEFT JOIN lkp_cv pfx ON pfx.CODE_TYPE = 'PREFIX' AND pfx.SRC_SYS = 'TRS' AND pfx.SRC_CODE_VALUE = s.PREFIX_NAME
          LEFT JOIN lkp_cv sfx ON sfx.CODE_TYPE = 'SUFFIX' AND sfx.SRC_SYS = 'TRS' AND sfx.SRC_CODE_VALUE = s.SUFX_NAME
          LEFT JOIN lkp_junk jf ON jf.NAME = UPPER(TRIM(s.FIRST_NAME)) AND jf.IS_FIRST_JUNK
          LEFT JOIN lkp_junk jl ON jl.NAME = UPPER(TRIM(s.LAST_NAME)) AND jl.IS_LAST_JUNK
          LEFT JOIN lkp_cv rc ON rc.CODE_TYPE = 'RACE' AND rc.SRC_SYS = 'TRS' AND rc.SRC_CODE_VALUE = s.RACE_CD
          LEFT JOIN lkp_cv et ON et.CODE_TYPE = 'ETHNICITY' AND et.SRC_SYS = 'TRS' AND et.SRC_CODE_VALUE = s.ETHNICITY_CD
    )
    SELECT d.*,
           TRIM(d.pkey_src_object)               AS pkey_trim,
           d.nm:first_name::VARCHAR              AS std_first_name,
           d.nm:middle_name::VARCHAR             AS std_mdl_name,
           d.nm:last_name::VARCHAR               AS std_lst_name,
           d.nm:full_name::VARCHAR               AS std_full_name,
           d.nm:prfx_name::VARCHAR               AS std_prfx_name,
           d.nm:sfx_name::VARCHAR                AS std_sfx_name,
           d.gd:mdm_gender_code::VARCHAR         AS mdm_gender_code,
           d.gd:exception_code::VARCHAR          AS gender_exception_code,
           xg.EXCEPTION_DESC                     AS gender_exception_description,
           xg.EXCEPTION_TYPE                     AS gender_exception_type,
           IFF(d.birth_exception_code IS NULL, d.DOB_DT, NULL) AS std_birth_date,
           xb.EXCEPTION_DESC                     AS birth_exception_description,
           xb.EXCEPTION_TYPE                     AS birth_exception_type,
           xr.EXCEPTION_CODE                     AS race_exception_code,
           xr.EXCEPTION_DESC                     AS race_exception_desc,
           xr.EXCEPTION_TYPE                     AS race_exception_type,
           xe.EXCEPTION_CODE                     AS ethnicity_exception_code,
           xe.EXCEPTION_DESC                     AS ethnicity_exception_desc,
           xe.EXCEPTION_TYPE                     AS ethnicity_exception_type,
           xd.EXCEPTION_CODE                     AS death_exception_lkp_code,
           xd.EXCEPTION_DESC                     AS death_exception_desc,
           xd.EXCEPTION_TYPE                     AS death_exception_type,
           (fn_snow_helper03_common(d.nm:first_name::VARCHAR)
            OR fn_snow_helper03_common(d.nm:last_name::VARCHAR)) AS name_missing
      FROM dq d
      LEFT JOIN lkp_exc xg ON xg.EXCEPTION_CODE = d.gd:exception_code::VARCHAR
      LEFT JOIN lkp_exc xb ON xb.EXCEPTION_CODE = d.birth_exception_code
      LEFT JOIN lkp_exc xr ON xr.EXCEPTION_CODE = fn_snow_helper18_common(d.race_mstr, 'Invalid_Race')
      LEFT JOIN lkp_exc xe ON xe.EXCEPTION_CODE = fn_snow_helper18_common(d.ethnicity_mstr, 'Invalid_Ethnicity')
      LEFT JOIN lkp_exc xd ON xd.EXCEPTION_CODE = d.death_exception_code;
    SELECT COUNT(*) INTO :l_rows FROM WRK_TRS_PTY_S2_DQ;
    RETURN :l_rows;
END;$$;
