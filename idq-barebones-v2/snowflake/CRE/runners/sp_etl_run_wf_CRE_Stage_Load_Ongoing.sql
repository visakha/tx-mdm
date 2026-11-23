-- ============================================================================
-- sp_etl_run_wf_CRE_Stage_Load_Ongoing  --  WORKFLOW RUNNER, BARE-BONES (CRE)
--
-- Runs the Snowflake replacement for IDQ workflow wf_CRE_Stage_Load_Ongoing,
-- in the same order as the original run script. The workflow has a
-- single mapping, so the runner makes a single mapping CALL:
--   * m_Tgt_C_S_CRE_CARE_Clients (loads CARE clients into CRE_SRC_MRG,
--     C_S_CRE_PTY, C_S_CRE_PTY_RLE, C_S_CRE_PTY_RLE_ADDR,
--     C_S_CRE_PTY_RLE_PHN and C_S_CRE_PTY_RLE_ALT_ID, plus exceptions).
-- The IDQ command task (touch <workflow>.ind) is left to the scheduler,
-- exactly as in the original run script.
--
-- HOW TO RUN IT
--   CALL sp_etl_run_wf_CRE_Stage_Load_Ongoing();
--
-- The runner calls the driver with ZERO arguments (all driver parameters
-- carry defaults), captures the driver's summary string, prefixes it with
-- a workflow header line, and RETURNs it.
--
-- RESTARTING (mapping level only -- there is no step-level restart)
--   A restart is simply a new run: call the runner again. The mapping, at
--   its start (step 5), drops any work tables the previous run left in
--   the database, then runs every step from scratch. Work tables are never
--   dropped at the end of a run.
--   Because the procedure is insert-only with unique-key guards, a
--   re-run inserts nothing twice; it does not undo what an earlier run
--   already published.
--
-- This runner is APP level in the boundary model: it owns the workflow
-- order, but it never writes to a target table itself and never drops a
-- work table.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_etl_run_wf_CRE_Stage_Load_Ongoing ()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    l_summary    VARCHAR;
BEGIN
    -- 1. CARE clients (the workflow's only mapping).
    l_summary := (CALL sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients());
    RETURN 'wf_CRE_Stage_Load_Ongoing' || CHR(10) || l_summary;
END;
$$;
