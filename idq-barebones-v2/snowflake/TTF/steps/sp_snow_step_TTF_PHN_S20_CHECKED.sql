-- ============================================================================
-- sp_snow_step_TTF_PHN_S20_CHECKED -- BARE-BONES variant (TTF)
--
-- Mapping: m_Tgt_C_S_TTF_Pty_Rle_Phn. No config table, no checkpointing, no job-run id,
-- no input-existence check: the CTAS below is verbatim from v2.1 and
-- names its source work table literally. Returns the row count.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_step_TTF_PHN_S20_CHECKED (
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
    -- ---- Step 20: CHECKED (verbatim from current main)
CREATE OR REPLACE TRANSIENT TABLE WRK_TTF_PHN_S2_CHECKED AS
    WITH
    lkp_area AS (SELECT * FROM TABLE(fn_snow_helper44_common()))
    SELECT s.*,
           /* VALIDATION */ fn_snow_helper24_common(s.std_phone, 'TTF', '001', ar.NPA_ID, ar.SERVICE) AS phone_exception_code
      FROM WRK_TTF_PHN_S1_SRC s
      LEFT JOIN lkp_area ar ON ar.NPA_ID = SUBSTR(s.std_phone, 1, 3);
    SELECT COUNT(*) INTO :l_rows FROM WRK_TTF_PHN_S2_CHECKED;
    RETURN :l_rows;
END;
$$;
