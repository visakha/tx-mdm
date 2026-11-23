-- ============================================================================
-- sp_snow_main_m_Tgt_C_S_TRS_Pty_Mng_Attr_Sw  --  BARE-BONES STEP DRIVER (TRS)
--
-- IDQ mapping: m_Tgt_C_S_TRS_Pty_Mng_Attr_Sw, workflow wf_TRS_Stage_Load_1_Ongoing.
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
--     Step  10  DAILY_INDV                                    WRK_TRS_MNGSW_S10_DAILY
--     Step  20  VALID_SRC                                     WRK_TRS_MNGSW_S20_SRC
--     Step  30  UNPIVOT_SWITCHES                              WRK_TRS_MNGSW_S30_NORM
--     Step  40  FILTERED_ATTRS                                WRK_TRS_MNGSW_S40_ATTRS
--     Step  50  PUBLISH_C_S_TRS_PTY_MNG_ATTR                  C_S_TRS_PTY_MNG_ATTR (publish)
--
-- PARITY NOTES (kept deliberately, do not "fix" silently; condensed
-- from the current main header -- see the manifest for the full text)
----   (kept deliberately, do not "fix" silently)
--     * Insert-only, as in the original Snowflake code: no TRUNCATE, no
--       DELETE of the target.  IDQ truncates C_S_TRS_PTY_MNG_ATTR; the
--       Snowflake version instead skips keys already present (the
--       existing-key guard in the publish step) and keeps the last row
--       per key in this run.  A re-run therefore inserts nothing twice,
--       but it also does not remove rows that IDQ would have truncated
--       away -- see the User Guide, "Parity gaps".
--     * VERSION_SEQ is hard-coded to 1 (the running version counter is
--       commented out in IDQ); PERIOD_START_DATE = EFF_BEGIN_DT;
--       PERIOD_END_DATE, PERIOD_REFERENCE_TIME and TIMELINE_ACTION are
--       NULL (unfed ports).
--     * ROWID_OBJECT, DELETED_*, UPDATED_BY, CREATOR and HUB_STATE_IND
--       are NULL (unfed ports), as in the original.
--
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_main_m_Tgt_C_S_TRS_Pty_Mng_Attr_Sw (
)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    c_mapping    VARCHAR DEFAULT 'm_Tgt_C_S_TRS_Pty_Mng_Attr_Sw';
    l_run_ts     TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()::TIMESTAMP_NTZ;
    l_rows       NUMBER DEFAULT 0;
    l_summary    VARCHAR DEFAULT '';
BEGIN
    -- ---- Step 5: CLEANUP_PREVIOUS_RUN -- drop work tables left by a previous run
    DROP TABLE IF EXISTS WRK_TRS_MNGSW_S10_DAILY;
    DROP TABLE IF EXISTS WRK_TRS_MNGSW_S20_SRC;
    DROP TABLE IF EXISTS WRK_TRS_MNGSW_S30_NORM;
    DROP TABLE IF EXISTS WRK_TRS_MNGSW_S40_ATTRS;

    -- ---- Step 10: DAILY_INDV
    l_rows := (CALL sp_snow_step_TRS_MNGSW_S10_DAILY(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 10 DAILY_INDV', :l_rows) || CHR(10);

    -- ---- Step 20: VALID_SRC
    l_rows := (CALL sp_snow_step_TRS_MNGSW_S20_SRC(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 20 VALID_SRC', :l_rows) || CHR(10);

    -- ---- Step 30: UNPIVOT_SWITCHES
    l_rows := (CALL sp_snow_step_TRS_MNGSW_S30_NORM(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 30 UNPIVOT_SWITCHES', :l_rows) || CHR(10);

    -- ---- Step 40: FILTERED_ATTRS
    l_rows := (CALL sp_snow_step_TRS_MNGSW_S40_ATTRS(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 40 FILTERED_ATTRS', :l_rows) || CHR(10);

    -- ---- PUBLISH: ONE transaction, all branches, in order ----
    BEGIN TRANSACTION;
    l_rows := (CALL sp_snow_pub_TRS_MNGSW_C_S_TRS_PTY_MNG_ATTR(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 50 PUBLISH_C_S_TRS_PTY_MNG_ATTR', :l_rows) || CHR(10);
    COMMIT;

    RETURN l_summary;
EXCEPTION
    WHEN OTHER THEN
        ROLLBACK;
        RAISE;
END;
$$;
