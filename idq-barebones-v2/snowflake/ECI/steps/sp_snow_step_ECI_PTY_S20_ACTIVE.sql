-- sp_snow_step_ECI_PTY_S20_ACTIVE -- BARE-BONES variant (ECI)
-- Mapping: m_Tgt_C_S_ECI_Pty, workflow wf_ECI_Stage_Load, step 20 (ACTIVE_PARTIES).
-- Produces: WRK_ECI_PTY_S20_ACTIVE.
-- Runs unconditionally from the driver; no gating, no checkpointing.
-- Business SQL below is verbatim from the v2.1 step procedure.
CREATE OR REPLACE PROCEDURE sp_snow_step_ECI_PTY_S20_ACTIVE (
    P_RUN_TS TIMESTAMP_NTZ
)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    l_rows       NUMBER DEFAULT 0;
BEGIN
    -- ---- Step 20: ACTIVE PARTIES ONLY (verbatim from current main)
    CREATE OR REPLACE TRANSIENT TABLE WRK_ECI_PTY_S20_ACTIVE AS
    SELECT e.*
      FROM WRK_ECI_PTY_S10_SRC e
     WHERE NOT EXISTS (SELECT 1 FROM STG_ECI_PTY_INACTIVE_STS i
                        WHERE i.SRC_KEY = e.pkey_src_object AND i.ROWID_SYSTEM = e.src_system
                          AND i.DEACTIVATION_STS IS NOT NULL);
    SELECT COUNT(*) INTO :l_rows FROM WRK_ECI_PTY_S20_ACTIVE;
    RETURN :l_rows;
END;
$$;
