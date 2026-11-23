-- ============================================================================
-- sp_snow_step_TTF_VAL_S20_NAMED -- BARE-BONES variant (TTF)
--
-- Mapping: m_Tgt_C_S_TTF_Pty_Validation. No config table, no checkpointing, no job-run id,
-- no input-existence check: the CTAS below is verbatim from v2.1 and
-- names its source work table literally. Returns the row count.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_step_TTF_VAL_S20_NAMED (
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
    -- ---- Step 20: NAMED (verbatim from current main)
CREATE OR REPLACE TRANSIENT TABLE WRK_TTF_VAL_S2_NAMED AS
    SELECT n.*,
           n.nm:first_name::VARCHAR    AS std_first_name,
           n.nm:middle_name::VARCHAR   AS std_mdl_name,
           n.nm:last_name::VARCHAR     AS std_lst_name,
           n.nm:src_full_name::VARCHAR AS std_src_full_name,
           /* VALIDATION */
           (fn_snow_helper03_common(n.nm:first_name::VARCHAR)
            OR fn_snow_helper03_common(n.nm:last_name::VARCHAR))                          AS name_missing,
           NVL(UPPER(n.nm:last_name::VARCHAR) = 'DECLINED'
               OR UPPER(n.nm:first_name::VARCHAR) = 'DECLINED', FALSE)                    AS name_declined,
           NVL(UPPER(n.nm:last_name::VARCHAR) = 'DO_NOT_DISCLOSE'
               OR UPPER(n.nm:first_name::VARCHAR) = 'DO_NOT_DISCLOSE', FALSE)             AS name_undisclosed
      FROM WRK_TTF_VAL_S1_ENRICHED n;
    SELECT COUNT(*) INTO :l_rows FROM WRK_TTF_VAL_S2_NAMED;
    RETURN :l_rows;
END;
$$;
