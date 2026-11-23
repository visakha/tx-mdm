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
-- sp_snow_step_FSS_VAL_S30_ROUTED  --  BARE-BONES STEP DRIVER (FSS)
--
-- Mapping: m_Tgt_C_S_FSS_Pty_Validation, workflow wf_FSS_Stage_Load, step 30.
-- Step name (checkpoint): ROUTED.
--
-- WHAT THIS STEP PRODUCES
--   WRK_FSS_VAL_S3_ROUTED: Invalid-name / deactivation / reactivation groups, exception details, first-row-per-exception-key flag.
--
-- INPUTS / DEPENDENCY DECLARATION
--   P_INPUT_TABLES lists WORK-TABLE inputs only (default: 'WRK_FSS_VAL_S2_ENRICHED').
--   Snowflake cannot parameterise table names in static SQL, so
--   P_INPUT_TABLES is a dependency declaration + runtime check, NOT
--   dynamic SQL: the CTAS below still names its sources literally, as
--   in the current main procedure.
--
-- BUSINESS SQL
--   The CTAS below is the current step-30 SELECT verbatim. Only
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
CREATE OR REPLACE PROCEDURE sp_snow_step_FSS_VAL_S30_ROUTED (
    P_RUN_TS       TIMESTAMP_NTZ
)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    c_mapping    VARCHAR DEFAULT 'm_Tgt_C_S_FSS_Pty_Validation';
    l_rows       NUMBER DEFAULT 0;
BEGIN

    -- ---- Step 30: ROUTED (verbatim from current main)
CREATE OR REPLACE TRANSIENT TABLE WRK_FSS_VAL_S3_ROUTED AS
    WITH
    lkp_exc AS (SELECT * FROM TABLE(fn_snow_helper40_common())),
    routed AS (
        SELECT r.*,
               r.name_missing                                                          AS grp_invalid_party_name,
               (r.name_missing OR r.CLIENT_DTL__CAPXACTION = 'D' OR r.LAST_INACTV_CLIENT_YN = 'Y') AS grp_deactivation,
               NVL(r.deactivation_sts IS NOT NULL AND NOT r.name_missing
                   AND r.CLIENT_DTL__CAPXACTION <> 'D' AND r.LAST_INACTV_CLIENT_YN <> 'Y', FALSE) AS grp_reactivation,
               CASE WHEN fn_snow_helper03_common(r.std_first_name) THEN 'Missing_First_Name'
                    WHEN fn_snow_helper03_common(r.std_lst_name) THEN 'Missing_Last_Name' END    AS exc_code_name,
               CASE WHEN fn_snow_helper03_common(r.std_first_name) THEN 'First Name'
                    WHEN fn_snow_helper03_common(r.std_lst_name) THEN 'Last Name' END            AS exc_attribute_name,
               fn_snow_helper02_common(r.hub_state_ind)                                          AS new_deactivation_sts
          FROM WRK_FSS_VAL_S2_ENRICHED r
    )
    SELECT r.*,
           ex.EXCEPTION_DESC     AS exc_desc_name,
           ex.EXCEPTION_TYPE     AS exc_type_name,
           'FSS'                 AS src_sys,
           :P_RUN_TS             AS run_ts,
           :c_mapping            AS mapping_name,
           'Deactivation'        AS action_deactivation,
           'Reactivation'        AS action_reactivation,
           /* BAD DATA: unique key of EXC_STG_BAD_REC_MEMB, first row per key in this run */
           ROW_NUMBER() OVER (PARTITION BY r.grp_invalid_party_name, r.PTY_SRC_KEY, ex.EXCEPTION_TYPE,
                                           r.exc_code_name ORDER BY r.DT_LAST_UPDATE DESC, r.ID_CLIENT) = 1 AS uq_exc_name
      FROM routed r
      LEFT JOIN lkp_exc ex ON ex.EXCEPTION_CODE = r.exc_code_name;
    SELECT COUNT(*) INTO :l_rows FROM WRK_FSS_VAL_S3_ROUTED;
    RETURN :l_rows;
END;
$$;
