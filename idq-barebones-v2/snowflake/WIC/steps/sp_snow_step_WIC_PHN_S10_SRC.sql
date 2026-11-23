-- ============================================================================
-- sp_snow_step_WIC_PHN_S10_SRC  --  BARE-BONES STEP DRIVER VARIANT (WIC)
--
-- Mapping: m_Tgt_C_S_WIC_Pty_Rle_Phn_And_EAddr, workflow wf_WIC_Stage_Load.
-- Step 10: SRC.
-- Produces: WRK_WIC_PHN_S10_SRC -- Active source rows only (deactivation-status filter) plus party-role, phone and e-mail keys, standardised phone, and the e-mail validation object (NULL when e-mail is null). Only step that reads V_WIC_ETL_SRC.
-- Consumes: base tables (no work-table input)
--
-- Bare-bones variant: stripped of config gating, job tracking and
-- input checks; the CTAS below is unchanged business SQL. The driver
-- passes the run timestamp; steps that do not use it still declare it
-- so every step call has the same shape.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_step_WIC_PHN_S10_SRC (
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
    CREATE OR REPLACE TRANSIENT TABLE WRK_WIC_PHN_S10_SRC AS
    SELECT v.SOURCE_TABLE, v.ID, v.PTY_SRC_KEY, v.DATEKEY, v.FID, v.PHONE, v.EMAIL,
           NVL(v.PTY_SRC_KEY, '') || '|Member'                                            AS pty_rle_fk,
           NVL(v.PTY_SRC_KEY, '') || '|Member|Telephone|001|' || NVL(TO_VARCHAR(v.FID), '') || '|'
           || NVL(TRIM(v.PHONE), '')                                                      AS phn_pkey,
           NVL(v.PTY_SRC_KEY, '') || '|Member|001|' || NVL(TO_VARCHAR(v.FID), '') || '|' || NVL(v.EMAIL, '')
                                                                                          AS eaddr_pkey,
           fn_snow_helper23_common(v.PHONE)                                               AS std_phone,
           IFF(v.EMAIL IS NOT NULL, fn_snow_helper22_common(v.EMAIL), NULL)               AS em
      FROM V_WIC_ETL_SRC v
     WHERE NOT EXISTS (SELECT 1 FROM STG_WIC_PTY_INACTIVE_STS i
                        WHERE i.SRC_KEY = v.PTY_SRC_KEY AND i.ROWID_SYSTEM = 'WIC'
                          AND i.DEACTIVATION_STS IS NOT NULL);;
    SELECT COUNT(*) INTO :l_rows FROM WRK_WIC_PHN_S10_SRC;
    RETURN :l_rows;
END;
$$;
