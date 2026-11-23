-- ============================================================================
-- sp_snow_step_WIC_ALT_S20_READY  --  BARE-BONES STEP DRIVER VARIANT (WIC)
--
-- Mapping: m_Tgt_C_S_WIC_Pty_Rle_Alt_Id, workflow wf_WIC_Stage_Load.
-- Step 20: READY.
-- Produces: WRK_WIC_ALT_S20_READY -- Deactivation filter applied, keys already in the target skipped, one row per alternate-id key (latest DATEKEY wins). Guard evaluated here, before publish, as in the original single query.
-- Consumes: WRK_WIC_ALT_S10_KEYS
--
-- Bare-bones variant: stripped of config gating, job tracking and
-- input checks; the CTAS below is unchanged business SQL. The driver
-- passes the run timestamp; steps that do not use it still declare it
-- so every step call has the same shape.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_step_WIC_ALT_S20_READY (
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
    CREATE OR REPLACE TRANSIENT TABLE WRK_WIC_ALT_S20_READY AS
    SELECT x.*
      FROM WRK_WIC_ALT_S10_KEYS x
      LEFT JOIN (SELECT DISTINCT PKEY_SRC_OBJECT FROM C_S_WIC_PTY_RLE_ALT_ID WHERE VERSION_SEQ = 1) xa
             ON xa.PKEY_SRC_OBJECT = x.pkey_src_object
     -- Lookup_STG_WIC_PTY_INACTIVE_STS + Filter
     WHERE NOT EXISTS (SELECT 1 FROM STG_WIC_PTY_INACTIVE_STS i
                        WHERE i.SRC_KEY = x.PTY_SRC_KEY AND i.ROWID_SYSTEM = 'WIC'
                          AND i.DEACTIVATION_STS IS NOT NULL)
       /* BAD DATA: unique key not yet in the table, first row per key in this run */
       AND xa.PKEY_SRC_OBJECT IS NULL
    QUALIFY ROW_NUMBER() OVER (PARTITION BY x.pkey_src_object ORDER BY x.DATEKEY DESC NULLS LAST) = 1;;
    SELECT COUNT(*) INTO :l_rows FROM WRK_WIC_ALT_S20_READY;
    RETURN :l_rows;
END;
$$;
