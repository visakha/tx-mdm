-- ============================================================================
-- sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Phn_And_EAddr  --  BARE-BONES STEP DRIVER (TRS)
--
-- IDQ mapping: m_Tgt_C_S_TRS_Pty_Rle_Phn_And_EAddr, workflow wf_TRS_Stage_Load_1_Ongoing.
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
--     Step  10  SRC_CASE_DELTA                                WRK_TRS_PHN_S1_SRC
--     Step  20  PHONE_SLOTS                                   WRK_TRS_PHN_S2_SLOTS
--     Step  30  PHONES_CHECKED                                WRK_TRS_PHN_S3_CHECKED
--     Step  40  PHONES                                        WRK_TRS_PHN_S4_PHONES
--     Step  50  PHN_VERSIONS                                  WRK_TRS_PHN_S5_VERSIONS
--     Step  60  EMAILS_CHECKED                                WRK_TRS_PHN_S6_EMAILS
--     Step  70  EADDR_VERSIONS                                WRK_TRS_PHN_S7_VERSIONS
--     Step  80  PUBLISH_C_S_TRS_PTY_RLE_PHN                   C_S_TRS_PTY_RLE_PHN (publish)
--     Step  90  PUBLISH_EXC_PHONE                             EXC_STG_BAD_REC_MEMB (publish)
--     Step 100  PUBLISH_C_S_TRS_PTY_RLE_EADDR                 C_S_TRS_PTY_RLE_EADDR (publish)
--     Step 110  PUBLISH_EXC_EMAIL                             EXC_STG_BAD_REC_MEMB (publish)
--
-- PARITY NOTES (kept deliberately, do not "fix" silently; condensed
-- from the current main header -- see the manifest for the full text)
----   (kept deliberately, do not "fix" silently)
--     * Insert-only, as in the original Snowflake code: no TRUNCATE, no
--       DELETE of targets.  IDQ truncates C_S_TRS_PTY_RLE_PHN and
--       C_S_TRS_PTY_RLE_EADDR; the Snowflake version instead skips keys
--       already present (uq_tgt).  A re-run therefore inserts nothing
--       twice, but it also does not remove rows that IDQ would have
--       truncated away.
--     * The stored source filter rownum < 100000 is NOT applied here,
--       exactly as in the original Snowflake code (it was not part of the
--       custom query).  Confirm whether it should be (BR notes, Verify
--       item 2).
--     * Inside the phone normalizer, the three rule instances get ONLY
--       the phone: their SRC_SYS and USG_TP inputs are not linked, so the
--       TRS / main-number toll-free check of the rule never runs here.
--
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Phn_And_EAddr (
)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    c_mapping    VARCHAR DEFAULT 'm_Tgt_C_S_TRS_Pty_Rle_Phn_And_EAddr';
    l_run_ts     TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()::TIMESTAMP_NTZ;
    l_rows       NUMBER DEFAULT 0;
    l_summary    VARCHAR DEFAULT '';
BEGIN
    -- ---- Step 5: CLEANUP_PREVIOUS_RUN -- drop work tables left by a previous run
    DROP TABLE IF EXISTS WRK_TRS_PHN_S1_SRC;
    DROP TABLE IF EXISTS WRK_TRS_PHN_S2_SLOTS;
    DROP TABLE IF EXISTS WRK_TRS_PHN_S3_CHECKED;
    DROP TABLE IF EXISTS WRK_TRS_PHN_S4_PHONES;
    DROP TABLE IF EXISTS WRK_TRS_PHN_S5_VERSIONS;
    DROP TABLE IF EXISTS WRK_TRS_PHN_S6_EMAILS;
    DROP TABLE IF EXISTS WRK_TRS_PHN_S7_VERSIONS;

    -- ---- Step 10: SRC_CASE_DELTA
    l_rows := (CALL sp_snow_step_TRS_PHN_S10_SRC(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 10 SRC_CASE_DELTA', :l_rows) || CHR(10);

    -- ---- Step 20: PHONE_SLOTS
    l_rows := (CALL sp_snow_step_TRS_PHN_S20_SLOTS(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 20 PHONE_SLOTS', :l_rows) || CHR(10);

    -- ---- Step 30: PHONES_CHECKED
    l_rows := (CALL sp_snow_step_TRS_PHN_S30_CHECKED(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 30 PHONES_CHECKED', :l_rows) || CHR(10);

    -- ---- Step 40: PHONES
    l_rows := (CALL sp_snow_step_TRS_PHN_S40_PHONES(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 40 PHONES', :l_rows) || CHR(10);

    -- ---- Step 50: PHN_VERSIONS
    l_rows := (CALL sp_snow_step_TRS_PHN_S50_VERSIONS(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 50 PHN_VERSIONS', :l_rows) || CHR(10);

    -- ---- Step 60: EMAILS_CHECKED
    l_rows := (CALL sp_snow_step_TRS_PHN_S60_EMAILS(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 60 EMAILS_CHECKED', :l_rows) || CHR(10);

    -- ---- Step 70: EADDR_VERSIONS
    l_rows := (CALL sp_snow_step_TRS_PHN_S70_EADDR(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 70 EADDR_VERSIONS', :l_rows) || CHR(10);

    -- ---- PUBLISH: ONE transaction, all branches, in order ----
    BEGIN TRANSACTION;
    l_rows := (CALL sp_snow_pub_TRS_PHN_C_S_TRS_PTY_RLE_PHN(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 80 PUBLISH_C_S_TRS_PTY_RLE_PHN', :l_rows) || CHR(10);
    l_rows := (CALL sp_snow_pub_TRS_PHN_EXC_STG_BAD_REC_MEMB_PHONE(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 90 PUBLISH_EXC_PHONE', :l_rows) || CHR(10);
    l_rows := (CALL sp_snow_pub_TRS_PHN_C_S_TRS_PTY_RLE_EADDR(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 100 PUBLISH_C_S_TRS_PTY_RLE_EADDR', :l_rows) || CHR(10);
    l_rows := (CALL sp_snow_pub_TRS_PHN_EXC_STG_BAD_REC_MEMB_EMAIL(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 110 PUBLISH_EXC_EMAIL', :l_rows) || CHR(10);
    COMMIT;

    RETURN l_summary;
EXCEPTION
    WHEN OTHER THEN
        ROLLBACK;
        RAISE;
END;
$$;
