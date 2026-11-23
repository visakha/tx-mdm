-- ============================================================================
-- sp_etl_run_wf_TRS_Stage_Load_1_Ongoing  --  WORKFLOW RUNNER, BARE-BONES (TRS)
--
-- Runs the Snowflake replacement for IDQ workflow wf_TRS_Stage_Load_1_Ongoing,
-- in the same order as the original run script:
--   1. m_Tgt_C_S_TRS_Pty_OnGoing
--   2. m_Tgt_C_S_TRS_Pty_Deactivation_1
--   3. m_Tgt_C_S_TRS_Pty_Rle_TOA
--   4. m_Tgt_C_S_TRS_Pty_Rle_Rel_1_Mem_To_Mem
--   5. m_Tgt_C_S_TRS_Pty_Rle_Rel_DeActivation_1
--   6. m_Tgt_C_S_TRS_Pty_Rle_Rel_2_Mem_To_PCP
--   7. m_Tgt_C_S_TRS_Pty_Rle_Phn_And_EAddr
--   8. m_Tgt_C_S_TRS_Pty_Mng_Attr_Sw
--   9. m_Tgt_C_S_TRS_Pty_Mng_Attr_Auth_Rep_Ongoing
--   10. m_Tgt_C_S_TRS_Pty_Nm
--   11. m_Tgt_C_S_TRS_Pty_Rle_Alt_Id
--   12. m_Tgt_C_S_TRS_Pty_Rle_Pln
--   13. m_Tgt_C_S_TRS_Addr_1
--   14. m_Tgt_C_S_TRS_Addr_2
--
-- HOW TO RUN IT
--   CALL sp_etl_run_wf_TRS_Stage_Load_1_Ongoing();
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
CREATE OR REPLACE PROCEDURE sp_etl_run_wf_TRS_Stage_Load_1_Ongoing (
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
    -- 1. m_Tgt_C_S_TRS_Pty_OnGoing (builds the valid-member spine)
    l_part := (CALL sp_snow_main_m_Tgt_C_S_TRS_Pty_OnGoing());
    l_summary := l_summary || '== m_Tgt_C_S_TRS_Pty_OnGoing ==' || CHR(10) || l_part || CHR(10);

    -- 2. m_Tgt_C_S_TRS_Pty_Deactivation_1 (deactivation capture)
    l_part := (CALL sp_snow_main_m_Tgt_C_S_TRS_Pty_Deactivation_1());
    l_summary := l_summary || '== m_Tgt_C_S_TRS_Pty_Deactivation_1 ==' || CHR(10) || l_part || CHR(10);

    -- 3. m_Tgt_C_S_TRS_Pty_Rle_TOA (role level)
    l_part := (CALL sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_TOA());
    l_summary := l_summary || '== m_Tgt_C_S_TRS_Pty_Rle_TOA ==' || CHR(10) || l_part || CHR(10);

    -- 4. m_Tgt_C_S_TRS_Pty_Rle_Rel_1_Mem_To_Mem (member-to-member relationships)
    l_part := (CALL sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Rel_1_Mem_To_Mem());
    l_summary := l_summary || '== m_Tgt_C_S_TRS_Pty_Rle_Rel_1_Mem_To_Mem ==' || CHR(10) || l_part || CHR(10);

    -- 5. m_Tgt_C_S_TRS_Pty_Rle_Rel_DeActivation_1 (relationship deactivation capture)
    l_part := (CALL sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Rel_DeActivation_1());
    l_summary := l_summary || '== m_Tgt_C_S_TRS_Pty_Rle_Rel_DeActivation_1 ==' || CHR(10) || l_part || CHR(10);

    -- 6. m_Tgt_C_S_TRS_Pty_Rle_Rel_2_Mem_To_PCP (member-to-PCP relationships)
    l_part := (CALL sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Rel_2_Mem_To_PCP());
    l_summary := l_summary || '== m_Tgt_C_S_TRS_Pty_Rle_Rel_2_Mem_To_PCP ==' || CHR(10) || l_part || CHR(10);

    -- 7. m_Tgt_C_S_TRS_Pty_Rle_Phn_And_EAddr (phones and emails)
    l_part := (CALL sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Phn_And_EAddr());
    l_summary := l_summary || '== m_Tgt_C_S_TRS_Pty_Rle_Phn_And_EAddr ==' || CHR(10) || l_part || CHR(10);

    -- 8. m_Tgt_C_S_TRS_Pty_Mng_Attr_Sw (must precede Auth Rep)
    l_part := (CALL sp_snow_main_m_Tgt_C_S_TRS_Pty_Mng_Attr_Sw());
    l_summary := l_summary || '== m_Tgt_C_S_TRS_Pty_Mng_Attr_Sw ==' || CHR(10) || l_part || CHR(10);

    -- 9. m_Tgt_C_S_TRS_Pty_Mng_Attr_Auth_Rep_Ongoing (appends to the table the previous mapping loads)
    l_part := (CALL sp_snow_main_m_Tgt_C_S_TRS_Pty_Mng_Attr_Auth_Rep_Ongoing());
    l_summary := l_summary || '== m_Tgt_C_S_TRS_Pty_Mng_Attr_Auth_Rep_Ongoing ==' || CHR(10) || l_part || CHR(10);

    -- 10. m_Tgt_C_S_TRS_Pty_Nm (names)
    l_part := (CALL sp_snow_main_m_Tgt_C_S_TRS_Pty_Nm());
    l_summary := l_summary || '== m_Tgt_C_S_TRS_Pty_Nm ==' || CHR(10) || l_part || CHR(10);

    -- 11. m_Tgt_C_S_TRS_Pty_Rle_Alt_Id (alternate IDs)
    l_part := (CALL sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Alt_Id());
    l_summary := l_summary || '== m_Tgt_C_S_TRS_Pty_Rle_Alt_Id ==' || CHR(10) || l_part || CHR(10);

    -- 12. m_Tgt_C_S_TRS_Pty_Rle_Pln (plans)
    l_part := (CALL sp_snow_main_m_Tgt_C_S_TRS_Pty_Rle_Pln());
    l_summary := l_summary || '== m_Tgt_C_S_TRS_Pty_Rle_Pln ==' || CHR(10) || l_part || CHR(10);

    -- 13. m_Tgt_C_S_TRS_Addr_1 (must precede part 2)
    l_part := (CALL sp_snow_main_m_Tgt_C_S_TRS_Addr_1());
    l_summary := l_summary || '== m_Tgt_C_S_TRS_Addr_1 ==' || CHR(10) || l_part || CHR(10);

    -- 14. m_Tgt_C_S_TRS_Addr_2 (reads the unique addresses of part 1)
    l_part := (CALL sp_snow_main_m_Tgt_C_S_TRS_Addr_2());
    l_summary := l_summary || '== m_Tgt_C_S_TRS_Addr_2 ==' || CHR(10) || l_part || CHR(10);

    RETURN l_summary;
EXCEPTION
    WHEN OTHER THEN
        RAISE;
END;
$$;
