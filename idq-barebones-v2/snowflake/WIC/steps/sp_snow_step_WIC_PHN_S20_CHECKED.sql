-- ============================================================================
-- sp_snow_step_WIC_PHN_S20_CHECKED  --  BARE-BONES STEP DRIVER VARIANT (WIC)
--
-- Mapping: m_Tgt_C_S_WIC_Pty_Rle_Phn_And_EAddr, workflow wf_WIC_Stage_Load.
-- Step 20: CHECKED.
-- Produces: WRK_WIC_PHN_S20_CHECKED -- Phone exception code from the area-code lookup (usage 001); standardised e-mail pulled out.
-- Consumes: WRK_WIC_PHN_S10_SRC
--
-- Bare-bones variant: stripped of config gating, job tracking and
-- input checks; the CTAS below is unchanged business SQL. The driver
-- passes the run timestamp; steps that do not use it still declare it
-- so every step call has the same shape.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_step_WIC_PHN_S20_CHECKED (
    P_RUN_TS                 TIMESTAMP_NTZ
)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    l_rows NUMBER DEFAULT 0;
BEGIN
    CREATE OR REPLACE TRANSIENT TABLE WRK_WIC_PHN_S20_CHECKED AS
    WITH
    lkp_area AS (SELECT * FROM TABLE(fn_snow_helper44_common()))
    SELECT s.*,
           /* VALIDATION */ fn_snow_helper24_common(s.std_phone, 'WIC', '001', ar.NPA_ID, ar.SERVICE) AS phone_exception_code,
           s.em:email_address::VARCHAR                                                   AS std_email
      FROM WRK_WIC_PHN_S10_SRC s
      LEFT JOIN lkp_area ar ON ar.NPA_ID = SUBSTR(s.std_phone, 1, 3);;
    SELECT COUNT(*) INTO :l_rows FROM WRK_WIC_PHN_S20_CHECKED;
    RETURN :l_rows;
END;
$$;
