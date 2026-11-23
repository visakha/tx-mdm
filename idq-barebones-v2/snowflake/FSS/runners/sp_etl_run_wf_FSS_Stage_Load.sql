-- ============================================================================
-- sp_etl_run_wf_FSS_Stage_Load  --  WORKFLOW RUNNER, BARE-BONES (FSS)
--
-- Bare-bones strip of the v2.1 runner: no P_JOB_RUN_ID, no job-control
-- calls, no config table. Runs the Snowflake replacement for IDQ workflow
-- wf_FSS_Stage_Load, in the same order as the original run script:
--   * m_Tgt_C_S_FSS_Pty_Validation first (it maintains
--     STG_FSS_PTY_INACTIVE_STS, the deactivation list every later
--     mapping reads);
--   * m_Tgt_C_S_FSS_Pty second (it loads the party and role tables
--     the later mappings' keys build on);
--   * addresses, alternate IDs, phones / e-mails and relationships
--     after that, in the original run-script order.
--   The IDQ command task (touch <workflow>.ind) is left to the
--   scheduler, exactly as in the original run script.
--
-- HOW TO RUN IT
--   CALL sp_etl_run_wf_FSS_Stage_Load();
--   Returns one combined summary string: one per-mapping section (a
--   header line plus that mapping driver's l_summary) per mapping, in
--   run order. Each mapping driver is called with ZERO arguments (all
--   remaining driver parameters carry defaults).
--
-- RESTARTING (mapping level only -- there is no step-level restart)
--   A restart is simply a new run: call the runner again. Each mapping,
--   at its start (step 5), drops any work tables the previous run of
--   that mapping left in the database, then runs every step from
--   scratch. Work tables are never dropped at the end of a run.
--   Because the procedures are insert-only with unique-key guards, a
--   re-run inserts nothing twice; it does not undo what an earlier run
--   already published.
--
-- This runner is APP level in the boundary model: it owns the workflow
-- order, but it never writes to a target table itself and never drops
-- a work table.
--
-- INSTALL
--   Install schema is FSS_ETL_WRK in database MDM_ETL_FSS.  All names
--   in the code below are unqualified, as in the original code.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_etl_run_wf_FSS_Stage_Load ()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    l_summary VARCHAR DEFAULT '';
    l_mapping VARCHAR;
BEGIN
    -- m_Tgt_C_S_FSS_Pty_Validation
    l_mapping := (CALL sp_snow_main_m_Tgt_C_S_FSS_Pty_Validation());
    l_summary := l_summary || '== m_Tgt_C_S_FSS_Pty_Validation ==' || CHR(10) || l_mapping || CHR(10);
    -- m_Tgt_C_S_FSS_Pty
    l_mapping := (CALL sp_snow_main_m_Tgt_C_S_FSS_Pty());
    l_summary := l_summary || '== m_Tgt_C_S_FSS_Pty ==' || CHR(10) || l_mapping || CHR(10);
    -- m_Tgt_C_S_FSS_Pty_Addr
    l_mapping := (CALL sp_snow_main_m_Tgt_C_S_FSS_Pty_Addr());
    l_summary := l_summary || '== m_Tgt_C_S_FSS_Pty_Addr ==' || CHR(10) || l_mapping || CHR(10);
    -- m_Tgt_C_S_FSS_Pty_Rle_Alt_Id
    l_mapping := (CALL sp_snow_main_m_Tgt_C_S_FSS_Pty_Rle_Alt_Id());
    l_summary := l_summary || '== m_Tgt_C_S_FSS_Pty_Rle_Alt_Id ==' || CHR(10) || l_mapping || CHR(10);
    -- m_Tgt_C_S_FSS_Pty_Rle_Phn_And_EAddr
    l_mapping := (CALL sp_snow_main_m_Tgt_C_S_FSS_Pty_Rle_Phn_And_EAddr());
    l_summary := l_summary || '== m_Tgt_C_S_FSS_Pty_Rle_Phn_And_EAddr ==' || CHR(10) || l_mapping || CHR(10);
    -- m_Tgt_C_S_FSS_Pty_Rle_Rel
    l_mapping := (CALL sp_snow_main_m_Tgt_C_S_FSS_Pty_Rle_Rel());
    l_summary := l_summary || '== m_Tgt_C_S_FSS_Pty_Rle_Rel ==' || CHR(10) || l_mapping || CHR(10);
    RETURN l_summary;
END;
$$;
