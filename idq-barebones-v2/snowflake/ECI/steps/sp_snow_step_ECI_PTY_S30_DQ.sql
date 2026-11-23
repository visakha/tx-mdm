-- sp_snow_step_ECI_PTY_S30_DQ -- BARE-BONES variant (ECI)
-- Mapping: m_Tgt_C_S_ECI_Pty, workflow wf_ECI_Stage_Load, step 30 (DQ_RULES).
-- Produces: WRK_ECI_PTY_S30_DQ.
-- Runs unconditionally from the driver; no gating, no checkpointing.
-- Business SQL below is verbatim from the v2.1 step procedure.
CREATE OR REPLACE PROCEDURE sp_snow_step_ECI_PTY_S30_DQ (
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
    -- ---- Step 30: VALIDATION RULES, STEP 1 (verbatim from current main)
    CREATE OR REPLACE TRANSIENT TABLE WRK_ECI_PTY_S30_DQ AS
    WITH
    lkp_cv   AS (SELECT * FROM TABLE(fn_snow_helper41_common())),
    lkp_junk AS (SELECT * FROM TABLE(fn_snow_helper43_common()))
    SELECT a.*,
           fn_snow_helper15_common(a.FIRST_NAME, a.MIDDLE_INITIAL, a.LAST_NAME, a.src_full_name, NULL, NULL,
                                   NULL, NULL, jf.NAME IS NOT NULL, jl.NAME IS NOT NULL)       AS nm,
           fn_snow_helper17_common(a.GENDER, a.party_type, a.src_system)                       AS gd,
           fn_snow_helper16_common(a.DOB, a.party_type, a.src_system, :P_RUN_TS) AS birth_exception_code,
           et.MSTR_CODE_VALUE                                                                  AS ethnicity_mstr,
           fn_snow_helper19_common(a.RACE_WHITE, a.RACE_AA, a.RACE_ASIAN, a.RACE_PI, a.RACE_AN) AS rc,
           lg.MSTR_CODE_VALUE                                                                  AS language_mstr
      FROM WRK_ECI_PTY_S20_ACTIVE a
      LEFT JOIN lkp_junk jf ON jf.NAME = UPPER(TRIM(a.FIRST_NAME)) AND jf.IS_FIRST_JUNK
      LEFT JOIN lkp_junk jl ON jl.NAME = UPPER(TRIM(a.LAST_NAME)) AND jl.IS_LAST_JUNK
      LEFT JOIN lkp_cv et ON et.CODE_TYPE = 'ETHNICITY' AND et.SRC_SYS = a.src_system
                         AND et.SRC_CODE_VALUE = a.ETHNICITY
      LEFT JOIN lkp_cv lg ON lg.CODE_TYPE = 'LANGUAGE_CD' AND lg.SRC_SYS = a.src_system
                         AND lg.SRC_CODE_VALUE = a.LANGUAGE_CD;
    SELECT COUNT(*) INTO :l_rows FROM WRK_ECI_PTY_S30_DQ;
    RETURN :l_rows;
END;
$$;
