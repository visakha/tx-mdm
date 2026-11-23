-- ============================================================================
-- sp_snow_main_m_Tgt_C_S_TRS_Addr_1  --  BARE-BONES STEP DRIVER (TRS)
--
-- IDQ mapping: m_Tgt_C_S_TRS_Addr_1, workflow wf_TRS_Stage_Load_1_Ongoing.
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
--     Step  10  SRC_DISTINCT_ADDR                             WRK_TRS_ADDR1_S10_SRC
--     Step  20  DERIVED_ADDR_LINES                            WRK_TRS_ADDR1_S20_DERIVED
--     Step  30  ADDR_VALIDATION                               WRK_TRS_ADDR1_S30_VALIDATED
--     Step  40  READY_TO_PUBLISH                              WRK_TRS_ADDR1_S40_READY
--     Step  50  PUBLISH_STG_TRS_D_UNQ_ADDR                    STG_TRS_D_UNQ_ADDR (publish)
--
-- PARITY NOTES (kept deliberately, do not "fix" silently; condensed
-- from the current main header -- see the manifest for the full text)
----   (kept deliberately, do not "fix" silently)
--     * Insert-only, as in the original Snowflake code: no TRUNCATE, no
--       DELETE of targets.  IDQ truncates STG_TRS_D_UNQ_ADDR first; the
--       Snowflake version instead skips addresses already present (the
--       xu guard in step 40), so an address validated in an earlier run
--       is not written again and is re-used by Addr_2.  A re-run therefore
--       inserts nothing twice, but it also does not remove rows that IDQ
--       would have truncated away -- see the User Guide, "Parity gaps".
--     * The address validator is a pass-through stand-in for AddressDoctor
--       (fn_snow_helper34_common, with its state-code and match-code
--       lookups).  It does not certify addresses the way AddressDoctor
--       does; the score is computed later, in Addr_2.
--     * SRC_COUNTY is NULL (unfed port), as in the original.  The scrub
--       rules clean the result lines; the derived source lines are kept
--
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_main_m_Tgt_C_S_TRS_Addr_1 (
)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    c_mapping    VARCHAR DEFAULT 'm_Tgt_C_S_TRS_Addr_1';
    l_run_ts     TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()::TIMESTAMP_NTZ;
    l_rows       NUMBER DEFAULT 0;
    l_summary    VARCHAR DEFAULT '';
BEGIN
    -- ---- Step 5: CLEANUP_PREVIOUS_RUN -- drop work tables left by a previous run
    DROP TABLE IF EXISTS WRK_TRS_ADDR1_S10_SRC;
    DROP TABLE IF EXISTS WRK_TRS_ADDR1_S20_DERIVED;
    DROP TABLE IF EXISTS WRK_TRS_ADDR1_S30_VALIDATED;
    DROP TABLE IF EXISTS WRK_TRS_ADDR1_S40_READY;

    -- ---- Step 10: SRC_DISTINCT_ADDR
    l_rows := (CALL sp_snow_step_TRS_ADDR1_S10_SRC(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 10 SRC_DISTINCT_ADDR', :l_rows) || CHR(10);

    -- ---- Step 20: DERIVED_ADDR_LINES
    l_rows := (CALL sp_snow_step_TRS_ADDR1_S20_DERIVED(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 20 DERIVED_ADDR_LINES', :l_rows) || CHR(10);

    -- ---- Step 30: ADDR_VALIDATION
    l_rows := (CALL sp_snow_step_TRS_ADDR1_S30_VALIDATED(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 30 ADDR_VALIDATION', :l_rows) || CHR(10);

    -- ---- Step 40: READY_TO_PUBLISH
    l_rows := (CALL sp_snow_step_TRS_ADDR1_S40_READY(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 40 READY_TO_PUBLISH', :l_rows) || CHR(10);

    -- ---- PUBLISH: ONE transaction, all branches, in order ----
    BEGIN TRANSACTION;
    l_rows := (CALL sp_snow_pub_TRS_ADDR1_STG_TRS_D_UNQ_ADDR());
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 50 PUBLISH_STG_TRS_D_UNQ_ADDR', :l_rows) || CHR(10);
    COMMIT;

    RETURN l_summary;
EXCEPTION
    WHEN OTHER THEN
        ROLLBACK;
        RAISE;
END;
$$;
