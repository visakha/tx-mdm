-- ============================================================================
-- sp_snow_pub_WIC_VAL_STG_WIC_PTY_INACTIVE_STS  --  BARE-BONES STEP DRIVER VARIANT (WIC)
--
-- Mapping: m_Tgt_C_S_WIC_Pty_Validation, workflow wf_WIC_Stage_Load.
-- Target: STG_WIC_PTY_INACTIVE_STS. Kind: STATUS (new deactivation-status rows).
-- WHERE guard: name_missing AND deactivation_sts IS NULL.
-- Reads ONLY WRK_WIC_VAL_S30_ROUTED. Reads the run_ts / mapping_name columns materialised in the final step; it takes no parameters.
--
-- Bare-bones variant: stripped of config gating, job tracking and
-- input checks; the INSERT below is unchanged business SQL. No
-- transaction control in this proc: the driver calls it inside ONE
-- publish transaction covering all branches.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_pub_WIC_VAL_STG_WIC_PTY_INACTIVE_STS (
)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
    INSERT INTO STG_WIC_PTY_INACTIVE_STS (SRC_KEY, ROWID_SYSTEM, DEACTIVATION_STS, DEACTIVATION_DT)
    SELECT PTY_SRC_KEY, src_sys, new_deactivation_sts, run_ts
      FROM WRK_WIC_VAL_S30_ROUTED
     WHERE name_missing AND deactivation_sts IS NULL;
    RETURN SQLROWCOUNT;
END;
$$;
