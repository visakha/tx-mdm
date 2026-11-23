-- sp_snow_pub_ECI_VAL_STG_ECI_PTY_INACTIVE_STS -- BARE-BONES variant (ECI)
-- Mapping: m_Tgt_C_S_ECI_Pty_Validation, workflow wf_ECI_Stage_Load, publish step 60 (PUBLISH_STG_ECI_PTY_INACTIVE_STS).
-- Target: STG_ECI_PTY_INACTIVE_STS. Consumes: WRK_ECI_VAL_S30_ROUTED.
-- Called by the driver inside the single publish transaction; no gating, no checkpointing.
-- INSERT below is verbatim from the v2.1 publish procedure.
CREATE OR REPLACE PROCEDURE sp_snow_pub_ECI_VAL_STG_ECI_PTY_INACTIVE_STS ()
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
    -- 40c. New deactivations (no status yet) -> STG_ECI_PTY_INACTIVE_STS (verbatim from current main)
    INSERT INTO STG_ECI_PTY_INACTIVE_STS (SRC_KEY, ROWID_SYSTEM, DEACTIVATION_STS, DEACTIVATION_DT)
    SELECT pkey_src_object, src_system, new_deactivation_sts, run_ts
      FROM WRK_ECI_VAL_S30_ROUTED
     WHERE grp_deactivation AND deactivation_sts IS NULL;
    RETURN SQLROWCOUNT;
END;
$$;
