-- ============================================================================
-- sp_snow_step_WIC_PTY_S20_DQ  --  BARE-BONES STEP DRIVER VARIANT (WIC)
--
-- Mapping: m_Tgt_C_S_WIC_Pty, workflow wf_WIC_Stage_Load.
-- Step 20: DQ_STANDARDISE_VALIDATE.
-- Produces: WRK_WIC_PTY_S20_DQ -- Name standardisation, gender, birth date, ethnicity, race indicators, language.
-- Consumes: WRK_WIC_PTY_S10_ACTIVE
--
-- Bare-bones variant: stripped of config gating, job tracking and
-- input checks; the CTAS below is unchanged business SQL. The driver
-- passes the run timestamp; steps that do not use it still declare it
-- so every step call has the same shape.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_step_WIC_PTY_S20_DQ (
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
    CREATE OR REPLACE TRANSIENT TABLE WRK_WIC_PTY_S20_DQ AS
    WITH
    lkp_cv   AS (SELECT * FROM TABLE(fn_snow_helper41_common())),
    lkp_junk AS (SELECT * FROM TABLE(fn_snow_helper43_common()))
    SELECT a.*,
           fn_snow_helper15_common(a.FIRST_NAME, a.MIDDLE_NAME, a.LAST_NAME,
               TRIM(NVL(a.FIRST_NAME, '') || IFF(a.MIDDLE_NAME IS NOT NULL, ' ' || TRIM(a.MIDDLE_NAME), '')
                    || ' ' || NVL(LTRIM(a.LAST_NAME), '')),
               NULL, NULL, NULL, NULL, jf.NAME IS NOT NULL, jl.NAME IS NOT NULL)        AS nm,
           fn_snow_helper17_common(a.GENDER, 'Indv', 'WIC')                            AS gd,
           /* VALIDATION */ fn_snow_helper16_common(a.DOB, 'Indv', 'WIC', :P_RUN_TS)  AS birth_exception_code,
           et.MSTR_CODE_VALUE                                                          AS ethnicity_mstr,
           fn_snow_helper19_common(a.RACE_WHITE_IND, a.RACE_AA_IND, a.RACE_ASIAN_IND, a.RACE_PI_IND,
                                   a.RACE_AN_IND)                                      AS rc,
           lg.MSTR_CODE_VALUE                                                          AS language_mstr
      FROM WRK_WIC_PTY_S10_ACTIVE a
      LEFT JOIN lkp_junk jf ON jf.NAME = UPPER(TRIM(a.FIRST_NAME)) AND jf.IS_FIRST_JUNK
      LEFT JOIN lkp_junk jl ON jl.NAME = UPPER(TRIM(a.LAST_NAME)) AND jl.IS_LAST_JUNK
      LEFT JOIN lkp_cv et ON et.CODE_TYPE = 'ETHNICITY' AND et.SRC_SYS = 'WIC' AND et.SRC_CODE_VALUE = a.ETHNICITY
      LEFT JOIN lkp_cv lg ON lg.CODE_TYPE = 'LANGUAGE_CD' AND lg.SRC_SYS = 'WIC' AND lg.SRC_CODE_VALUE = a.LANGUAGE_CD;;
    SELECT COUNT(*) INTO :l_rows FROM WRK_WIC_PTY_S20_DQ;
    RETURN :l_rows;
END;
$$;
