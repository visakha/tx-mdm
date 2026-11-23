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
-- sp_snow_step_FSS_PTY_S30_DQ2  --  BARE-BONES STEP DRIVER (FSS)
--
-- Mapping: m_Tgt_C_S_FSS_Pty, workflow wf_FSS_Stage_Load, step 30.
-- Step name (checkpoint): DQ2_EXCEPTIONS.
--
-- WHAT THIS STEP PRODUCES
--   WRK_FSS_PTY_S3_DQ2: Standardised values with exception codes / descriptions / types resolved.
--
-- INPUTS / DEPENDENCY DECLARATION
--   P_INPUT_TABLES lists WORK-TABLE inputs only (default: 'WRK_FSS_PTY_S2_DQ').
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
CREATE OR REPLACE PROCEDURE sp_snow_step_FSS_PTY_S30_DQ2 (
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

    -- ---- Step 30: DQ2_EXCEPTIONS (verbatim from current main)
CREATE OR REPLACE TRANSIENT TABLE WRK_FSS_PTY_S3_DQ2 AS
    WITH
    lkp_exc AS (SELECT * FROM TABLE(fn_snow_helper40_common()))
    SELECT d.*,
           d.nm:first_name::VARCHAR                       AS std_first_name,
           d.nm:middle_name::VARCHAR                      AS std_mdl_name,
           d.nm:last_name::VARCHAR                        AS std_lst_name,
           d.nm:full_name::VARCHAR                        AS std_full_name,
           d.nm:src_full_name::VARCHAR                    AS std_src_full_name,
           d.nm:prfx_name::VARCHAR                        AS std_prfx_name,
           d.gd:mdm_gender_code::VARCHAR                  AS mdm_gender_code,
           d.gd:exception_code::VARCHAR                   AS gender_exception_code,
           xg.EXCEPTION_DESC                              AS gender_exception_description,
           xg.EXCEPTION_TYPE                              AS gender_exception_type,
           /* BAD DATA */ IFF(d.birth_exception_code IS NULL, d.DT_DOB, NULL) AS std_birth_date,
           xb.EXCEPTION_DESC                              AS birth_exception_description,
           xb.EXCEPTION_TYPE                              AS birth_exception_type,
           xe.EXCEPTION_CODE                              AS ethnicity_exception_code,
           xe.EXCEPTION_DESC                              AS ethnicity_exception_desc,
           xe.EXCEPTION_TYPE                              AS ethnicity_exception_type,
           d.rc:mdm_race_cd::VARCHAR                      AS mdm_race_cd,
           d.rc:src_race_ind_list::VARCHAR                AS src_race_ind_list,
           xr.EXCEPTION_CODE                              AS race_exception_cd,
           xr.EXCEPTION_DESC                              AS race_exception_desc,
           xr.EXCEPTION_TYPE                              AS race_exception_type,
           xl.EXCEPTION_CODE                              AS language_exception_code,
           xl.EXCEPTION_DESC                              AS language_exception_desc,
           xl.EXCEPTION_TYPE                              AS language_exception_type,
           xs.EXCEPTION_DESC                              AS suffix_exception_desc,
           xs.EXCEPTION_TYPE                              AS suffix_exception_type
      FROM WRK_FSS_PTY_S2_DQ d
      LEFT JOIN lkp_exc xg ON xg.EXCEPTION_CODE = d.gd:exception_code::VARCHAR
      LEFT JOIN lkp_exc xb ON xb.EXCEPTION_CODE = d.birth_exception_code
      LEFT JOIN lkp_exc xe ON xe.EXCEPTION_CODE = fn_snow_helper18_common(d.ethnicity_mstr, 'Invalid_Ethnicity')
      LEFT JOIN lkp_exc xr ON xr.EXCEPTION_CODE = d.rc:exception_code::VARCHAR
      LEFT JOIN lkp_exc xl ON xl.EXCEPTION_CODE = fn_snow_helper18_common(d.language_mstr, 'Invalid_Language')
      LEFT JOIN lkp_exc xs ON xs.EXCEPTION_CODE = d.suffix_exception_code;
    SELECT COUNT(*) INTO :l_rows FROM WRK_FSS_PTY_S3_DQ2;
    RETURN :l_rows;
END;
$$;
