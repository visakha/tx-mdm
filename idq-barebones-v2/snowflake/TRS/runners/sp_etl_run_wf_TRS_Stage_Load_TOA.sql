-- ============================================================================
-- sp_etl_run_wf_TRS_Stage_Load_TOA  --  WORKFLOW RUNNER, BARE-BONES (TRS)
--
-- Runs the Snowflake replacement for IDQ workflow wf_TRS_Stage_Load_TOA,
-- in the same order as the original run script:
--   1. m_Tgt_C_S_TRS_Stg_TOA
--
-- HOW TO RUN IT
--   CALL sp_etl_run_wf_TRS_Stage_Load_TOA();
--
-- Each driver is called with ZERO arguments (all driver parameters
-- carry defaults, and the runner passes none, so every mapping runs
-- with its defaults). Each driver RETURNs its summary string; the
-- runner concatenates them, one per-mapping header line plus
-- newlines, into one big summary string and RETURNs it.
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
-- This runner is app level: it owns the workflow order, but it never
-- writes to a target table itself and never drops a work table.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_etl_run_wf_TRS_Stage_Load_TOA (
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
    -- 1. m_Tgt_C_S_TRS_Stg_TOA (TOA reference catalogue)
    l_part := (CALL sp_snow_main_m_Tgt_C_S_TRS_Stg_TOA());
    l_summary := l_summary || '== m_Tgt_C_S_TRS_Stg_TOA ==' || CHR(10) || l_part || CHR(10);

    RETURN l_summary;
EXCEPTION
    WHEN OTHER THEN
        RAISE;
END;
$$;
