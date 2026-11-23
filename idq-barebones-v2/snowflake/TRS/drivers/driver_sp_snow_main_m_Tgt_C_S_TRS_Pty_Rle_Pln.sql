-- ============================================================================
-- sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Pln  --  BARE-BONES STEP DRIVER (TRS)
--
-- IDQ mapping: m_Tgt_C_S_TRS_Pty_Rle_Pln, workflow wf_TRS_Stage_Load_1_Ongoing.
-- Bare-bones variant: no run-config table, no job-control calls, no
-- flags. Every step runs unconditionally, in order, and every step
-- and branch appends one line to the summary string via
-- fn_snow_helper36_common. Step 5 drops the mapping work tables
-- (bare drops); work tables are NOT dropped at the end of a run and
-- stay in the database until the next run of this mapping cleans
-- them up. Publish is ONE transaction: all branch calls, then COMMIT.
-- On error: ROLLBACK + RAISE. The driver RETURNs l_summary.
--
-- BUSINESS FLOW (read this top to bottom -- it IS the business flow)
--     Step  10  MANAGED_CARE_SRC                              WRK_TRS_PLN_S10_SRC
--     Step  20  PLAN_TRANSLATED                               WRK_TRS_PLN_S20_PLANNED
--     Step  30  RANKED                                        WRK_TRS_PLN_S30_RANKED
--     Step  40  PUBLISH_C_S_TRS_PTY_RLE_PLN                   C_S_TRS_PTY_RLE_PLN (publish)
--     Step  50  PUBLISH_EXC_STG_BAD_REC_MEMB                  EXC_STG_BAD_REC_MEMB (publish)
--
-- PARITY NOTES (kept deliberately, do not "fix" silently; condensed
-- from the current main header -- see the manifest for the full text)
----   (kept deliberately, do not "fix" silently)
--     * Insert-only, as in the original Snowflake code: no TRUNCATE, no
--       DELETE of the targets.  IDQ truncates C_S_TRS_PTY_RLE_PLN; the
--       Snowflake version instead skips keys already present (the
--       existing-key guard in step 30) and keeps the last row per key in
--       this run.  A re-run therefore inserts nothing twice, but it also
--       does not remove rows that IDQ would have truncated away -- see
--       the User Guide, "Parity gaps".
--     * Rows whose begin date is NOT before the end date (including
--       begin = end) are dropped by the step-10 source filter, silently:
--       they are neither loaded nor exceptioned, exactly as in the
--       original.  Open-ended rows (END_DT IS NULL) do load.
--     * The plan lookup is under source system 'MAX', not 'TRS', as in the
--       original -- preserved, not "corrected".
--
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Pln (
)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    c_mapping    VARCHAR DEFAULT 'm_Tgt_C_S_TRS_Pty_Rle_Pln';
    l_run_ts     TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()::TIMESTAMP_NTZ;
    l_rows       NUMBER DEFAULT 0;
    l_summary    VARCHAR DEFAULT '';
BEGIN
    -- ---- Step 5: CLEANUP_PREVIOUS_RUN -- drop work tables left by a previous run
    DROP TABLE IF EXISTS WRK_TRS_PLN_S10_SRC;
    DROP TABLE IF EXISTS WRK_TRS_PLN_S20_PLANNED;
    DROP TABLE IF EXISTS WRK_TRS_PLN_S30_RANKED;

    -- ---- Step 10: MANAGED_CARE_SRC
    l_rows := (CALL sp_snow_step_TRS_PLN_S10_SRC(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 10 MANAGED_CARE_SRC', :l_rows) || CHR(10);

    -- ---- Step 20: PLAN_TRANSLATED
    l_rows := (CALL sp_snow_step_TRS_PLN_S20_PLANNED(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 20 PLAN_TRANSLATED', :l_rows) || CHR(10);

    -- ---- Step 30: RANKED
    l_rows := (CALL sp_snow_step_TRS_PLN_S30_RANKED(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 30 RANKED', :l_rows) || CHR(10);

    -- ---- PUBLISH: ONE transaction, all branches, in order ----
    BEGIN TRANSACTION;
    l_rows := (CALL sp_snow_pub_TRS_PLN_C_S_TRS_PTY_RLE_PLN());
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 40 PUBLISH_C_S_TRS_PTY_RLE_PLN', :l_rows) || CHR(10);
    l_rows := (CALL sp_snow_pub_TRS_PLN_EXC_STG_BAD_REC_MEMB());
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 50 PUBLISH_EXC_STG_BAD_REC_MEMB', :l_rows) || CHR(10);
    COMMIT;

    RETURN l_summary;
EXCEPTION
    WHEN OTHER THEN
        ROLLBACK;
        RAISE;
END;
$$;
