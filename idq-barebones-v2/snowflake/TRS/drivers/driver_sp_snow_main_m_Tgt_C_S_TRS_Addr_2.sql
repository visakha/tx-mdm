-- ============================================================================
-- sp_snow_main_m_Tgt_C_S_TRS_Addr_2  --  BARE-BONES STEP DRIVER (TRS)
--
-- IDQ mapping: m_Tgt_C_S_TRS_Addr_2, workflow wf_TRS_Stage_Load_1_Ongoing.
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
--     Step  10  ADDR_DEDUP                                    WRK_TRS_ADDR2_S10_DEDUP
--     Step  20  SRC_VALIDATED_JOIN                            WRK_TRS_ADDR2_S20_SRC
--     Step  30  KEYED_ADDR                                    WRK_TRS_ADDR2_S30_KEYED
--     Step  40  SCORED_VERSIONED                              WRK_TRS_ADDR2_S40_SCORED
--     Step  50  READY_TO_PUBLISH                              WRK_TRS_ADDR2_S50_READY
--     Step  60  PUBLISH_DQM_ADDRESS                           DQM_ADDRESS (publish)
--     Step  70  PUBLISH_C_S_TRS_PTY_RLE_ADDR                  C_S_TRS_PTY_RLE_ADDR (publish)
--     Step  80  PUBLISH_EXC_STG_BAD_REC_MEMB                  EXC_STG_BAD_REC_MEMB (publish)
--
-- PARITY NOTES (kept deliberately, do not "fix" silently; condensed
-- from the current main header -- see the manifest for the full text)
----   (kept deliberately, do not "fix" silently)
--     * Insert-only, as in the original Snowflake code: no TRUNCATE, no
--       DELETE of targets.  IDQ truncates C_S_TRS_PTY_RLE_ADDR first; the
--       Snowflake version instead skips keys already present (the uq_addr
--       guard in step 50, on PKEY_SRC_OBJECT + VERSION_SEQ, and the
--       uq_addr_exc guard for exceptions).  A re-run therefore inserts
--       nothing twice, but it also does not remove rows that IDQ would
--       have truncated away -- see the User Guide, "Parity gaps".
--     * Score rules, exactly as in the original: only '100' loads and only
--       '40' is exceptioned.  The IDQ Default router branch is not linked
--       ("the score is always '40' or '100"), so a row with any other
--       score is written to DQM_ADDRESS (the WHEN TRUE audit branch) and
--       to neither staging nor exceptions.  That behaviour is preserved
--       here; if a new score ever appears, it will be visible in
--
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_main_m_Tgt_C_S_TRS_Addr_2 (

    P_MEMBER_ROLE_TYPE      VARCHAR DEFAULT 'Member',
    P_MEMBER_HIERARCHY_CODE VARCHAR DEFAULT 'Member',
    P_MEMBER_HM_REL_TP_CD   VARCHAR DEFAULT 'Member Addr'

)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    c_mapping    VARCHAR DEFAULT 'm_Tgt_C_S_TRS_Addr_2';
    l_run_ts     TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()::TIMESTAMP_NTZ;
    l_rows       NUMBER DEFAULT 0;
    l_summary    VARCHAR DEFAULT '';
BEGIN
    -- ---- Step 5: CLEANUP_PREVIOUS_RUN -- drop work tables left by a previous run
    DROP TABLE IF EXISTS WRK_TRS_ADDR2_S10_DEDUP;
    DROP TABLE IF EXISTS WRK_TRS_ADDR2_S20_SRC;
    DROP TABLE IF EXISTS WRK_TRS_ADDR2_S30_KEYED;
    DROP TABLE IF EXISTS WRK_TRS_ADDR2_S40_SCORED;
    DROP TABLE IF EXISTS WRK_TRS_ADDR2_S50_READY;

    -- ---- Step 10: ADDR_DEDUP
    l_rows := (CALL sp_snow_step_TRS_ADDR2_S10_DEDUP(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 10 ADDR_DEDUP', :l_rows) || CHR(10);

    -- ---- Step 20: SRC_VALIDATED_JOIN
    l_rows := (CALL sp_snow_step_TRS_ADDR2_S20_SRC(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 20 SRC_VALIDATED_JOIN', :l_rows) || CHR(10);

    -- ---- Step 30: KEYED_ADDR
    l_rows := (CALL sp_snow_step_TRS_ADDR2_S30_KEYED(:P_MEMBER_ROLE_TYPE, :l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 30 KEYED_ADDR', :l_rows) || CHR(10);

    -- ---- Step 40: SCORED_VERSIONED
    l_rows := (CALL sp_snow_step_TRS_ADDR2_S40_SCORED(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 40 SCORED_VERSIONED', :l_rows) || CHR(10);

    -- ---- Step 50: READY_TO_PUBLISH
    l_rows := (CALL sp_snow_step_TRS_ADDR2_S50_READY(:P_MEMBER_ROLE_TYPE, :P_MEMBER_HIERARCHY_CODE, :P_MEMBER_HM_REL_TP_CD, :l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 50 READY_TO_PUBLISH', :l_rows) || CHR(10);

    -- ---- PUBLISH: ONE transaction, all branches, in order ----
    BEGIN TRANSACTION;
    l_rows := (CALL sp_snow_pub_TRS_ADDR2_DQM_ADDRESS());
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 60 PUBLISH_DQM_ADDRESS', :l_rows) || CHR(10);
    l_rows := (CALL sp_snow_pub_TRS_ADDR2_C_S_TRS_PTY_RLE_ADDR());
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 70 PUBLISH_C_S_TRS_PTY_RLE_ADDR', :l_rows) || CHR(10);
    l_rows := (CALL sp_snow_pub_TRS_ADDR2_EXC_STG_BAD_REC_MEMB());
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 80 PUBLISH_EXC_STG_BAD_REC_MEMB', :l_rows) || CHR(10);
    COMMIT;

    RETURN l_summary;
EXCEPTION
    WHEN OTHER THEN
        ROLLBACK;
        RAISE;
END;
$$;
