-- sp_snow_pub_ECI_VAL_STG_ECI_PTY_INACTIVE_LOG_REACTIVATION -- BARE-BONES variant (ECI)
-- Mapping: m_Tgt_C_S_ECI_Pty_Validation, workflow wf_ECI_Stage_Load, publish step 70 (PUBLISH_STG_ECI_PTY_INACTIVE_LOG_REACTIVATION).
-- Target: STG_ECI_PTY_INACTIVE_LOG. Consumes: WRK_ECI_VAL_S30_ROUTED.
-- Called by the driver inside the single publish transaction; no gating, no checkpointing.
-- INSERT below is verbatim from the v2.1 publish procedure.
CREATE OR REPLACE PROCEDURE sp_snow_pub_ECI_VAL_STG_ECI_PTY_INACTIVE_LOG_REACTIVATION ()
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
    -- 40d. Reactivation -> STG_ECI_PTY_INACTIVE_LOG (verbatim from current main)
    INSERT INTO STG_ECI_PTY_INACTIVE_LOG (SRC_KEY, ROWID_SYSTEM, ACTION, ACTION_DT)
    SELECT pkey_src_object, src_system, action_reactivation, run_ts
      FROM WRK_ECI_VAL_S30_ROUTED
     WHERE grp_reactivation;
    RETURN SQLROWCOUNT;
END;
$$;
