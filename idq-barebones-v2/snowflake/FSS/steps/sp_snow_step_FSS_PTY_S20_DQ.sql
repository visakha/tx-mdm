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
-- sp_snow_step_FSS_PTY_S20_DQ  --  BARE-BONES STEP DRIVER (FSS)
--
-- Mapping: m_Tgt_C_S_FSS_Pty, workflow wf_FSS_Stage_Load, step 20.
-- Step name (checkpoint): DQ_CHECKS.
--
-- WHAT THIS STEP PRODUCES
--   WRK_FSS_PTY_S2_DQ: Name standardisation, gender, birth date, ethnicity, race, language, suffix checks.
--
-- INPUTS / DEPENDENCY DECLARATION
--   P_INPUT_TABLES lists WORK-TABLE inputs only (default: 'WRK_FSS_PTY_S1_SRC').
--   Snowflake cannot parameterise table names in static SQL, so
--   P_INPUT_TABLES is a dependency declaration + runtime check, NOT
--   dynamic SQL: the CTAS below still names its sources literally, as
--   in the current main procedure.
--
-- BUSINESS SQL
--   The CTAS below is the current step-20 SELECT verbatim. Only
--   substitution: :l_run_ts -> :P_RUN_TS,
--   :c_mapping -> the local constant below (used by the checkpoint).
--   No business expression, filter, guard or column list was changed.
--   Original parameters used by this step: none; this step uses :P_RUN_TS (substituted from :l_run_ts).
--
-- FRAMEWORK
--   No exception block (errors propagate to the driver handler), no
--   transactions, no target writes. This proc writes its own checkpoint
--   in the v2 10-argument form (TARGET_TABLE NULL, as in the current
--   main's step checkpoints; row count survives in the RETURN value
--   and the driver's helper36 summary line).
--   P_JOB_RUN_ID is present in every new proc in this refactor.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_step_FSS_PTY_S20_DQ (
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

    -- ---- Step 20: DQ_CHECKS (verbatim from current main)
CREATE OR REPLACE TRANSIENT TABLE WRK_FSS_PTY_S2_DQ AS
    WITH
    lkp_cv     AS (SELECT * FROM TABLE(fn_snow_helper41_common())),
    lkp_cv_any AS (SELECT * FROM TABLE(fn_snow_helper42_common())),
    lkp_junk   AS (SELECT * FROM TABLE(fn_snow_helper43_common()))
    SELECT a.*,
           fn_snow_helper15_common(a.NM_FIRST, a.NM_MIDDLE, a.NM_LAST,
               TRIM(NVL(a.NM_FIRST, '') || IFF(a.NM_MIDDLE IS NOT NULL, ' ' || TRIM(a.NM_MIDDLE), '')
                    || ' ' || NVL(LTRIM(a.NM_LAST), '')),
               NULL, a.CD_SUFFIX, NULL, nsx.MSTR_CODE_VALUE,
               jf.NAME IS NOT NULL, jl.NAME IS NOT NULL)                                    AS nm,
           fn_snow_helper17_common(a.CD_GENDER, 'Indv', 'FSS')                              AS gd,
           /* VALIDATION */ fn_snow_helper16_common(a.DT_DOB, 'Indv', 'FSS', :P_RUN_TS)     AS birth_exception_code,
           et.MSTR_CODE_VALUE                                                               AS ethnicity_mstr,
           fn_snow_helper19_common(a.RACE_WHITE, a.RACE_AA, a.RACE_ASIAN, a.RACE_PI, a.RACE_AN) AS rc,
           lg.MSTR_CODE_VALUE                                                               AS language_mstr,
           sx.MSTR_CODE_VALUE                                                               AS std_suffix,
           /* VALIDATION */ fn_snow_helper20_common(a.CD_SUFFIX, sx.MSTR_CODE_VALUE)       AS suffix_exception_code
      FROM WRK_FSS_PTY_S1_SRC a
      LEFT JOIN lkp_junk jf ON jf.NAME = UPPER(TRIM(a.NM_FIRST)) AND jf.IS_FIRST_JUNK
      LEFT JOIN lkp_junk jl ON jl.NAME = UPPER(TRIM(a.NM_LAST)) AND jl.IS_LAST_JUNK
      -- lkp_V_Lookup_Sfx_Code_Value inside the name mapplet (CODE_TYPE 'SUFFIX')
      LEFT JOIN lkp_cv nsx ON nsx.CODE_TYPE = 'SUFFIX' AND nsx.SRC_SYS = 'FSS' AND nsx.SRC_CODE_VALUE = a.CD_SUFFIX
      LEFT JOIN lkp_cv et  ON et.CODE_TYPE = 'ETHNICITY' AND et.SRC_SYS = 'FSS' AND et.SRC_CODE_VALUE = a.CD_HISPANIC
      LEFT JOIN lkp_cv lg  ON lg.CODE_TYPE = 'LANGUAGE_CD' AND lg.SRC_SYS = 'FSS' AND lg.SRC_CODE_VALUE = a.LANGUAGE_CD
      -- rule_Suffix_Std's lkp_V_LOOKUP_CODE_VALUE (no code-type filter)
      LEFT JOIN lkp_cv_any sx ON sx.SRC_SYS = 'FSS' AND sx.SRC_CODE_VALUE = a.CD_SUFFIX;
    SELECT COUNT(*) INTO :l_rows FROM WRK_FSS_PTY_S2_DQ;
    RETURN :l_rows;
END;
$$;
