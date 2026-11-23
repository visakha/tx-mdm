-- ============================================================================
-- sp_snow_step_WIC_ADR_S20_VALIDATED  --  BARE-BONES STEP DRIVER VARIANT (WIC)
--
-- Mapping: m_Tgt_C_S_WIC_Pty_Addr, workflow wf_WIC_Stage_Load.
-- Step 20: VALIDATED.
-- Produces: WRK_WIC_ADDR_S20_VALIDATED -- Address validation with state TX, country US, zip only; state code resolved from the state lookup.
-- Consumes: WRK_WIC_ADDR_S10_ACTIVE
--
-- Bare-bones variant: stripped of config gating, job tracking and
-- input checks; the CTAS below is unchanged business SQL. The driver
-- passes the run timestamp; steps that do not use it still declare it
-- so every step call has the same shape.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_step_WIC_ADR_S20_VALIDATED (
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
    CREATE OR REPLACE TRANSIENT TABLE WRK_WIC_ADDR_S20_VALIDATED AS
    WITH
    lkp_cv AS (SELECT * FROM TABLE(fn_snow_helper41_common()))
    SELECT a.*,
           fn_snow_helper34_common(a.ADDRESS1, a.ADDRESS2, a.CITY, 'TX', a.ZIP_CODE, 'US', st.MSTR_CODE_VALUE) AS av
      FROM WRK_WIC_ADDR_S10_ACTIVE a
      LEFT JOIN lkp_cv st ON st.CODE_TYPE = 'STATE' AND st.SRC_SYS = 'WIC' AND st.SRC_CODE_VALUE = 'TX';;
    SELECT COUNT(*) INTO :l_rows FROM WRK_WIC_ADDR_S20_VALIDATED;
    RETURN :l_rows;
END;
$$;
