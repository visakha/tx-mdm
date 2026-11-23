-- ============================================================================
-- sp_snow_step_WIC_ADR_S10_ACTIVE  --  BARE-BONES STEP DRIVER VARIANT (WIC)
--
-- Mapping: m_Tgt_C_S_WIC_Pty_Addr, workflow wf_WIC_Stage_Load.
-- Step 10: ACTIVE.
-- Produces: WRK_WIC_ADDR_S10_ACTIVE -- Active source addresses only (deactivation-status filter) plus the address key. Only step that reads V_WIC_ETL_SRC.
-- Consumes: base tables (no work-table input)
--
-- Bare-bones variant: stripped of config gating, job tracking and
-- input checks; the CTAS below is unchanged business SQL. The driver
-- passes the run timestamp; steps that do not use it still declare it
-- so every step call has the same shape.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_step_WIC_ADR_S10_ACTIVE (
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
    CREATE OR REPLACE TRANSIENT TABLE WRK_WIC_ADDR_S10_ACTIVE AS
    SELECT v.SOURCE_TABLE, v.ID, v.FID, v.DATE_ADDRESS_VALID_FROM, v.ADDRESS1, v.ADDRESS2, v.CITY, v.COUNTY,
           v.ZIP_CODE, v.PTY_SRC_KEY,
           NVL(v.PTY_SRC_KEY, '') || '|Member|002|' || NVL(LPAD(TO_VARCHAR(v.FID), 12, '0'), '') || '|'
           || NVL(TRIM(UPPER(v.ADDRESS1)), '') || '|' || NVL(TRIM(UPPER(v.ADDRESS2)), '') || '|'
           || NVL(UPPER(v.CITY), '') || '||' || NVL(v.ZIP_CODE, '')                      AS pkey_src_object
      FROM V_WIC_ETL_SRC v
     WHERE NOT EXISTS (SELECT 1 FROM STG_WIC_PTY_INACTIVE_STS i
                        WHERE i.SRC_KEY = v.PTY_SRC_KEY AND i.ROWID_SYSTEM = 'WIC'
                          AND i.DEACTIVATION_STS IS NOT NULL);;
    SELECT COUNT(*) INTO :l_rows FROM WRK_WIC_ADDR_S10_ACTIVE;
    RETURN :l_rows;
END;
$$;
