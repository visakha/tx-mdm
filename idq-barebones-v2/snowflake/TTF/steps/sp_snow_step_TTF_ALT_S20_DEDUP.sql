-- ============================================================================
-- sp_snow_step_TTF_ALT_S20_DEDUP -- BARE-BONES variant (TTF)
--
-- Mapping: m_Tgt_C_S_TTF_Pty_Rle_Alt_Id. No config table, no checkpointing, no job-run id,
-- no input-existence check: the CTAS below is verbatim from v2.1 and
-- names its source work table literally. Returns the row count.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_step_TTF_ALT_S20_DEDUP (
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
    -- ---- Step 20: DEDUP (verbatim from current main)
CREATE OR REPLACE TRANSIENT TABLE WRK_TTF_ALT_S2_DEDUP AS
    SELECT k.*
      FROM WRK_TTF_ALT_S1_KEYS k
      LEFT JOIN (SELECT DISTINCT PKEY_SRC_OBJECT FROM C_S_TTF_PTY_RLE_ALT_ID WHERE VERSION_SEQ = 1) xa
             ON xa.PKEY_SRC_OBJECT = k.pkey_src_object
     /* BAD DATA: unique key not yet in the table, first row per key in this run */
     WHERE xa.PKEY_SRC_OBJECT IS NULL
    QUALIFY ROW_NUMBER() OVER (PARTITION BY k.pkey_src_object ORDER BY k.SUBMITDATE DESC NULLS LAST) = 1;
    SELECT COUNT(*) INTO :l_rows FROM WRK_TTF_ALT_S2_DEDUP;
    RETURN :l_rows;
END;
$$;
