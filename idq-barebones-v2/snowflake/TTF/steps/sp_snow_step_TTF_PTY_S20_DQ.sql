-- ============================================================================
-- sp_snow_step_TTF_PTY_S20_DQ -- BARE-BONES variant (TTF)
--
-- Mapping: m_Tgt_C_S_TTF_Pty. No config table, no checkpointing, no job-run id,
-- no input-existence check: the CTAS below is verbatim from v2.1 and
-- names its source work table literally. Returns the row count.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_step_TTF_PTY_S20_DQ (
    P_RUN_TS TIMESTAMP_NTZ
)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    l_rows       NUMBER DEFAULT 0;
BEGIN
    -- ---- Step 20: DQ (verbatim from current main)
CREATE OR REPLACE TRANSIENT TABLE WRK_TTF_PTY_S2_DQ AS
    WITH
    lkp_cv   AS (SELECT * FROM TABLE(fn_snow_helper41_common())),
    lkp_junk AS (SELECT * FROM TABLE(fn_snow_helper43_common()))
    SELECT a.*,
           fn_snow_helper15_common(a.FIRSTNAME, a.MIDDLENAME, a.LASTNAME,
               TRIM(NVL(a.FIRSTNAME, '') || IFF(a.MIDDLENAME IS NOT NULL, ' ' || TRIM(a.MIDDLENAME), '')
                    || ' ' || NVL(LTRIM(a.LASTNAME), '')),
               NULL, NULL, NULL, NULL, jf.NAME IS NOT NULL, jl.NAME IS NOT NULL)        AS nm,
           fn_snow_helper17_common(a.gender, 'Indv', 'TTF')                            AS gd,
           /* VALIDATION */ fn_snow_helper16_common(a.DOB, 'Indv', 'TTF', :P_RUN_TS)  AS birth_exception_code,
           et.MSTR_CODE_VALUE                                                          AS ethnicity_mstr,
           rc.MSTR_CODE_VALUE                                                          AS race_mstr
      FROM WRK_TTF_PTY_S1_ACTIVE a
      LEFT JOIN lkp_junk jf ON jf.NAME = UPPER(TRIM(a.FIRSTNAME)) AND jf.IS_FIRST_JUNK
      LEFT JOIN lkp_junk jl ON jl.NAME = UPPER(TRIM(a.LASTNAME)) AND jl.IS_LAST_JUNK
      LEFT JOIN lkp_cv et ON et.CODE_TYPE = 'ETHNICITY' AND et.SRC_SYS = 'TTF' AND et.SRC_CODE_VALUE = a.ethnicity
      LEFT JOIN lkp_cv rc ON rc.CODE_TYPE = 'RACE' AND rc.SRC_SYS = 'TTF' AND rc.SRC_CODE_VALUE = a.RACEETHNICITYID;
    SELECT COUNT(*) INTO :l_rows FROM WRK_TTF_PTY_S2_DQ;
    RETURN :l_rows;
END;
$$;
