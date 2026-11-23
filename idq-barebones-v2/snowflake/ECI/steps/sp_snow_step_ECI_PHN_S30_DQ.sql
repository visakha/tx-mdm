-- sp_snow_step_ECI_PHN_S30_DQ -- BARE-BONES variant (ECI)
-- Mapping: m_Tgt_C_S_ECI_Pty_Rle_Phn_And_EAddr, workflow wf_ECI_Stage_Load, step 30 (DQ_CLEAN_VALIDATE).
-- Produces: WRK_ECI_PHN_S30_DQ.
-- Runs unconditionally from the driver; no gating, no checkpointing.
-- Business SQL below is verbatim from the v2.1 step procedure.
CREATE OR REPLACE PROCEDURE sp_snow_step_ECI_PHN_S30_DQ (
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
    -- ---- Step 30 CTAS (verbatim from the original main procedure) ----
CREATE OR REPLACE TRANSIENT TABLE WRK_ECI_PHN_S30_DQ AS
    SELECT a.*,
           IFF(NOT a.is_email,
               fn_snow_helper23_common(IFF(LENGTH(a.PHONE_EMAIL) = 7, '000' || a.PHONE_EMAIL, a.PHONE_EMAIL)),
               NULL)                                                          AS std_phone,
           IFF(a.is_email, fn_snow_helper22_common(a.PHONE_EMAIL), NULL)       AS em
      FROM WRK_ECI_PHN_S20_ACTIVE a;
    SELECT COUNT(*) INTO :l_rows FROM WRK_ECI_PHN_S30_DQ;
    RETURN :l_rows;
END;
$$;
