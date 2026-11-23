-- ============================================================================
-- sp_snow_main_m_Tgt_C_S_WIC_Pty_Rle_Alt_Id  --  BARE-BONES STEP DRIVER VARIANT (WIC)
--
-- IDQ mapping: m_Tgt_C_S_WIC_Pty_Rle_Alt_Id, workflow wf_WIC_Stage_Load.
-- Install schema is WIC_ETL_WRK in database MDM_ETL_WIC; all table
-- names below are unqualified.
--
-- WHAT THIS MAPPING DOES, IN PLAIN WORDS
--   Writes one alternate id per active WIC party: the WIC id padded to 12, type 020 for SOURCE_TABLE CLIENT and 021 otherwise. Parties with a deactivation status are excluded; keys already in the target are skipped.
--
-- BUSINESS FLOW (read this top to bottom -- it IS the business flow)
--     Step  5  CLEANUP_PREVIOUS_RUN  drop any work tables left by the previous run (drops only), then rebuild from step 10
--     Step 10   KEYS                     WRK_WIC_ALT_S10_KEYS
--     Step 20   READY                    WRK_WIC_ALT_S20_READY
--     Step 30   PUBLISH_C_S_WIC_PTY_RLE_ALT_ID C_S_WIC_PTY_RLE_ALT_ID (SPINE)
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
--   WRK_WIC_ALT_S10_KEYS, WRK_WIC_ALT_S20_READY. They live in the same schema as the targets
--   (unqualified names, as in the original code) and are prefixed WRK_WIC_.
--   They survive a session crash (TRANSIENT, not TEMP), which is what
--   makes inspection after a run possible. No CURSOR was used: every step
--   here is set-based by design.
--
-- PARITY NOTES (kept deliberately, do not "fix" silently)
--   * Thin split, flagged in the multisource step map: this original has no CTE chain, it is a single query (an inner derived table plus an outer SELECT). Step 10 builds the keys (the original inner derived table) and step 20 applies the deactivation filter, the already-loaded guard and the one-row-per-key rank (the original outer SELECT). No business expression was changed.
--   * Insert-only: IDQ truncate of C_S_WIC_PTY_RLE_ALT_ID is not performed.
--   * HUB_STATE_IND is not linked (left to the column default).
--   * VERSION_SEQ = 1; PERIOD_START_DATE = DATEKEY; no validation rule runs in this mapping.
--   * The publish INSERT uses the run timestamp directly (not a materialised run_ts column), so this publish proc is the one WIC publish proc in which P_RUN_TS is actually used in the body.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_main_m_Tgt_C_S_WIC_Pty_Rle_Alt_Id (
)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    c_mapping    VARCHAR DEFAULT 'm_Tgt_C_S_WIC_Pty_Rle_Alt_Id';
    l_run_ts     TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()::TIMESTAMP_NTZ;
    l_rows       NUMBER DEFAULT 0;
    l_summary    VARCHAR DEFAULT '';
    -- Per-branch publish counts (one variable per branch)
BEGIN
    -- ---- Step 5: CLEANUP_PREVIOUS_RUN -- drop work tables left by a previous run
    DROP TABLE IF EXISTS WRK_WIC_ALT_S10_KEYS;
    DROP TABLE IF EXISTS WRK_WIC_ALT_S20_READY;

    -- ---- Step 10: KEYS
    l_rows := (CALL sp_snow_step_WIC_ALT_S10_KEYS(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 10 KEYS', :l_rows) || CHR(10);

    -- ---- Step 20: READY
    l_rows := (CALL sp_snow_step_WIC_ALT_S20_READY(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 20 READY', :l_rows) || CHR(10);

    -- ---- PUBLISH: ONE transaction, all branches, in order ----
    BEGIN TRANSACTION;
    l_rows := (CALL sp_snow_pub_WIC_ALT_C_S_WIC_PTY_RLE_ALT_ID(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 30 PUBLISH_C_S_WIC_PTY_RLE_ALT_ID', :l_rows) || CHR(10);
    COMMIT;


    RETURN l_summary;
EXCEPTION
    WHEN OTHER THEN
        ROLLBACK;
        RAISE;
END;
$$;
