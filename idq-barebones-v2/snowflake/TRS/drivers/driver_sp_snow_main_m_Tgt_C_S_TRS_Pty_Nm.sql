-- ============================================================================
-- sp_snow_main_m_Tgt_C_S_TRS_Pty_Nm  --  BARE-BONES STEP DRIVER (TRS)
--
-- IDQ mapping: m_Tgt_C_S_TRS_Pty_Nm, workflow wf_TRS_Stage_Load_1_Ongoing.
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
--     Step  10  ALIAS_SRC                                     WRK_TRS_NM_S10_SRC
--     Step  20  NAMED_FILTERED                                WRK_TRS_NM_S20_NAMED
--     Step  30  STANDARDISED                                  WRK_TRS_NM_S30_STD
--     Step  40  DEDUP_KEYED                                   WRK_TRS_NM_S40_DEDUP
--     Step  50  PUBLISH_C_S_TRS_PTY_NM                        C_S_TRS_PTY_NM (publish)
--
-- PARITY NOTES (kept deliberately, do not "fix" silently; condensed
-- from the current main header -- see the manifest for the full text)
----   (kept deliberately, do not "fix" silently)
--     * Insert-only, as in the original Snowflake code: no TRUNCATE, no
--       DELETE of the target.  IDQ truncates C_S_TRS_PTY_NM; the
--       Snowflake version instead skips keys already present (the
--       existing-key guard in the publish step) and keeps the latest
--       CREATE_DT per key in this run, whereas IDQ keeps the first that
--       arrives and the database rejects the rest.  A re-run therefore
--       inserts nothing twice, but it also does not remove rows that IDQ
--       would have truncated away -- see the User Guide, "Parity gaps".
--     * Prefix / suffix standardisation values are NULL, as in the
--       original: the name mapplet's source-system input is not linked
--       in this mapping, so its prefix/suffix lookups (keyed on the
--       source system) never match.  Preserved, not repaired -- repairing
--       it would change which names load.
--
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_main_m_Tgt_C_S_TRS_Pty_Nm (

    P_MEMBER_NAME_TYPE_CODE VARCHAR DEFAULT '002'

)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    c_mapping    VARCHAR DEFAULT 'm_Tgt_C_S_TRS_Pty_Nm';
    l_run_ts     TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()::TIMESTAMP_NTZ;
    l_rows       NUMBER DEFAULT 0;
    l_summary    VARCHAR DEFAULT '';
BEGIN
    -- ---- Step 5: CLEANUP_PREVIOUS_RUN -- drop work tables left by a previous run
    DROP TABLE IF EXISTS WRK_TRS_NM_S10_SRC;
    DROP TABLE IF EXISTS WRK_TRS_NM_S20_NAMED;
    DROP TABLE IF EXISTS WRK_TRS_NM_S30_STD;
    DROP TABLE IF EXISTS WRK_TRS_NM_S40_DEDUP;

    -- ---- Step 10: ALIAS_SRC
    l_rows := (CALL sp_snow_step_TRS_NM_S10_SRC(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 10 ALIAS_SRC', :l_rows) || CHR(10);

    -- ---- Step 20: NAMED_FILTERED
    l_rows := (CALL sp_snow_step_TRS_NM_S20_NAMED(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 20 NAMED_FILTERED', :l_rows) || CHR(10);

    -- ---- Step 30: STANDARDISED
    l_rows := (CALL sp_snow_step_TRS_NM_S30_STD(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 30 STANDARDISED', :l_rows) || CHR(10);

    -- ---- Step 40: DEDUP_KEYED
    l_rows := (CALL sp_snow_step_TRS_NM_S40_DEDUP(:P_MEMBER_NAME_TYPE_CODE, :l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 40 DEDUP_KEYED', :l_rows) || CHR(10);

    -- ---- PUBLISH: ONE transaction, all branches, in order ----
    BEGIN TRANSACTION;
    l_rows := (CALL sp_snow_pub_TRS_NM_C_S_TRS_PTY_NM(:P_MEMBER_NAME_TYPE_CODE, :l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 50 PUBLISH_C_S_TRS_PTY_NM', :l_rows) || CHR(10);
    COMMIT;

    RETURN l_summary;
EXCEPTION
    WHEN OTHER THEN
        ROLLBACK;
        RAISE;
END;
$$;
