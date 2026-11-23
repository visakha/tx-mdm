-- ============================================================================
-- sp_snow_step_TTF_PHN_S10_SRC -- BARE-BONES variant (TTF)
--
-- Mapping: m_Tgt_C_S_TTF_Pty_Rle_Phn. No config table, no checkpointing, no job-run id,
-- no input-existence check: the CTAS below is verbatim from v2.1 and
-- names its source work table literally. Returns the row count.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_step_TTF_PHN_S10_SRC (
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
    -- ---- Step 10: SRC (verbatim from current main)
CREATE OR REPLACE TRANSIENT TABLE WRK_TTF_PHN_S1_SRC AS
    SELECT v.PHONE, v.SUBMITDATE, v.PTY_SRC_KEY,
           NVL(v.PTY_SRC_KEY, '') || '|Member|Telephone|001|' || v.PHONE AS phn_pkey,
           fn_snow_helper23_common(v.PHONE)                             AS std_phone
      FROM V_TTF_ETL_SRC v
     WHERE v.PHONE IS NOT NULL                                           -- Filt_null_phone
       AND NOT EXISTS (SELECT 1 FROM STG_TTF_PTY_INACTIVE_STS i          -- fil_deactivated_status
                        WHERE i.SRC_KEY = v.PTY_SRC_KEY AND i.ROWID_SYSTEM = 'TTF'
                          AND i.DEACTIVATION_STS IS NOT NULL);
    SELECT COUNT(*) INTO :l_rows FROM WRK_TTF_PHN_S1_SRC;
    RETURN :l_rows;
END;
$$;
