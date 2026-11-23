-- sp_snow_pub_ECI_VAL_STG_ECI_PTY_INACTIVE_LOG_DEACTIVATION -- BARE-BONES variant (ECI)
-- Mapping: m_Tgt_C_S_ECI_Pty_Validation, workflow wf_ECI_Stage_Load, publish step 50 (PUBLISH_STG_ECI_PTY_INACTIVE_LOG_DEACTIVATION).
-- Target: STG_ECI_PTY_INACTIVE_LOG. Consumes: WRK_ECI_VAL_S30_ROUTED.
-- Called by the driver inside the single publish transaction; no gating, no checkpointing.
-- INSERT below is verbatim from the v2.1 publish procedure.
CREATE OR REPLACE PROCEDURE sp_snow_pub_ECI_VAL_STG_ECI_PTY_INACTIVE_LOG_DEACTIVATION ()
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
    -- 40b. Deactivation -> STG_ECI_PTY_INACTIVE_LOG (verbatim from current main)
    INSERT INTO STG_ECI_PTY_INACTIVE_LOG (SRC_KEY, ROWID_SYSTEM, ACTION, ACTION_DT)
    SELECT pkey_src_object, src_system, action_deactivation, run_ts
      FROM WRK_ECI_VAL_S30_ROUTED
     WHERE grp_deactivation;
    RETURN SQLROWCOUNT;
END;
$$;
