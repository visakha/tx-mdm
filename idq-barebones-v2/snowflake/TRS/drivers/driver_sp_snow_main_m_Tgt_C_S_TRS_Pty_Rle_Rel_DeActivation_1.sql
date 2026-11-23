-- ============================================================================
-- sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Rel_DeActivation_1  --  BARE-BONES STEP DRIVER (TRS)
--
-- IDQ mapping: m_Tgt_C_S_TRS_Pty_Rle_Rel_DeActivation_1, workflow wf_TRS_Stage_Load_1_Ongoing.
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
--     Step  10  MIN_PK                                        WRK_TRS_RELDEACT_S10_MINPK
--     Step  20  REL_SRC                                       WRK_TRS_RELDEACT_S20_SRC
--     Step  30  KEYED_REL                                     WRK_TRS_RELDEACT_S30_KEYED
--     Step  40  XREF_ONE                                      WRK_TRS_RELDEACT_S40_XREF
--     Step  50  READY_TO_PUBLISH                              WRK_TRS_RELDEACT_S50_READY
--     Step  60  PUBLISH_STG_TRS_DEACTIVATED_RELATIONSHIPS     STG_TRS_DEACTIVATED_RELATIONSHIPS (publish)
--
-- PARITY NOTES (kept deliberately, do not "fix" silently; condensed
-- from the current main header -- see the manifest for the full text)
----   (kept deliberately, do not "fix" silently)
--     * Insert-only, as in the original Snowflake code: no TRUNCATE, no
--       DELETE of targets.  The IDQ mapping has no delete target here
--       either -- the original Snowflake comment notes the mapping
--       description also mentions removing relationships from a valid
--       list, but the IDQ mapping has no such target, so nothing is
--       removed in either version.
--     * PROCESSED_YN is NOT in the INSERT column list, exactly as in the
--       original: it is left to the column default of
--       STG_TRS_DEACTIVATED_RELATIONSHIPS.  IDQ writes new rows as
--       PROCESSED_YN = 'N' (BR-50) and already-soft-deleted rows as 'Y'.
--       If the Snowflake column default is 'N', behaviour matches IDQ for
--       new rows; if it is NULL, the later CopyList still picks the rows
--       up (it treats NULL as unprocessed, nvl(PROCESSED_YN,'N') <> 'Y'),
--
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Rel_DeActivation_1 (
)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    c_mapping    VARCHAR DEFAULT 'm_Tgt_C_S_TRS_Pty_Rle_Rel_DeActivation_1';
    l_run_ts     TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()::TIMESTAMP_NTZ;
    l_rows       NUMBER DEFAULT 0;
    l_summary    VARCHAR DEFAULT '';
BEGIN
    -- ---- Step 5: CLEANUP_PREVIOUS_RUN -- drop work tables left by a previous run
    DROP TABLE IF EXISTS WRK_TRS_RELDEACT_S10_MINPK;
    DROP TABLE IF EXISTS WRK_TRS_RELDEACT_S20_SRC;
    DROP TABLE IF EXISTS WRK_TRS_RELDEACT_S30_KEYED;
    DROP TABLE IF EXISTS WRK_TRS_RELDEACT_S40_XREF;
    DROP TABLE IF EXISTS WRK_TRS_RELDEACT_S50_READY;

    -- ---- Step 10: MIN_PK
    l_rows := (CALL sp_snow_step_TRS_RELDEACT_S10_MINPK(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 10 MIN_PK', :l_rows) || CHR(10);

    -- ---- Step 20: REL_SRC
    l_rows := (CALL sp_snow_step_TRS_RELDEACT_S20_SRC(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 20 REL_SRC', :l_rows) || CHR(10);

    -- ---- Step 30: KEYED_REL
    l_rows := (CALL sp_snow_step_TRS_RELDEACT_S30_KEYED(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 30 KEYED_REL', :l_rows) || CHR(10);

    -- ---- Step 40: XREF_ONE
    l_rows := (CALL sp_snow_step_TRS_RELDEACT_S40_XREF(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 40 XREF_ONE', :l_rows) || CHR(10);

    -- ---- Step 50: READY_TO_PUBLISH
    l_rows := (CALL sp_snow_step_TRS_RELDEACT_S50_READY(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 50 READY_TO_PUBLISH', :l_rows) || CHR(10);

    -- ---- PUBLISH: ONE transaction, all branches, in order ----
    BEGIN TRANSACTION;
    l_rows := (CALL sp_snow_pub_TRS_RELDEACT_STG_TRS_DEACTIVATED_RELATIONSHIPS());
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 60 PUBLISH_STG_TRS_DEACTIVATED_RELATIONSHIPS', :l_rows) || CHR(10);
    COMMIT;

    RETURN l_summary;
EXCEPTION
    WHEN OTHER THEN
        ROLLBACK;
        RAISE;
END;
$$;
