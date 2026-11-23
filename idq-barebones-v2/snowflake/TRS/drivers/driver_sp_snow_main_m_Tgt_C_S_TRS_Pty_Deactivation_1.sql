-- ============================================================================
-- sp_snow_main_m_Tgt_C_S_TRS_Pty_Deactivation_1  --  BARE-BONES STEP DRIVER (TRS)
--
-- IDQ mapping: m_Tgt_C_S_TRS_Pty_Deactivation_1, workflow wf_TRS_Stage_Load_1_Ongoing.
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
--     Step  10  DEACTIVATED_INDIVIDUALS                       WRK_TRS_DEACT1_S10_DEACTV
--     Step  20  DEACTIVATED_PER_INDIVIDUAL                    WRK_TRS_DEACT1_S20_DEACTV_ID
--     Step  30  READY_TO_PUBLISH                              WRK_TRS_DEACT1_S30_READY
--     Step  40  PUBLISH_STG_TRS_DEACTIVED_MEMBERS             STG_TRS_DEACTIVED_MEMBERS (publish)
--     Step  50  DELETE_VALID_STAGE_NOT_PERFORMED              (no data written)
--
-- PARITY NOTES (kept deliberately, do not "fix" silently; condensed
-- from the current main header -- see the manifest for the full text)
----   (kept deliberately, do not "fix" silently)
--     * Insert-only, as in the original Snowflake code: no TRUNCATE, no
--       DELETE of targets.  In particular, the IDQ DD_DELETE of
--       STG_TRS_VALID_MEMBERS is NOT performed here (step 50).  That means
--       deactivated members STAY in the valid-member list in the Snowflake
--       version, whereas IDQ removes them -- so downstream Snowflake
--       mappings that join STG_TRS_VALID_MEMBERS will still see
--       deactivated members until some other process removes them.  This
--       is the single largest parity gap in this mapping, and it is a
--       business decision, not a bug to fix in passing: the original
--       Snowflake comment cites it as a deliberate insert-only rule.
--     * STG_TRS_DEACTIVED_MEMBERS has primary key INDV_ID, which Snowflake
--       does not enforce.  An individual can be a valid member under two
--       party keys (INDV_ID|DC_INDV and INDV_ID for MCI); IDQ writes the
--
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_main_m_Tgt_C_S_TRS_Pty_Deactivation_1 (
)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    c_mapping    VARCHAR DEFAULT 'm_Tgt_C_S_TRS_Pty_Deactivation_1';
    l_run_ts     TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()::TIMESTAMP_NTZ;
    l_rows       NUMBER DEFAULT 0;
    l_summary    VARCHAR DEFAULT '';
BEGIN
    -- ---- Step 5: CLEANUP_PREVIOUS_RUN -- drop work tables left by a previous run
    DROP TABLE IF EXISTS WRK_TRS_DEACT1_S10_DEACTV;
    DROP TABLE IF EXISTS WRK_TRS_DEACT1_S20_DEACTV_ID;
    DROP TABLE IF EXISTS WRK_TRS_DEACT1_S30_READY;

    -- ---- Step 10: DEACTIVATED_INDIVIDUALS
    l_rows := (CALL sp_snow_step_TRS_PTYDEACT_S10_DEACTV(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 10 DEACTIVATED_INDIVIDUALS', :l_rows) || CHR(10);

    -- ---- Step 20: DEACTIVATED_PER_INDIVIDUAL
    l_rows := (CALL sp_snow_step_TRS_PTYDEACT_S20_DEACTV_ID(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 20 DEACTIVATED_PER_INDIVIDUAL', :l_rows) || CHR(10);

    -- ---- Step 30: READY_TO_PUBLISH
    l_rows := (CALL sp_snow_step_TRS_PTYDEACT_S30_READY(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 30 READY_TO_PUBLISH', :l_rows) || CHR(10);

    -- ---- PUBLISH: ONE transaction, all branches, in order ----
    BEGIN TRANSACTION;
    l_rows := (CALL sp_snow_pub_TRS_PTYDEACT_STG_TRS_DEACTIVED_MEMBERS());
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 40 PUBLISH_STG_TRS_DEACTIVED_MEMBERS', :l_rows) || CHR(10);
    COMMIT;

    -- ---- Step 50: DELETE_VALID_STAGE_NOT_PERFORMED (no data written, AFTER publish -- original order)
    l_rows := (CALL sp_snow_step_TRS_PTYDEACT_S50_NOTPERFORMED(:l_run_ts));
    l_summary := l_summary || 'step 50 DELETE_VALID_STAGE_NOT_PERFORMED: recorded, no data written (deliberate, see manifest)' || CHR(10);

    RETURN l_summary;
EXCEPTION
    WHEN OTHER THEN
        ROLLBACK;
        RAISE;
END;
$$;
