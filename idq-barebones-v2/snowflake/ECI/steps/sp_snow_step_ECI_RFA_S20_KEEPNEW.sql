-- sp_snow_step_ECI_RFA_S20_KEEPNEW -- BARE-BONES variant (ECI)
-- Mapping: m_Tgt_Stg_ECI_Pty_Reactivation_D_Family_Addr, workflow wf_ECI_Stage_Load, step 20 (KEEP_NEW_ONLY).
-- Produces: WRK_ECI_RFA_S20_KEEPNEW.
-- Runs unconditionally from the driver; no gating, no checkpointing.
-- Business SQL below is verbatim from the v2.1 step procedure.
CREATE OR REPLACE PROCEDURE sp_snow_step_ECI_RFA_S20_KEEPNEW (
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
    -- ---- Step 20: KEEP-NEW FILTER (verbatim from current main)
    CREATE OR REPLACE TRANSIENT TABLE WRK_ECI_RFA_S20_KEEPNEW AS
    SELECT h.*
      FROM WRK_ECI_RFA_S10_LATEST h
     WHERE NOT EXISTS (SELECT 1 FROM STG_ECI_D_FAMILY_ADDRESS d
                        WHERE d.ID_FAMILY_ADDRESS = h.ID_FAMILY_ADDRESS);
    SELECT COUNT(*) INTO :l_rows FROM WRK_ECI_RFA_S20_KEEPNEW;
    RETURN :l_rows;
END;
$$;
