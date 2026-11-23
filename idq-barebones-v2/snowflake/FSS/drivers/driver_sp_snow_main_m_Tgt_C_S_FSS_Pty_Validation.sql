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
-- sp_snow_main_m_Tgt_C_S_FSS_Pty_Validation  --  BARE-BONES STEP DRIVER (FSS)
--
-- IDQ mapping: m_Tgt_C_S_FSS_Pty_Validation, workflow wf_FSS_Stage_Load.
-- Install schema is FSS_ETL_WRK in database MDM_ETL_FSS; all table
-- names below are unqualified, except the config table, which is
-- COMMON-qualified (COMMON.ETL_RUN_CONFIG_TBL).
-- Driver name and signature are EXACTLY as the current main procedure,
-- so every existing CALL still works.
--
-- WHAT THIS MAPPING DOES, IN PLAIN WORDS
--   Checks FSS clients and maintains the deactivation list every later FSS mapping reads: blank-named clients become exception rows; blank-named, deleted or all-inactive clients go to the deactivation log and get a new deactivation status row when they have none; clients with a status, with names, not deleted and not all-inactive get a reactivation status row.
--
-- BUSINESS FLOW (read this top to bottom -- it IS the business flow)
--   Step  5  CLEANUP_PREVIOUS_RUN  drop any work tables left by the
--                                  previous run (drops only, no
--                                  checkpoint), then rebuild from step 10
--   Step 10  SRC                    Source clients: last active registration or all-inactive rows
--   Step 20  ENRICHED               Standardised names + blank-name flag, current deactivation status, cross-reference state
--   Step 30  ROUTED                 Invalid-name / deactivation / reactivation groups, exception details, first-row-per-exception-key flag
--   ---- PUBLISH (one transaction; branches below, in order) --------
--   Step 50  PUBLISH_EXC            Invalid-name exceptions -> EXC_STG_BAD_REC_MEMB (EXCEPTION)
--   Step 60  PUBLISH_LOG            Deactivation log rows -> STG_FSS_PTY_INACTIVE_LOG (STATUS)
--   Step 70  PUBLISH_STS_NEW        New deactivation statuses -> STG_FSS_PTY_INACTIVE_STS (STATUS)
--   Step 80  PUBLISH_STS_REACTIVATION Reactivation statuses -> STG_FSS_PTY_INACTIVE_STS (STATUS)
--   End    TERMINATING             work tables are NOT dropped: they
--                                  stay in the database until the next
--                                  run of this mapping cleans them up
--
-- CONFIG-DRIVEN NOTES (COMMON.ETL_RUN_CONFIG_TBL)
--   * The driver reads IS_RUN_ENABLED (per STEP_NO) and
--     WORK_TABLES_CONSUMED (per STEP_NO) in ONE SELECT at the start.
--     Flags and consumed strings are pre-initialised to their defaults
--     ('Y' / the step's normal input), so a missing or unreadable
--     config table leaves every step enabled with its normal inputs:
--     the config can only disable steps, never break a run by absence.
--   * A driver row with STEP_NO = 0 and IS_RUN_ENABLED = 'N' skips the
--     WHOLE mapping before step 5 cleanup (no work tables are dropped).
--   * A step/branch row with IS_RUN_ENABLED = 'N' skips just that
--     step/branch: a SKIPPED checkpoint row is written and a plain-text
--     summary line is appended (helper36 is NOT used for skips -- it
--     renders NULL as '0 row(s)'). No other step is auto-skipped: if a
--     downstream step stays enabled while its input step was skipped,
--     that step's input-existence check raises the missing table
--     loudly instead of running on stale data. Disable downstream
--     steps explicitly if you disable an upstream one.
--   * Config columns IS_DEPENDENT, DEPENDENT_ON and
--     WORK_TABLES_PRODUCED are present in the table but are NOT read
--     by this driver; gating is by IS_RUN_ENABLED only.
--   * SKIPPED vocabulary: JOB_CONTROL_ETL.STEP_STATUS has NO CHECK
--     constraint (a DDL comment that in v2 lists STARTED | COMPLETED | FAILED | SKIPPED), so 'SKIPPED' rows are used here and are flagged to the
--     user as a choice to confirm.
--
-- TRANSACTION EDGES (framework rule)
--   Never call a checkpoint between BEGIN TRANSACTION and COMMIT.
--   Steps run (autocommitted) with their own checkpoints first; then
--   ONE publish transaction calls the branch procs (which contain NO
--   checkpoint calls and NO transaction control); then COMMIT; then,
--   and only then, the driver checkpoints each executed branch and
--   writes SKIPPED rows for skipped branches. The exception handler
--   ROLLBACKs first, then checkpoints, so its rows are not rolled back.
--
-- WORK TABLES (all TRANSIENT)
--   WRK_FSS_VAL_S1_SRC, WRK_FSS_VAL_S2_ENRICHED, WRK_FSS_VAL_S3_ROUTED.
--   They live in the same schema as the targets (unqualified names, as
--   in the original code) and are prefixed WRK_FSS_. They survive a
--   session crash (TRANSIENT, not TEMP), which is what makes inspection
--   after a run possible. No CURSOR was used: every step here is
--   set-based by design.
--
-- PARITY NOTES (kept deliberately, do not "fix" silently)
--   * Insert-only: no TRUNCATE, no DELETE of targets. The IDQ delete of STG_FSS_PTY_INACTIVE_STS for reactivations is NOT performed, exactly as in the main.
--   * PRESERVED: the reactivation branch writes its row to STG_FSS_PTY_INACTIVE_STS (the status table), not to the log table, as ported from the original. Because later mappings skip any key with a non-null status, a reactivated FSS client stays excluded -- confirm with the business.
--   * PRESERVED: a NULL capture action or inactive flag is not treated as not deleted / not inactive (a NULL comparison is not true), so such rows are not reactivated.
--   * PRESERVED: the commented-out testing source filters are not applied, exactly as in the original.
--   * The exception row writes the computed code with the looked-up description / type, and the source full name as the attribute value, exactly as in the original.
--   * A row can land in more than one publish branch, exactly as in the original INSERT ALL.
--
-- SIGNATURE
--   The original parameters are unchanged and in the same order, so
--   every existing CALL still works. One parameter was APPENDED:
--     P_JOB_RUN_ID   VARCHAR  DEFAULT NULL  -- NULL = start a new run
--                                             (a run id is generated and
--                                             returned in the summary).
--   A restart is simply a new run: the mapping cleans up the
--   previous run's work tables at its start (step 5) and runs
--   every step from scratch. There is no step-level restart.
--   Procedure-call return capture uses `l_rows := (CALL proc(...));`
--   (Snowflake Scripting scalar-call form) -- a compile-time
--   verification item, since there is no live Snowflake here.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_main_m_Tgt_C_S_FSS_Pty_Validation ()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    c_mapping    VARCHAR DEFAULT 'm_Tgt_C_S_FSS_Pty_Validation';
    l_run_ts     TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()::TIMESTAMP_NTZ;
    l_rows       NUMBER DEFAULT 0;
    l_summary    VARCHAR DEFAULT '';
BEGIN
    -- ---- Step 5: CLEANUP_PREVIOUS_RUN -- drop work tables left by a previous run
    -- Drops only, no checkpoint call for drops. UNCHANGED from current main.
    DROP TABLE IF EXISTS WRK_FSS_VAL_S1_SRC;
    DROP TABLE IF EXISTS WRK_FSS_VAL_S2_ENRICHED;
    DROP TABLE IF EXISTS WRK_FSS_VAL_S3_ROUTED;

    -- ---- Step 10: SRC
    l_rows := (CALL sp_snow_step_FSS_VAL_S10_SRC(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 10 SRC', :l_rows) || CHR(10);

    -- ---- Step 20: ENRICHED
    l_rows := (CALL sp_snow_step_FSS_VAL_S20_ENRICHED(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 20 ENRICHED', :l_rows) || CHR(10);

    -- ---- Step 30: ROUTED
    l_rows := (CALL sp_snow_step_FSS_VAL_S30_ROUTED(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 30 ROUTED', :l_rows) || CHR(10);

    -- ---- PUBLISH: ONE transaction, all branches, in order ----
    BEGIN TRANSACTION;
    l_rows := (CALL sp_snow_pub_FSS_VAL_EXC_STG_BAD_REC_MEMB());
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 50 PUBLISH_EXC', :l_rows) || CHR(10);
    l_rows := (CALL sp_snow_pub_FSS_VAL_STG_FSS_PTY_INACTIVE_LOG());
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 60 PUBLISH_LOG', :l_rows) || CHR(10);
    l_rows := (CALL sp_snow_pub_FSS_VAL_STG_FSS_PTY_INACTIVE_STS_NEW());
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 70 PUBLISH_STS_NEW', :l_rows) || CHR(10);
    l_rows := (CALL sp_snow_pub_FSS_VAL_STG_FSS_PTY_INACTIVE_STS_REACTIVATION());
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 80 PUBLISH_STS_REACTIVATION', :l_rows) || CHR(10);
    COMMIT;
    RETURN l_summary;
EXCEPTION
    WHEN OTHER THEN
        ROLLBACK;
        RAISE;
END;
$$;
