-- sp_etl_run_wf_ECI_Stage_Load -- BARE-BONES variant (ECI)
-- Workflow: wf_ECI_Stage_Load. Runs the 9 mapping drivers in the original
-- run-script order, each with zero arguments (driver defaults apply, which
-- match the explicit values the v2.1 runner passed). Each driver RETURNs a
-- summary string; the runner concatenates them under per-mapping headers
-- and RETURNs the combined string. No gating, no checkpointing.
CREATE OR REPLACE PROCEDURE sp_etl_run_wf_ECI_Stage_Load ()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    l_summary     VARCHAR DEFAULT '';
    l_map_summary VARCHAR;
BEGIN
    -- VAL: m_Tgt_C_S_ECI_Pty_Validation
    l_map_summary := (CALL sp_snow_main_m_Tgt_C_S_ECI_Pty_Validation());
    l_summary := l_summary || '=== m_Tgt_C_S_ECI_Pty_Validation ===' || CHR(10) || l_map_summary || CHR(10);
    -- PTY: m_Tgt_C_S_ECI_Pty
    l_map_summary := (CALL sp_snow_main_m_Tgt_C_S_ECI_Pty());
    l_summary := l_summary || '=== m_Tgt_C_S_ECI_Pty ===' || CHR(10) || l_map_summary || CHR(10);
    -- RFA: m_Tgt_Stg_ECI_Pty_Reactivation_D_Family_Addr
    l_map_summary := (CALL sp_snow_main_m_Tgt_Stg_ECI_Pty_Reactivation_D_Family_Addr());
    l_summary := l_summary || '=== m_Tgt_Stg_ECI_Pty_Reactivation_D_Family_Addr ===' || CHR(10) || l_map_summary || CHR(10);
    -- RFP: m_Tgt_Stg_ECI_Pty_Reactivation_D_Family_Phn
    l_map_summary := (CALL sp_snow_main_m_Tgt_Stg_ECI_Pty_Reactivation_D_Family_Phn());
    l_summary := l_summary || '=== m_Tgt_Stg_ECI_Pty_Reactivation_D_Family_Phn ===' || CHR(10) || l_map_summary || CHR(10);
    -- RFM: m_Tgt_Stg_ECI_Pty_Reactivation_D_Medicaid
    l_map_summary := (CALL sp_snow_main_m_Tgt_Stg_ECI_Pty_Reactivation_D_Medicaid());
    l_summary := l_summary || '=== m_Tgt_Stg_ECI_Pty_Reactivation_D_Medicaid ===' || CHR(10) || l_map_summary || CHR(10);
    -- ALT: m_Tgt_C_S_ECI_Pty_Rle_Alt_Id
    l_map_summary := (CALL sp_snow_main_m_Tgt_C_S_ECI_Pty_Rle_Alt_Id());
    l_summary := l_summary || '=== m_Tgt_C_S_ECI_Pty_Rle_Alt_Id ===' || CHR(10) || l_map_summary || CHR(10);
    -- PHN: m_Tgt_C_S_ECI_Pty_Rle_Phn_And_EAddr
    l_map_summary := (CALL sp_snow_main_m_Tgt_C_S_ECI_Pty_Rle_Phn_And_EAddr());
    l_summary := l_summary || '=== m_Tgt_C_S_ECI_Pty_Rle_Phn_And_EAddr ===' || CHR(10) || l_map_summary || CHR(10);
    -- ADR: m_Tgt_C_S_ECI_Pty_Addr
    l_map_summary := (CALL sp_snow_main_m_Tgt_C_S_ECI_Pty_Addr());
    l_summary := l_summary || '=== m_Tgt_C_S_ECI_Pty_Addr ===' || CHR(10) || l_map_summary || CHR(10);
    -- REL: m_Tgt_C_S_ECI_Pty_Rle_Rel
    l_map_summary := (CALL sp_snow_main_m_Tgt_C_S_ECI_Pty_Rle_Rel());
    l_summary := l_summary || '=== m_Tgt_C_S_ECI_Pty_Rle_Rel ===' || CHR(10) || l_map_summary || CHR(10);
    RETURN l_summary;
EXCEPTION
    WHEN OTHER THEN
        RAISE;
END;
$$;
