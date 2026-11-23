-- sp_snow_step_ECI_PHN_S20_ACTIVE -- BARE-BONES variant (ECI)
-- Mapping: m_Tgt_C_S_ECI_Pty_Rle_Phn_And_EAddr, workflow wf_ECI_Stage_Load, step 20 (ACTIVE_PHN_EADDR).
-- Produces: WRK_ECI_PHN_S20_ACTIVE.
-- Runs unconditionally from the driver; no gating, no checkpointing.
-- Business SQL below is verbatim from the v2.1 step procedure.
CREATE OR REPLACE PROCEDURE sp_snow_step_ECI_PHN_S20_ACTIVE (
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
    -- ---- Step 20 CTAS (verbatim from the original main procedure) ----
CREATE OR REPLACE TRANSIENT TABLE WRK_ECI_PHN_S20_ACTIVE AS
    SELECT s.*
      FROM WRK_ECI_PHN_S10_SRC s
     WHERE NOT EXISTS (SELECT 1 FROM STG_ECI_PTY_INACTIVE_STS i
                        WHERE i.SRC_KEY = s.pty_src_key AND i.ROWID_SYSTEM = 'ECI'
                          AND i.DEACTIVATION_STS IS NOT NULL);
    SELECT COUNT(*) INTO :l_rows FROM WRK_ECI_PHN_S20_ACTIVE;
    RETURN :l_rows;
END;
$$;
