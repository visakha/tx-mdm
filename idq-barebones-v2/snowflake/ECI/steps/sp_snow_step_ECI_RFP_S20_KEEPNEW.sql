-- sp_snow_step_ECI_RFP_S20_KEEPNEW -- BARE-BONES variant (ECI)
-- Mapping: m_Tgt_Stg_ECI_Pty_Reactivation_D_Family_Phn, workflow wf_ECI_Stage_Load, step 20 (KEEP_NEW_ONLY).
-- Produces: WRK_ECI_RFP_S20_KEEPNEW.
-- Runs unconditionally from the driver; no gating, no checkpointing.
-- Business SQL below is verbatim from the v2.1 step procedure.
CREATE OR REPLACE PROCEDURE sp_snow_step_ECI_RFP_S20_KEEPNEW (
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
    -- ---- Step 20: KEEP-NEW FILTER (CTAS verbatim from current main) -----
    -- Purpose: drop rows already in the delta table. Reads ONLY step
    -- 10, so the filter sees the delta table as it was before this
    -- run's publish, exactly as in the original. This is the original
    -- lookup plus keep-new filter.
    CREATE OR REPLACE TRANSIENT TABLE WRK_ECI_RFP_S20_KEEPNEW AS
    SELECT h.*
      FROM WRK_ECI_RFP_S10_LATEST h
     WHERE NOT EXISTS (SELECT 1 FROM STG_ECI_D_FAMILY_PHONE d
                        WHERE d.ID_FAMILY_PHONE = h.ID_FAMILY_PHONE);
    SELECT COUNT(*) INTO :l_rows FROM WRK_ECI_RFP_S20_KEEPNEW;
    RETURN :l_rows;
END;
$$;
