-- ============================================================================
-- sp_snow_main_m_Tgt_C_S_TRS_Pty_Mng_Attr_Auth_Rep_Ongoing  --  BARE-BONES STEP DRIVER (TRS)
--
-- IDQ mapping: m_Tgt_C_S_TRS_Pty_Mng_Attr_Auth_Rep_Ongoing, workflow wf_TRS_Stage_Load_1_Ongoing.
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
--     Step  10  PAYEE_CASE_ROWS                               WRK_TRS_MNGAR_S10_PAYEE
--     Step  20  VALID_SRC                                     WRK_TRS_MNGAR_S20_SRC
--     Step  30  KEYED                                         WRK_TRS_MNGAR_S30_KEYED
--     Step  40  AGG_DEDUP                                     WRK_TRS_MNGAR_S40_AGG
--     Step  50  PUBLISH_C_S_TRS_PTY_MNG_ATTR                  C_S_TRS_PTY_MNG_ATTR (publish)
--
-- PARITY NOTES (kept deliberately, do not "fix" silently; condensed
-- from the current main header -- see the manifest for the full text)
----   (kept deliberately, do not "fix" silently)
--     * IDQ deletes ONLY its own attribute type from C_S_TRS_PTY_MNG_ATTR
--       before loading (pre-SQL: DELETE ... WHERE MNG_ATTR_TP =
--       '$ATTR_TP_AUTH_REP').  THE SNOWFLAKE ORIGINAL DOES NOT DO THIS:
--       it contains no DELETE at all, and this rewrite preserves that --
--       it only skips keys already present in the target (VERSION_SEQ = 1)
--       and keeps one row per key in this run.  Consequence, stated
--       plainly: a re-run inserts nothing twice, but a stale
--       Auth_Rep_Flag row that IDQ would have deleted and reloaded is
--       left in place by this version.  If IDQ parity is required, the
--       delete must be added as an explicit publish sub-step inside the
--       step-50 transaction (see the User Guide, "Parity gaps") -- it has
--       NOT been invented here.
--     * Insert-only otherwise, as in the original Snowflake code: no
--
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_main_m_Tgt_C_S_TRS_Pty_Mng_Attr_Auth_Rep_Ongoing (

    P_ATTR_TP_AUTH_REP VARCHAR DEFAULT 'Auth_Rep_Flag'

)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    c_mapping    VARCHAR DEFAULT 'm_Tgt_C_S_TRS_Pty_Mng_Attr_Auth_Rep_Ongoing';
    l_run_ts     TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()::TIMESTAMP_NTZ;
    l_rows       NUMBER DEFAULT 0;
    l_summary    VARCHAR DEFAULT '';
BEGIN
    -- ---- Step 5: CLEANUP_PREVIOUS_RUN -- drop work tables left by a previous run
    DROP TABLE IF EXISTS WRK_TRS_MNGAR_S10_PAYEE;
    DROP TABLE IF EXISTS WRK_TRS_MNGAR_S20_SRC;
    DROP TABLE IF EXISTS WRK_TRS_MNGAR_S30_KEYED;
    DROP TABLE IF EXISTS WRK_TRS_MNGAR_S40_AGG;

    -- ---- Step 10: PAYEE_CASE_ROWS
    l_rows := (CALL sp_snow_step_TRS_AUTHREP_S10_PAYEE(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 10 PAYEE_CASE_ROWS', :l_rows) || CHR(10);

    -- ---- Step 20: VALID_SRC
    l_rows := (CALL sp_snow_step_TRS_AUTHREP_S20_SRC(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 20 VALID_SRC', :l_rows) || CHR(10);

    -- ---- Step 30: KEYED
    l_rows := (CALL sp_snow_step_TRS_AUTHREP_S30_KEYED(:P_ATTR_TP_AUTH_REP, :l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 30 KEYED', :l_rows) || CHR(10);

    -- ---- Step 40: AGG_DEDUP
    l_rows := (CALL sp_snow_step_TRS_AUTHREP_S40_AGG(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 40 AGG_DEDUP', :l_rows) || CHR(10);

    -- ---- PUBLISH: ONE transaction, all branches, in order ----
    BEGIN TRANSACTION;
    l_rows := (CALL sp_snow_pub_TRS_AUTHREP_C_S_TRS_PTY_MNG_ATTR(:P_ATTR_TP_AUTH_REP, :l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 50 PUBLISH_C_S_TRS_PTY_MNG_ATTR', :l_rows) || CHR(10);
    COMMIT;

    RETURN l_summary;
EXCEPTION
    WHEN OTHER THEN
        ROLLBACK;
        RAISE;
END;
$$;
