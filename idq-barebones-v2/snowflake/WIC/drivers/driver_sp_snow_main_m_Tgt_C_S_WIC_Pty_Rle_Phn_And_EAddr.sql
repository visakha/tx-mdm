-- ============================================================================
-- sp_snow_main_m_Tgt_C_S_WIC_Pty_Rle_Phn_And_EAddr  --  BARE-BONES STEP DRIVER VARIANT (WIC)
--
-- IDQ mapping: m_Tgt_C_S_WIC_Pty_Rle_Phn_And_EAddr, workflow wf_WIC_Stage_Load.
-- Install schema is WIC_ETL_WRK in database MDM_ETL_WIC; all table
-- names below are unqualified.
--
-- WHAT THIS MAPPING DOES, IN PLAIN WORDS
--   Each active WIC row gives one phone and possibly one e-mail. Good phones load, bad phones are logged. Non-null e-mails are validated the same way: valid e-mails load, bad e-mails are logged.
--
-- BUSINESS FLOW (read this top to bottom -- it IS the business flow)
--     Step  5  CLEANUP_PREVIOUS_RUN  drop any work tables left by the previous run (drops only), then rebuild from step 10
--     Step 10   SRC                      WRK_WIC_PHN_S10_SRC
--     Step 20   CHECKED                  WRK_WIC_PHN_S20_CHECKED
--     Step 30   ROUTED                   WRK_WIC_PHN_S30_ROUTED
--     Step 40   READY                    WRK_WIC_PHN_S40_READY
--     Step 50   PUBLISH_C_S_WIC_PTY_RLE_PHN C_S_WIC_PTY_RLE_PHN (SPINE)
--     Step 60   PUBLISH_EXC_STG_BAD_REC_MEMB_PHONE EXC_STG_BAD_REC_MEMB (EXCEPTION)
--     Step 70   PUBLISH_C_S_WIC_PTY_RLE_EADDR C_S_WIC_PTY_RLE_EADDR (SPINE)
--     Step 80   PUBLISH_EXC_STG_BAD_REC_MEMB_EMAIL EXC_STG_BAD_REC_MEMB (EXCEPTION)
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
--   WRK_WIC_PHN_S10_SRC, WRK_WIC_PHN_S20_CHECKED, WRK_WIC_PHN_S30_ROUTED, WRK_WIC_PHN_S40_READY. They live in the same schema as the targets
--   (unqualified names, as in the original code) and are prefixed WRK_WIC_.
--   They survive a session crash (TRANSIENT, not TEMP), which is what
--   makes inspection after a run possible. No CURSOR was used: every step
--   here is set-based by design.
--
-- PARITY NOTES (kept deliberately, do not "fix" silently)
--   * Insert-only: IDQ truncates of the phone and e-mail targets are not performed.
--   * No null-phone filter: a party without a phone is validated and logged as an invalid phone.
--   * The e-mail key uses the e-mail as read (no trim).
--   * The phone routing groups overlap by construction: a Missing_AreaCode code counts as both good and bad, so the original INSERT ALL would write such a row to both the phone table and the exception table, and the publish INSERTs keep the same WHEN conditions (the original header notes Missing_AreaCode only exists for ECI, so WIC never gets it in practice).
--   * VERSION_SEQ is 1 on both targets; PERIOD_START_DATE = DATEKEY.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_main_m_Tgt_C_S_WIC_Pty_Rle_Phn_And_EAddr (
)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    c_mapping    VARCHAR DEFAULT 'm_Tgt_C_S_WIC_Pty_Rle_Phn_And_EAddr';
    l_run_ts     TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()::TIMESTAMP_NTZ;
    l_rows       NUMBER DEFAULT 0;
    l_summary    VARCHAR DEFAULT '';
    -- Per-branch publish counts (one variable per branch)
BEGIN
    -- ---- Step 5: CLEANUP_PREVIOUS_RUN -- drop work tables left by a previous run
    DROP TABLE IF EXISTS WRK_WIC_PHN_S10_SRC;
    DROP TABLE IF EXISTS WRK_WIC_PHN_S20_CHECKED;
    DROP TABLE IF EXISTS WRK_WIC_PHN_S30_ROUTED;
    DROP TABLE IF EXISTS WRK_WIC_PHN_S40_READY;

    -- ---- Step 10: SRC
    l_rows := (CALL sp_snow_step_WIC_PHN_S10_SRC(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 10 SRC', :l_rows) || CHR(10);

    -- ---- Step 20: CHECKED
    l_rows := (CALL sp_snow_step_WIC_PHN_S20_CHECKED(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 20 CHECKED', :l_rows) || CHR(10);

    -- ---- Step 30: ROUTED
    l_rows := (CALL sp_snow_step_WIC_PHN_S30_ROUTED(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 30 ROUTED', :l_rows) || CHR(10);

    -- ---- Step 40: READY
    l_rows := (CALL sp_snow_step_WIC_PHN_S40_READY(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 40 READY', :l_rows) || CHR(10);

    -- ---- PUBLISH: ONE transaction, all branches, in order ----
    BEGIN TRANSACTION;
    l_rows := (CALL sp_snow_pub_WIC_PHN_C_S_WIC_PTY_RLE_PHN());
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 50 PUBLISH_C_S_WIC_PTY_RLE_PHN', :l_rows) || CHR(10);
    l_rows := (CALL sp_snow_pub_WIC_PHN_EXC_STG_BAD_REC_MEMB_PHONE());
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 60 PUBLISH_EXC_STG_BAD_REC_MEMB_PHONE', :l_rows) || CHR(10);
    l_rows := (CALL sp_snow_pub_WIC_PHN_C_S_WIC_PTY_RLE_EADDR());
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 70 PUBLISH_C_S_WIC_PTY_RLE_EADDR', :l_rows) || CHR(10);
    l_rows := (CALL sp_snow_pub_WIC_PHN_EXC_STG_BAD_REC_MEMB_EMAIL());
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 80 PUBLISH_EXC_STG_BAD_REC_MEMB_EMAIL', :l_rows) || CHR(10);
    COMMIT;


    RETURN l_summary;
EXCEPTION
    WHEN OTHER THEN
        ROLLBACK;
        RAISE;
END;
$$;
