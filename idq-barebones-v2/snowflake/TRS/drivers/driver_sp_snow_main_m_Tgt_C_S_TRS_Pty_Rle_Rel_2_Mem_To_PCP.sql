-- ============================================================================
-- sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Rel_2_Mem_To_PCP  --  BARE-BONES STEP DRIVER (TRS)
--
-- IDQ mapping: m_Tgt_C_S_TRS_Pty_Rle_Rel_2_Mem_To_PCP, workflow wf_TRS_Stage_Load_1_Ongoing.
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
--     Step  10  SRC_MANAGED_CARE                              WRK_TRS_REL2_S1_SRC
--     Step  20  KEYED                                         WRK_TRS_REL2_S2_KEYED
--     Step  30  ROUTER_EXCEPTIONS                             WRK_TRS_REL2_S3_ROUTER
--     Step  40  CONSOLIDATED                                  WRK_TRS_REL2_S4_CONSOL
--     Step  50  PREPARED                                      WRK_TRS_REL2_S5_PREP
--     Step  60  TIMELINE                                      WRK_TRS_REL2_S6_TIMELINE
--     Step  70  PUBLISH_EXC_DATES                             EXC_STG_BAD_REC_MEMB (publish)
--     Step  80  PUBLISH_EXC_DEFAULT                           EXC_STG_BAD_REC_MEMB (publish)
--     Step  90  PUBLISH_C_S_TRS_PTY_RLE_REL_PROV              C_S_TRS_PTY_RLE_REL_PROV (publish)
--
-- PARITY NOTES (kept deliberately, do not "fix" silently; condensed
-- from the current main header -- see the manifest for the full text)
----   (kept deliberately, do not "fix" silently)
--     * Insert-only, as in the original Snowflake code: no TRUNCATE, no
--       DELETE of targets.  IDQ truncates C_S_TRS_PTY_RLE_REL_PROV; the
--       Snowflake version instead skips keys already present (uq_rel).
--       A re-run therefore inserts nothing twice, but it also does not
--       remove rows that IDQ would have truncated away.
--     * A non-numeric provider number is dropped silently by
--       Filt_Numeric_Prov (fn_snow_helper01_common = 1) -- no exception
--       row is written for it, as in the original.
--     * The stored source filter PROVIDER_NUM is not null duplicates the
--       custom query's WHERE clause; both are preserved.
--     * The MDM cross-reference filter ROWID_SYSTEM = 'C21' is trimmed
--       (the MDM column is blank-padded), and only hub_state_ind = 1
--       rows are considered, with the latest source key per TPI kept.
--
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Rel_2_Mem_To_PCP (

    P_PCP_REL_TP VARCHAR DEFAULT '100' -- $PCP_REL_TP

)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    c_mapping    VARCHAR DEFAULT 'm_Tgt_C_S_TRS_Pty_Rle_Rel_2_Mem_To_PCP';
    l_run_ts     TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()::TIMESTAMP_NTZ;
    l_rows       NUMBER DEFAULT 0;
    l_summary    VARCHAR DEFAULT '';
BEGIN
    -- ---- Step 5: CLEANUP_PREVIOUS_RUN -- drop work tables left by a previous run
    DROP TABLE IF EXISTS WRK_TRS_REL2_S1_SRC;
    DROP TABLE IF EXISTS WRK_TRS_REL2_S2_KEYED;
    DROP TABLE IF EXISTS WRK_TRS_REL2_S3_ROUTER;
    DROP TABLE IF EXISTS WRK_TRS_REL2_S4_CONSOL;
    DROP TABLE IF EXISTS WRK_TRS_REL2_S5_PREP;
    DROP TABLE IF EXISTS WRK_TRS_REL2_S6_TIMELINE;

    -- ---- Step 10: SRC_MANAGED_CARE
    l_rows := (CALL sp_snow_step_TRS_REL2_S10_SRC(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 10 SRC_MANAGED_CARE', :l_rows) || CHR(10);

    -- ---- Step 20: KEYED
    l_rows := (CALL sp_snow_step_TRS_REL2_S20_KEYED(:P_PCP_REL_TP, :l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 20 KEYED', :l_rows) || CHR(10);

    -- ---- Step 30: ROUTER_EXCEPTIONS
    l_rows := (CALL sp_snow_step_TRS_REL2_S30_ROUTER(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 30 ROUTER_EXCEPTIONS', :l_rows) || CHR(10);

    -- ---- Step 40: CONSOLIDATED
    l_rows := (CALL sp_snow_step_TRS_REL2_S40_CONSOL(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 40 CONSOLIDATED', :l_rows) || CHR(10);

    -- ---- Step 50: PREPARED
    l_rows := (CALL sp_snow_step_TRS_REL2_S50_PREP(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 50 PREPARED', :l_rows) || CHR(10);

    -- ---- Step 60: TIMELINE
    l_rows := (CALL sp_snow_step_TRS_REL2_S60_TIMELINE(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 60 TIMELINE', :l_rows) || CHR(10);

    -- ---- PUBLISH: ONE transaction, all branches, in order ----
    BEGIN TRANSACTION;
    l_rows := (CALL sp_snow_pub_TRS_REL2_EXC_STG_BAD_REC_MEMB_DATES(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 70 PUBLISH_EXC_DATES', :l_rows) || CHR(10);
    l_rows := (CALL sp_snow_pub_TRS_REL2_EXC_STG_BAD_REC_MEMB_DEFAULT(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 80 PUBLISH_EXC_DEFAULT', :l_rows) || CHR(10);
    l_rows := (CALL sp_snow_pub_TRS_REL2_C_S_TRS_PTY_RLE_REL_PROV(:P_PCP_REL_TP, :l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 90 PUBLISH_C_S_TRS_PTY_RLE_REL_PROV', :l_rows) || CHR(10);
    COMMIT;

    RETURN l_summary;
EXCEPTION
    WHEN OTHER THEN
        ROLLBACK;
        RAISE;
END;
$$;
