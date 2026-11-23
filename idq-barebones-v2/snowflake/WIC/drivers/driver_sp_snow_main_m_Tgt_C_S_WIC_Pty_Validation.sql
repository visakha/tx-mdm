-- ============================================================================
-- sp_snow_main_m_Tgt_C_S_WIC_Pty_Validation  --  BARE-BONES STEP DRIVER VARIANT (WIC)
--
-- IDQ mapping: m_Tgt_C_S_WIC_Pty_Validation, workflow wf_WIC_Stage_Load.
-- Install schema is WIC_ETL_WRK in database MDM_ETL_WIC; all table
-- names below are unqualified.
--
-- WHAT THIS MAPPING DOES, IN PLAIN WORDS
--   Checks the WIC parties and maintains the deactivation list every later WIC mapping reads. A party whose standardised first or last name is blank is logged as an exception, written to the deactivation log, and given a new deactivation-status row if it has none yet. A party that already has a status and now has both names present is written to the deactivation log as a reactivation.
--
-- BUSINESS FLOW (read this top to bottom -- it IS the business flow)
--     Step  5  CLEANUP_PREVIOUS_RUN  drop any work tables left by the previous run (drops only), then rebuild from step 10
--     Step 10   ENRICHED                 WRK_WIC_VAL_S10_ENRICHED
--     Step 20   NAMED_BLANK_TEST         WRK_WIC_VAL_S20_NAMED
--     Step 30   ROUTED                   WRK_WIC_VAL_S30_ROUTED
--     Step 40   PUBLISH_EXC_STG_BAD_REC_MEMB EXC_STG_BAD_REC_MEMB (EXCEPTION)
--     Step 50   PUBLISH_STG_WIC_PTY_INACTIVE_LOG_DEACTIVATION STG_WIC_PTY_INACTIVE_LOG (STATUS)
--     Step 60   PUBLISH_STG_WIC_PTY_INACTIVE_STS STG_WIC_PTY_INACTIVE_STS (STATUS)
--     Step 70   PUBLISH_STG_WIC_PTY_INACTIVE_LOG_REACTIVATION STG_WIC_PTY_INACTIVE_LOG (STATUS)
--     End    work tables are NOT dropped: they stay in the database until the next run of this mapping cleans them up
--
-- BARE-BONES VARIANT
--   No config gating, no job tracking, no input checks, no seed data.
--   Every step and every publish branch runs, unconditionally, in order.
--   Steps run autocommitted; publish runs as ONE transaction covering all
--   branches. The driver RETURNs the combined summary string l_summary.
--   A restart is simply a new run: the mapping cleans up the previous
--   run's work tables at its start (step 5) and runs every step fresh.
--   Procedure-call return capture uses `l_rows := (CALL proc(...));`
--   (Snowflake Scripting scalar-call form).
--
-- WORK TABLES (all TRANSIENT)
--   WRK_WIC_VAL_S10_ENRICHED, WRK_WIC_VAL_S20_NAMED, WRK_WIC_VAL_S30_ROUTED. They live in the same schema as the targets
--   (unqualified names, as in the original code) and are prefixed WRK_WIC_.
--   They survive a session crash (TRANSIENT, not TEMP), which is what
--   makes inspection after a run possible. No CURSOR was used: every step
--   here is set-based by design.
--
-- PARITY NOTES (kept deliberately, do not "fix" silently)
--   * Insert-only: the IDQ delete of STG_WIC_PTY_INACTIVE_STS is NOT performed. A reactivation therefore only writes a log row; the status row stays, so the party stays excluded by the downstream NOT EXISTS filters until something else removes the status row. This is the Snowflake Yes/No reactivation verdict for WIC (IDQ re-admits via Upd_Delete_Inactive, which the Snowflake code does not perform).
--   * Deactivation detection is pure ETL interpretation: no source deactivation flag is read. Only the blank-standardised-name test (name_missing) drives deactivation and reactivation.
--   * The cross-reference lookup filters on TRIM(ROWID_SYSTEM) = WIC.
--   * No timeline handling in this mapping (no VERSION_SEQ).
--   * Step 30 (and therefore the publish) is computed before any publish INSERT runs, so all routing sees the pre-run deactivation status, as in the original single INSERT ALL.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_main_m_Tgt_C_S_WIC_Pty_Validation (
)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    c_mapping    VARCHAR DEFAULT 'm_Tgt_C_S_WIC_Pty_Validation';
    l_run_ts     TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()::TIMESTAMP_NTZ;
    l_rows       NUMBER DEFAULT 0;
    l_summary    VARCHAR DEFAULT '';
    -- Per-branch publish counts (one variable per branch)
BEGIN
    -- ---- Step 5: CLEANUP_PREVIOUS_RUN -- drop work tables left by a previous run
    DROP TABLE IF EXISTS WRK_WIC_VAL_S10_ENRICHED;
    DROP TABLE IF EXISTS WRK_WIC_VAL_S20_NAMED;
    DROP TABLE IF EXISTS WRK_WIC_VAL_S30_ROUTED;

    -- ---- Step 10: ENRICHED
    l_rows := (CALL sp_snow_step_WIC_VAL_S10_ENRICHED(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 10 ENRICHED', :l_rows) || CHR(10);

    -- ---- Step 20: NAMED_BLANK_TEST
    l_rows := (CALL sp_snow_step_WIC_VAL_S20_NAMED(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 20 NAMED_BLANK_TEST', :l_rows) || CHR(10);

    -- ---- Step 30: ROUTED
    l_rows := (CALL sp_snow_step_WIC_VAL_S30_ROUTED(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 30 ROUTED', :l_rows) || CHR(10);

    -- ---- PUBLISH: ONE transaction, all branches, in order ----
    BEGIN TRANSACTION;
    l_rows := (CALL sp_snow_pub_WIC_VAL_EXC_STG_BAD_REC_MEMB());
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 40 PUBLISH_EXC_STG_BAD_REC_MEMB', :l_rows) || CHR(10);
    l_rows := (CALL sp_snow_pub_WIC_VAL_STG_WIC_PTY_INACTIVE_LOG_DEACTIVATION());
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 50 PUBLISH_STG_WIC_PTY_INACTIVE_LOG_DEACTIVATION', :l_rows) || CHR(10);
    l_rows := (CALL sp_snow_pub_WIC_VAL_STG_WIC_PTY_INACTIVE_STS());
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 60 PUBLISH_STG_WIC_PTY_INACTIVE_STS', :l_rows) || CHR(10);
    l_rows := (CALL sp_snow_pub_WIC_VAL_STG_WIC_PTY_INACTIVE_LOG_REACTIVATION());
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 70 PUBLISH_STG_WIC_PTY_INACTIVE_LOG_REACTIVATION', :l_rows) || CHR(10);
    COMMIT;


    RETURN l_summary;
EXCEPTION
    WHEN OTHER THEN
        ROLLBACK;
        RAISE;
END;
$$;
