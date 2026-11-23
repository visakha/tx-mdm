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
-- sp_snow_step_FSS_PTY_S40_ROUTED  --  BARE-BONES STEP DRIVER (FSS)
--
-- Mapping: m_Tgt_C_S_FSS_Pty, workflow wf_FSS_Stage_Load, step 40.
-- Step name (checkpoint): ROUTED.
--
-- WHAT THIS STEP PRODUCES
--   WRK_FSS_PTY_S4_ROUTED: Party / role keys, exception groups, insert-only guards.
--
-- INPUTS / DEPENDENCY DECLARATION
--   P_INPUT_TABLES lists WORK-TABLE inputs only (default: 'WRK_FSS_PTY_S3_DQ2').
--   Snowflake cannot parameterise table names in static SQL, so
--   P_INPUT_TABLES is a dependency declaration + runtime check, NOT
--   dynamic SQL: the CTAS below still names its sources literally, as
--   in the current main procedure.
--
-- BUSINESS SQL
--   The CTAS below is the current step-40 SELECT verbatim. Only
--   substitution: :l_run_ts -> :P_RUN_TS,
--   :c_mapping -> the local constant below (used by the checkpoint).
--   No business expression, filter, guard or column list was changed.
--   Original parameters used by this step: P_PTY_BO_CLASS_CD_MEMBER, P_RLE_BO_CLASS_CD_MEMBER.
--
-- FRAMEWORK
--   No exception block (errors propagate to the driver handler), no
--   transactions, no target writes. This proc writes its own checkpoint
--   in the v2 10-argument form (TARGET_TABLE NULL, as in the current
--   main's step checkpoints; row count survives in the RETURN value
--   and the driver's helper36 summary line).
--   P_JOB_RUN_ID is present in every new proc in this refactor.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_step_FSS_PTY_S40_ROUTED (
    P_PTY_BO_CLASS_CD_MEMBER VARCHAR DEFAULT 'Indv',
    P_RLE_BO_CLASS_CD_MEMBER VARCHAR DEFAULT 'Member',
    P_RUN_TS       TIMESTAMP_NTZ DEFAULT NULL
)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    c_mapping    VARCHAR DEFAULT 'm_Tgt_C_S_FSS_Pty';
    l_rows       NUMBER DEFAULT 0;
BEGIN

    -- ---- Step 40: ROUTED (verbatim from current main)
CREATE OR REPLACE TRANSIENT TABLE WRK_FSS_PTY_S4_ROUTED AS
    WITH
    routed AS (
        SELECT d.*,
               TRIM(d.PTY_SRC_KEY)                                                   AS pkey_trim,
               TRIM(d.PTY_SRC_KEY) || '|' || :P_RLE_BO_CLASS_CD_MEMBER                AS rle_pkey,
               (d.gender_exception_description IS NOT NULL AND d.SOURCE_TYPE = 'CLIENT') AS grp_gender,
               d.birth_exception_code IS NOT NULL                                    AS grp_birth,
               (d.ethnicity_exception_code IS NOT NULL AND d.SOURCE_TYPE = 'CLIENT')  AS grp_ethnicity,
               (d.race_exception_desc IS NOT NULL AND d.SOURCE_TYPE = 'CLIENT')       AS grp_race,
               d.language_exception_code IS NOT NULL                                 AS grp_language,
               d.suffix_exception_code IS NOT NULL                                   AS grp_suffix
          FROM WRK_FSS_PTY_S3_DQ2 d
    )
    SELECT r.*,
           1 /* TIMELINE: VERSION_SEQ hard-coded */                  AS version_seq,
           1                                                          AS hub_state_ind,
           'FSS'                                                      AS src_sys,
           :P_RUN_TS                                                  AS run_ts,
           :c_mapping                                                 AS mapping_name,
           :P_PTY_BO_CLASS_CD_MEMBER                                  AS pty_bo_class_cd,
           :P_RLE_BO_CLASS_CD_MEMBER                                  AS rle_bo_class_cd,
           TO_VARCHAR(r.DT_DOB, 'MM/DD/YYYY')                         AS dob_text,
           'Gender'                                                   AS attr_gender,
           'Birth Date'                                               AS attr_birth,
           'Ethnicity_Cd'                                             AS attr_ethnicity,
           'Race_Cd'                                                  AS attr_race,
           'Language_Cd'                                              AS attr_language,
           'Name Suffix'                                              AS attr_suffix,
           /* BAD DATA: unique keys Snowflake does not enforce */
           (ROW_NUMBER() OVER (PARTITION BY r.pkey_trim ORDER BY r.DT_LAST_UPDATE DESC, r.ID_CLIENT) = 1
            AND xp.PKEY_SRC_OBJECT IS NULL)                           AS uq_pty,
           (ROW_NUMBER() OVER (PARTITION BY r.rle_pkey ORDER BY r.DT_LAST_UPDATE DESC, r.ID_CLIENT) = 1
            AND xr2.PKEY_SRC_OBJECT IS NULL)                          AS uq_rle,
           ROW_NUMBER() OVER (PARTITION BY r.grp_gender, r.PTY_SRC_KEY, r.ID_CLIENT, r.gender_exception_type,
                                           r.gender_exception_code ORDER BY r.DT_LAST_UPDATE DESC) = 1 AS uq_gender,
           ROW_NUMBER() OVER (PARTITION BY r.grp_birth, r.PTY_SRC_KEY, r.ID_CLIENT, r.birth_exception_type,
                                           r.birth_exception_code ORDER BY r.DT_LAST_UPDATE DESC) = 1  AS uq_birth,
           ROW_NUMBER() OVER (PARTITION BY r.grp_ethnicity, r.PTY_SRC_KEY, r.ID_CLIENT,
                                           r.ethnicity_exception_type, r.ethnicity_exception_code
                                  ORDER BY r.DT_LAST_UPDATE DESC) = 1                                  AS uq_ethnicity,
           ROW_NUMBER() OVER (PARTITION BY r.grp_race, r.PTY_SRC_KEY, r.ID_CLIENT, r.race_exception_type,
                                           r.race_exception_cd ORDER BY r.DT_LAST_UPDATE DESC) = 1     AS uq_race,
           ROW_NUMBER() OVER (PARTITION BY r.grp_language, r.PTY_SRC_KEY, r.ID_CLIENT,
                                           r.language_exception_type, r.language_exception_code
                                  ORDER BY r.DT_LAST_UPDATE DESC) = 1                                  AS uq_language,
           ROW_NUMBER() OVER (PARTITION BY r.grp_suffix, r.PTY_SRC_KEY, r.ID_CLIENT, r.suffix_exception_type,
                                           r.suffix_exception_code ORDER BY r.DT_LAST_UPDATE DESC) = 1 AS uq_suffix
      FROM routed r
      LEFT JOIN (SELECT DISTINCT PKEY_SRC_OBJECT FROM C_S_FSS_PTY WHERE VERSION_SEQ = 1) xp
             ON xp.PKEY_SRC_OBJECT = r.pkey_trim
      LEFT JOIN (SELECT DISTINCT PKEY_SRC_OBJECT FROM C_S_FSS_PTY_RLE WHERE VERSION_SEQ = 1) xr2
             ON xr2.PKEY_SRC_OBJECT = r.rle_pkey;
    SELECT COUNT(*) INTO :l_rows FROM WRK_FSS_PTY_S4_ROUTED;
    RETURN :l_rows;
END;
$$;
