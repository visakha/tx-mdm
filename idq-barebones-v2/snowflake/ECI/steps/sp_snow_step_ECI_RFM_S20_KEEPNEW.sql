-- sp_snow_step_ECI_RFM_S20_KEEPNEW -- BARE-BONES variant (ECI)
-- Mapping: m_Tgt_Stg_ECI_Pty_Reactivation_D_Medicaid, workflow wf_ECI_Stage_Load, step 20 (KEEP_NEW_ONLY).
-- Produces: WRK_ECI_RFM_S20_KEEPNEW.
-- Runs unconditionally from the driver; no gating, no checkpointing.
-- Business SQL below is verbatim from the v2.1 step procedure.
CREATE OR REPLACE PROCEDURE sp_snow_step_ECI_RFM_S20_KEEPNEW (
    P_TEST_LOOKUP_RESULT VARCHAR,
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
    -- ---- Step 20: KEEP-NEW FILTER + ONE ROW PER ID (verbatim CTAS) -----
    CREATE OR REPLACE TRANSIENT TABLE WRK_ECI_RFM_S20_KEEPNEW AS
    SELECT h.*
      FROM WRK_ECI_RFM_S10_LATEST h
     WHERE IFF(:P_TEST_LOOKUP_RESULT = 'Y', h.LKP_ID_MEDICAID IS NULL, h.ID_MEDICAID IS NULL)
    QUALIFY ROW_NUMBER() OVER (PARTITION BY h.ID_MEDICAID ORDER BY h.DATE_MODIFIED DESC NULLS LAST) = 1;
    SELECT COUNT(*) INTO :l_rows FROM WRK_ECI_RFM_S20_KEEPNEW;
    RETURN :l_rows;
END;
$$;
