-- ============================================================================
-- sp_snow_step_WIC_ALT_S10_KEYS  --  BARE-BONES STEP DRIVER VARIANT (WIC)
--
-- Mapping: m_Tgt_C_S_WIC_Pty_Rle_Alt_Id, workflow wf_WIC_Stage_Load.
-- Step 10: KEYS.
-- Produces: WRK_WIC_ALT_S10_KEYS -- Party-role key, id type (020 or 021), alternate-id key. Only step that reads V_WIC_ETL_SRC.
-- Consumes: base tables (no work-table input)
--
-- Bare-bones variant: stripped of config gating, job tracking and
-- input checks; the CTAS below is unchanged business SQL. The driver
-- passes the run timestamp; steps that do not use it still declare it
-- so every step call has the same shape.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_step_WIC_ALT_S10_KEYS (
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
    CREATE OR REPLACE TRANSIENT TABLE WRK_WIC_ALT_S10_KEYS AS
    SELECT v.ID, v.PTY_SRC_KEY, v.DATEKEY, v.SOURCE_TABLE,
           NVL(v.PTY_SRC_KEY, '') || '|Member'                                    AS pty_rle_fk,
           IFF(v.SOURCE_TABLE = 'CLIENT', '020', '021')                           AS alt_id_tp,
           NVL(v.PTY_SRC_KEY, '') || '|Member|' || IFF(v.SOURCE_TABLE = 'CLIENT', '020', '021') || '|'
           || NVL(LPAD(TO_VARCHAR(v.ID), 12, '0'), '')                             AS pkey_src_object
      FROM V_WIC_ETL_SRC v;;
    SELECT COUNT(*) INTO :l_rows FROM WRK_WIC_ALT_S10_KEYS;
    RETURN :l_rows;
END;
$$;
