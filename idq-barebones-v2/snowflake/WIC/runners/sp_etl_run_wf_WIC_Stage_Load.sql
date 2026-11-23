-- ============================================================================
-- sp_etl_run_wf_WIC_Stage_Load  --  WORKFLOW RUNNER, BARE-BONES VARIANT (WIC)
--
-- Runs the Snowflake replacement for IDQ workflow wf_WIC_Stage_Load, in
-- the same order as the original run script, with the same dependencies:
--   * m_Tgt_C_S_WIC_Pty_Validation first (it maintains the deactivation
--     list that every later mapping filters on);
--   * m_Tgt_C_S_WIC_Pty second (it loads the parties and roles);
--   * m_Tgt_C_S_WIC_Pty_Addr third (addresses for the loaded parties);
--   * m_Tgt_C_S_WIC_Pty_Rle_Phn_And_EAddr fourth (phones and e-mails);
--   * m_Tgt_C_S_WIC_Pty_Rle_Alt_Id last (alternate ids).
--   The IDQ command task (touch <workflow>.ind) is left to the scheduler,
--   exactly as in the original run script.
--
-- HOW TO RUN IT
--   CALL sp_etl_run_wf_WIC_Stage_Load();
--   The runner RETURNs one combined summary string: each mapping's driver
--   summary under a per-mapping header line, in run order.
--
-- BARE-BONES VARIANT
--   Drivers are called with ZERO arguments; their original parameters take
--   their defaults. No config gating, no job tracking, no input checks.
--
-- RESTARTING (mapping level only -- there is no step-level restart)
--   A restart is simply a new run: call the runner again. Each mapping, at
--   its start (step 5), drops any work tables the previous run of that
--   mapping left in the database, then runs every step from scratch. Work
--   tables are never dropped at the end of a run, and no mapping is ever
--   skipped because it completed in an earlier run -- a new run re-runs
--   every mapping. Because the procedures are insert-only with unique-key
--   guards, a re-run inserts nothing twice; it does not undo what an
--   earlier run already published.
--
-- INSTALL LOCATION
--   Install schema is WIC_ETL_WRK in database MDM_ETL_WIC. All procedure
--   names in the code below are unqualified, exactly as in the original.
--
-- This runner is APP level in the boundary model: it owns the workflow
-- order, but it never writes to a target table itself and never drops a
-- work table.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_etl_run_wf_WIC_Stage_Load (
)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    l_summary VARCHAR DEFAULT '';
    l_part    VARCHAR DEFAULT '';
BEGIN
    -- m_Tgt_C_S_WIC_Pty_Validation
    l_part := (CALL sp_snow_main_m_Tgt_C_S_WIC_Pty_Validation());
    l_summary := l_summary || '===== m_Tgt_C_S_WIC_Pty_Validation =====' || CHR(10) || l_part || CHR(10);

    -- m_Tgt_C_S_WIC_Pty
    l_part := (CALL sp_snow_main_m_Tgt_C_S_WIC_Pty());
    l_summary := l_summary || '===== m_Tgt_C_S_WIC_Pty =====' || CHR(10) || l_part || CHR(10);

    -- m_Tgt_C_S_WIC_Pty_Addr
    l_part := (CALL sp_snow_main_m_Tgt_C_S_WIC_Pty_Addr());
    l_summary := l_summary || '===== m_Tgt_C_S_WIC_Pty_Addr =====' || CHR(10) || l_part || CHR(10);

    -- m_Tgt_C_S_WIC_Pty_Rle_Phn_And_EAddr
    l_part := (CALL sp_snow_main_m_Tgt_C_S_WIC_Pty_Rle_Phn_And_EAddr());
    l_summary := l_summary || '===== m_Tgt_C_S_WIC_Pty_Rle_Phn_And_EAddr =====' || CHR(10) || l_part || CHR(10);

    -- m_Tgt_C_S_WIC_Pty_Rle_Alt_Id
    l_part := (CALL sp_snow_main_m_Tgt_C_S_WIC_Pty_Rle_Alt_Id());
    l_summary := l_summary || '===== m_Tgt_C_S_WIC_Pty_Rle_Alt_Id =====' || CHR(10) || l_part || CHR(10);

    RETURN l_summary;
END;
$$;
