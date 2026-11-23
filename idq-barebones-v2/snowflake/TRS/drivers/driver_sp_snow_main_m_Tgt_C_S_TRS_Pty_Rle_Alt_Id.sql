-- ============================================================================
-- sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Alt_Id  --  BARE-BONES STEP DRIVER (TRS)
--
-- IDQ mapping: m_Tgt_C_S_TRS_Pty_Rle_Alt_Id, workflow wf_TRS_Stage_Load_1_Ongoing.
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
--     Step  10  SRC_DEDUP                                     WRK_TRS_ALT_S1_SRC
--     Step  20  SSN_VALIDATED                                 WRK_TRS_ALT_S2_SSN
--     Step  30  NORMALIZED                                    WRK_TRS_ALT_S3_NORM
--     Step  40  ROUTED                                        WRK_TRS_ALT_S4_ROUTED
--     Step  50  PUBLISH_C_S_TRS_PTY_RLE_ALT_ID                C_S_TRS_PTY_RLE_ALT_ID (publish)
--     Step  60  PUBLISH_EXC_STG_BAD_REC_MEMB                  EXC_STG_BAD_REC_MEMB (publish)
--
-- PARITY NOTES (kept deliberately, do not "fix" silently; condensed
-- from the current main header -- see the manifest for the full text)
----   (kept deliberately, do not "fix" silently)
--     * Insert-only, as in the original Snowflake code: no TRUNCATE, no
--       DELETE of targets.  IDQ truncates C_S_TRS_PTY_RLE_ALT_ID; the
--       Snowflake version instead skips keys already present (uq_alt_id).
--       A re-run therefore inserts nothing twice, but it also does not
--       remove rows that IDQ would have truncated away.
--     * The stored source filter INDV_ID = 504937068 is NOT applied here,
--       exactly as in the original Snowflake code (it was not part of the
--       custom query).  Confirm in the live IDQ mapping whether it should
--       be (BR notes, Verify item 1).
--     * VERSION_SEQ is hard-coded to 1 (TIMELINE: the rank is commented out
--       in IDQ), so the rank filter keeps EVERY row.  PERIOD_END_DATE,
--       PERIOD_REFERENCE_TIME and TIMELINE_ACTION are NULL (unfed ports).
--     * ROWID_OBJECT, DELETED_*, UPDATED_BY, CREATOR and HUB_STATE_IND
--
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Alt_Id (
)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    c_mapping    VARCHAR DEFAULT 'm_Tgt_C_S_TRS_Pty_Rle_Alt_Id';
    l_run_ts     TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()::TIMESTAMP_NTZ;
    l_rows       NUMBER DEFAULT 0;
    l_summary    VARCHAR DEFAULT '';
BEGIN
    -- ---- Step 5: CLEANUP_PREVIOUS_RUN -- drop work tables left by a previous run
    DROP TABLE IF EXISTS WRK_TRS_ALT_S1_SRC;
    DROP TABLE IF EXISTS WRK_TRS_ALT_S2_SSN;
    DROP TABLE IF EXISTS WRK_TRS_ALT_S3_NORM;
    DROP TABLE IF EXISTS WRK_TRS_ALT_S4_ROUTED;

    -- ---- Step 10: SRC_DEDUP
    l_rows := (CALL sp_snow_step_TRS_ALT_S10_SRC(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 10 SRC_DEDUP', :l_rows) || CHR(10);

    -- ---- Step 20: SSN_VALIDATED
    l_rows := (CALL sp_snow_step_TRS_ALT_S20_SSN(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 20 SSN_VALIDATED', :l_rows) || CHR(10);

    -- ---- Step 30: NORMALIZED
    l_rows := (CALL sp_snow_step_TRS_ALT_S30_NORM(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 30 NORMALIZED', :l_rows) || CHR(10);

    -- ---- Step 40: ROUTED
    l_rows := (CALL sp_snow_step_TRS_ALT_S40_ROUTED(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 40 ROUTED', :l_rows) || CHR(10);

    -- ---- PUBLISH: ONE transaction, all branches, in order ----
    BEGIN TRANSACTION;
    l_rows := (CALL sp_snow_pub_TRS_ALT_C_S_TRS_PTY_RLE_ALT_ID(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 50 PUBLISH_C_S_TRS_PTY_RLE_ALT_ID', :l_rows) || CHR(10);
    l_rows := (CALL sp_snow_pub_TRS_ALT_EXC_STG_BAD_REC_MEMB(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 60 PUBLISH_EXC_STG_BAD_REC_MEMB', :l_rows) || CHR(10);
    COMMIT;

    RETURN l_summary;
EXCEPTION
    WHEN OTHER THEN
        ROLLBACK;
        RAISE;
END;
$$;
