-- ============================================================================
-- sp_snow_step_WIC_PTY_S10_ACTIVE  --  BARE-BONES STEP DRIVER VARIANT (WIC)
--
-- Mapping: m_Tgt_C_S_WIC_Pty, workflow wf_WIC_Stage_Load.
-- Step 10: ACTIVE.
-- Produces: WRK_WIC_PTY_S10_ACTIVE -- Active source parties only (parties with a deactivation status removed). Only step that reads V_WIC_ETL_SRC.
-- Consumes: base tables (no work-table input)
--
-- Bare-bones variant: stripped of config gating, job tracking and
-- input checks; the CTAS below is unchanged business SQL. The driver
-- passes the run timestamp; steps that do not use it still declare it
-- so every step call has the same shape.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_step_WIC_PTY_S10_ACTIVE (
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
    CREATE OR REPLACE TRANSIENT TABLE WRK_WIC_PTY_S10_ACTIVE AS
    SELECT v.SOURCE_TABLE, v.DATEKEY, v.LOAD_DATE, v.ID, v.PTY_SRC_KEY, v.FIRST_NAME, v.LAST_NAME,
           v.MIDDLE_NAME, v.DOB, v.GENDER, v.BIRTH_WT_LB, v.BIRTH_WT_OZ, v.LANGUAGE_CD, v.ETHNICITY,
           v.RACE_WHITE_IND, v.RACE_AA_IND, v.RACE_ASIAN_IND, v.RACE_PI_IND, v.RACE_AN_IND
      FROM V_WIC_ETL_SRC v
     WHERE NOT EXISTS (SELECT 1 FROM STG_WIC_PTY_INACTIVE_STS i
                        WHERE i.SRC_KEY = v.PTY_SRC_KEY AND i.ROWID_SYSTEM = 'WIC'
                          AND i.DEACTIVATION_STS IS NOT NULL);;
    SELECT COUNT(*) INTO :l_rows FROM WRK_WIC_PTY_S10_ACTIVE;
    RETURN :l_rows;
END;
$$;
