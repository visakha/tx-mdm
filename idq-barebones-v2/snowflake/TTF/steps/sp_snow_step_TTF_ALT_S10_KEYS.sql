-- ============================================================================
-- sp_snow_step_TTF_ALT_S10_KEYS -- BARE-BONES variant (TTF)
--
-- Mapping: m_Tgt_C_S_TTF_Pty_Rle_Alt_Id. No config table, no checkpointing, no job-run id,
-- no input-existence check: the CTAS below is verbatim from v2.1 and
-- names its source work table literally. Returns the row count.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_step_TTF_ALT_S10_KEYS (
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
    -- ---- Step 10: KEYS (verbatim from current main)
CREATE OR REPLACE TRANSIENT TABLE WRK_TTF_ALT_S1_KEYS AS
    SELECT v.PTY_SRC_KEY, v.SUBMITDATE,
           NVL(v.PTY_SRC_KEY, '') || '|Member|024|' || NVL(v.PTY_SRC_KEY, '') AS pkey_src_object
      FROM V_TTF_ETL_SRC v
     -- Lkp_STG_TTF_PTY_INACTIVE_STS + Filter
     WHERE NOT EXISTS (SELECT 1 FROM STG_TTF_PTY_INACTIVE_STS i
                        WHERE i.SRC_KEY = v.PTY_SRC_KEY AND i.ROWID_SYSTEM = 'TTF'
                          AND i.DEACTIVATION_STS IS NOT NULL);
    SELECT COUNT(*) INTO :l_rows FROM WRK_TTF_ALT_S1_KEYS;
    RETURN :l_rows;
END;
$$;
