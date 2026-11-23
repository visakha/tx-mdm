-- ============================================================================
-- sp_etl_run_wf_TTF_Stage_Load  --  WORKFLOW RUNNER, BARE-BONES variant (TTF)
--
-- Runs the Snowflake replacement for IDQ workflow wf_TTF_Stage_Load, in the
-- same order as the v2.1 runner:
--   1. m_Tgt_C_S_TTF_Pty_Validation (maintains STG_TTF_PTY_INACTIVE_STS /
--      STG_TTF_PTY_INACTIVE_LOG, which later mappings read);
--   2. m_Tgt_C_S_TTF_Pty (party and role tables);
--   3. m_Tgt_C_S_TTF_Pty_Rle_Alt_Id;
--   4. m_Tgt_C_S_TTF_Pty_Rle_Phn.
-- No config table, no checkpointing, no job-run id. Each driver is called
-- with zero arguments (drivers carry their own defaults) and its returned
-- summary string is concatenated, under a per-mapping header line, into
-- one big summary string, which the runner returns. A restart is simply
-- a new run: each mapping drops its previous work tables at its start
-- (step 5) and runs every step from scratch; work tables are left
-- standing at the end. The IDQ command task (touch <workflow>.ind) is
-- left to the scheduler, exactly as in the original run script.
--
-- HOW TO RUN IT
--   CALL sp_etl_run_wf_TTF_Stage_Load();
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_etl_run_wf_TTF_Stage_Load (
)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    l_mapping  VARCHAR DEFAULT '';
    l_summary  VARCHAR DEFAULT '';
BEGIN
    -- m_Tgt_C_S_TTF_Pty_Validation
    l_mapping := (CALL sp_snow_main_m_Tgt_C_S_TTF_Pty_Validation());
    l_summary := l_summary || '=== m_Tgt_C_S_TTF_Pty_Validation ===' || CHR(10) || :l_mapping || CHR(10);

    -- m_Tgt_C_S_TTF_Pty
    l_mapping := (CALL sp_snow_main_m_Tgt_C_S_TTF_Pty());
    l_summary := l_summary || '=== m_Tgt_C_S_TTF_Pty ===' || CHR(10) || :l_mapping || CHR(10);

    -- m_Tgt_C_S_TTF_Pty_Rle_Alt_Id
    l_mapping := (CALL sp_snow_main_m_Tgt_C_S_TTF_Pty_Rle_Alt_Id());
    l_summary := l_summary || '=== m_Tgt_C_S_TTF_Pty_Rle_Alt_Id ===' || CHR(10) || :l_mapping || CHR(10);

    -- m_Tgt_C_S_TTF_Pty_Rle_Phn
    l_mapping := (CALL sp_snow_main_m_Tgt_C_S_TTF_Pty_Rle_Phn());
    l_summary := l_summary || '=== m_Tgt_C_S_TTF_Pty_Rle_Phn ===' || CHR(10) || :l_mapping || CHR(10);

    RETURN l_summary;
EXCEPTION
    WHEN OTHER THEN
        RAISE;
END;
$$;
