-- ============================================================================
-- sp_snow_main_m_Tgt_C_S_TRS_Stg_TOA  --  BARE-BONES STEP DRIVER (TRS)
--
-- IDQ mapping: m_Tgt_C_S_TRS_Stg_TOA, workflow wf_TRS_Stage_Load_TOA.
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
--     Step  10  CATALOGUE_KEYED                               WRK_TRS_LUTOA_S10_KEYED
--     Step  20  SURVIVOR_PER_KEY                              WRK_TRS_LUTOA_S20_FINAL
--     Step  30  PUBLISH_C_S_LU_TOA                            C_S_LU_TOA (publish)
--
-- PARITY NOTES (kept deliberately, do not "fix" silently; condensed
-- from the current main header -- see the manifest for the full text)
----   (kept deliberately, do not "fix" silently)
--     * Insert-only, as in the original Snowflake code: no TRUNCATE, no
--       DELETE of the target.  IDQ truncates C_S_LU_TOA; the Snowflake
--       version instead skips keys already present (VERSION_SEQ = 1) and
--       skips null keys.  A re-run therefore inserts nothing twice, but
--       it also does not remove rows that IDQ would have truncated away
--       -- see the User Guide, "Parity gaps".
--     * No validation in IDQ for this mapping: no router, no filter, no
--       exception table, and no begin-after-end date check (unlike the
--       member TOA mapping, BR-27).  The only checks in the original are
--       the target's NOT NULL / unique constraints, ported here as the
--       step-20 null-key filter and existing-key guard.  A TOA code with
--       no TOA master label leaves PKEY_SRC_OBJECT NULL; IDQ gets the row
--       rejected by Oracle and logs nothing, and this version drops it
--
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_main_m_Tgt_C_S_TRS_Stg_TOA (
)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    c_mapping    VARCHAR DEFAULT 'm_Tgt_C_S_TRS_Stg_TOA';
    l_run_ts     TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()::TIMESTAMP_NTZ;
    l_rows       NUMBER DEFAULT 0;
    l_summary    VARCHAR DEFAULT '';
BEGIN
    -- ---- Step 5: CLEANUP_PREVIOUS_RUN -- drop work tables left by a previous run
    DROP TABLE IF EXISTS WRK_TRS_LUTOA_S10_KEYED;
    DROP TABLE IF EXISTS WRK_TRS_LUTOA_S20_FINAL;

    -- ---- Step 10: CATALOGUE_KEYED
    l_rows := (CALL sp_snow_step_TRS_STGTOA_S10_KEYED(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 10 CATALOGUE_KEYED', :l_rows) || CHR(10);

    -- ---- Step 20: SURVIVOR_PER_KEY
    l_rows := (CALL sp_snow_step_TRS_STGTOA_S20_FINAL(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 20 SURVIVOR_PER_KEY', :l_rows) || CHR(10);

    -- ---- PUBLISH: ONE transaction, all branches, in order ----
    BEGIN TRANSACTION;
    l_rows := (CALL sp_snow_pub_TRS_STGTOA_C_S_LU_TOA(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 30 PUBLISH_C_S_LU_TOA', :l_rows) || CHR(10);
    COMMIT;

    RETURN l_summary;
EXCEPTION
    WHEN OTHER THEN
        ROLLBACK;
        RAISE;
END;
$$;
