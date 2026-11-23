-- ============================================================================
-- sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_TOA  --  BARE-BONES STEP DRIVER (TRS)
--
-- IDQ mapping: m_Tgt_C_S_TRS_Pty_Rle_TOA, workflow wf_TRS_Stage_Load_1_Ongoing.
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
--     Step  10  TOA_SRC_RANKED                                WRK_TRS_TOA_S10_RAW
--     Step  20  TOA_LATEST                                    WRK_TRS_TOA_S20_SRC
--     Step  30  TOA_KEYED                                     WRK_TRS_TOA_S30_KEYED
--     Step  40  TOA_RANKED                                    WRK_TRS_TOA_S40_RANKED
--     Step  50  PUBLISH_EXC_BAD_VALUE                         EXC_STG_BAD_REC_MEMB (publish)
--     Step  60  PUBLISH_EXC_DATES                             EXC_STG_BAD_REC_MEMB (publish)
--     Step  70  PUBLISH_C_S_TRS_PTY_RLE_TOA                   C_S_TRS_PTY_RLE_TOA (publish)
--
-- PARITY NOTES (kept deliberately, do not "fix" silently; condensed
-- from the current main header -- see the manifest for the full text)
----   (kept deliberately, do not "fix" silently)
--     * Insert-only, as in the original Snowflake code: no TRUNCATE, no
--       DELETE of the targets.  IDQ truncates C_S_TRS_PTY_RLE_TOA; the
--       Snowflake version instead skips keys already present (the uq_*
--       flags in step 40).  A re-run therefore inserts nothing twice,
--       but it also does not remove rows that IDQ would have truncated
--       away -- see the User Guide, "Parity gaps".
--     * The Bad_Value exception row writes the looked-up EXCEPTION_CODE
--       for 'Invalid_TOA', which is NULL when that code is not configured
--       in EXC_LOOKUP_CODE_VALUE -- preserved, not defaulted.  The date
--       exception row writes the computed code
--       'Period_Start_Date_>_Period_End_Date'.
--     * The original source carries only the MCI_EDG_INDV branch
--       (SRC_TBL = 'MCI_EDG_INDV', decoded to source 'TIERS'); the
--
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_TOA (
)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    c_mapping    VARCHAR DEFAULT 'm_Tgt_C_S_TRS_Pty_Rle_TOA';
    l_run_ts     TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()::TIMESTAMP_NTZ;
    l_rows       NUMBER DEFAULT 0;
    l_summary    VARCHAR DEFAULT '';
BEGIN
    -- ---- Step 5: CLEANUP_PREVIOUS_RUN -- drop work tables left by a previous run
    DROP TABLE IF EXISTS WRK_TRS_TOA_S10_RAW;
    DROP TABLE IF EXISTS WRK_TRS_TOA_S20_SRC;
    DROP TABLE IF EXISTS WRK_TRS_TOA_S30_KEYED;
    DROP TABLE IF EXISTS WRK_TRS_TOA_S40_RANKED;

    -- ---- Step 10: TOA_SRC_RANKED
    l_rows := (CALL sp_snow_step_TRS_TOA_S10_RAW(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 10 TOA_SRC_RANKED', :l_rows) || CHR(10);

    -- ---- Step 20: TOA_LATEST
    l_rows := (CALL sp_snow_step_TRS_TOA_S20_LATEST(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 20 TOA_LATEST', :l_rows) || CHR(10);

    -- ---- Step 30: TOA_KEYED
    l_rows := (CALL sp_snow_step_TRS_TOA_S30_KEYED(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 30 TOA_KEYED', :l_rows) || CHR(10);

    -- ---- Step 40: TOA_RANKED
    l_rows := (CALL sp_snow_step_TRS_TOA_S40_RANKED(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 40 TOA_RANKED', :l_rows) || CHR(10);

    -- ---- PUBLISH: ONE transaction, all branches, in order ----
    BEGIN TRANSACTION;
    l_rows := (CALL sp_snow_pub_TRS_TOA_EXC_STG_BAD_REC_MEMB_BAD_VALUE());
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 50 PUBLISH_EXC_BAD_VALUE', :l_rows) || CHR(10);
    l_rows := (CALL sp_snow_pub_TRS_TOA_EXC_STG_BAD_REC_MEMB_DATES());
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 60 PUBLISH_EXC_DATES', :l_rows) || CHR(10);
    l_rows := (CALL sp_snow_pub_TRS_TOA_C_S_TRS_PTY_RLE_TOA());
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 70 PUBLISH_C_S_TRS_PTY_RLE_TOA', :l_rows) || CHR(10);
    COMMIT;

    RETURN l_summary;
EXCEPTION
    WHEN OTHER THEN
        ROLLBACK;
        RAISE;
END;
$$;
