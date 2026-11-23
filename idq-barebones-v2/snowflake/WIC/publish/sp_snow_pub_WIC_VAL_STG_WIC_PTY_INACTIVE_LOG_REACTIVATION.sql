-- ============================================================================
-- sp_snow_pub_WIC_VAL_STG_WIC_PTY_INACTIVE_LOG_REACTIVATION  --  BARE-BONES STEP DRIVER VARIANT (WIC)
--
-- Mapping: m_Tgt_C_S_WIC_Pty_Validation, workflow wf_WIC_Stage_Load.
-- Target: STG_WIC_PTY_INACTIVE_LOG. Kind: STATUS (reactivation log rows).
-- WHERE guard: deactivation_sts IS NOT NULL AND NOT name_missing.
-- Reads ONLY WRK_WIC_VAL_S30_ROUTED. Reads the run_ts / mapping_name columns materialised in the final step; it takes no parameters.
--
-- Bare-bones variant: stripped of config gating, job tracking and
-- input checks; the INSERT below is unchanged business SQL. No
-- transaction control in this proc: the driver calls it inside ONE
-- publish transaction covering all branches.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_pub_WIC_VAL_STG_WIC_PTY_INACTIVE_LOG_REACTIVATION (
)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
    INSERT INTO STG_WIC_PTY_INACTIVE_LOG (SRC_KEY, ROWID_SYSTEM, ACTION, ACTION_DT)
    SELECT PTY_SRC_KEY, src_sys, action_reactivation, run_ts
      FROM WRK_WIC_VAL_S30_ROUTED
     WHERE deactivation_sts IS NOT NULL AND NOT name_missing;
    RETURN SQLROWCOUNT;
END;
$$;
