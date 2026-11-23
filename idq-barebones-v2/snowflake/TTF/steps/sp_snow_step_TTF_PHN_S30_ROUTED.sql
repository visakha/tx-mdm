-- ============================================================================
-- sp_snow_step_TTF_PHN_S30_ROUTED -- BARE-BONES variant (TTF)
--
-- Mapping: m_Tgt_C_S_TTF_Pty_Rle_Phn. No config table, no checkpointing, no job-run id,
-- no input-existence check: the CTAS below is verbatim from v2.1 and
-- names its source work table literally. Returns the row count.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_step_TTF_PHN_S30_ROUTED (
    P_RUN_TS TIMESTAMP_NTZ
)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    c_mapping    VARCHAR DEFAULT 'm_Tgt_C_S_TTF_Pty_Rle_Phn';
    l_rows       NUMBER DEFAULT 0;
BEGIN
    -- ---- Step 30: ROUTED (verbatim from current main)
CREATE OR REPLACE TRANSIENT TABLE WRK_TTF_PHN_S3_ROUTED AS
    WITH
    lkp_exc  AS (SELECT * FROM TABLE(fn_snow_helper40_common()))
    SELECT c.*,
           xp.EXCEPTION_DESC                                    AS phone_exception_desc,
           '1' /* TIMELINE: VERSION_SEQ */                     AS version_seq,
           1                                                    AS hub_state_ind,
           NVL(c.PTY_SRC_KEY, '') || '|Member'                  AS pty_rle_fk,
           'Telephone'                                          AS phn_tp,
           '001'                                                AS usg_tp,
           'Primary'                                            AS pref_lvl,
           'TTF'                                                AS src_sys,
           :P_RUN_TS                                            AS run_ts,
           :c_mapping                                           AS mapping_name,
           'Rejected Record'                                    AS exc_type_rejected,
           'Main Phone'                                         AS attr_phone,
           /* BAD DATA: unique keys Snowflake does not enforce */
           (ROW_NUMBER() OVER (PARTITION BY c.phone_exception_code IS NULL, c.phn_pkey
                                   ORDER BY c.SUBMITDATE DESC) = 1
            AND xph.PKEY_SRC_OBJECT IS NULL)                    AS uq_phn,
           ROW_NUMBER() OVER (PARTITION BY c.phone_exception_code IS NULL, c.PTY_SRC_KEY, c.phone_exception_code
                                  ORDER BY c.SUBMITDATE DESC) = 1 AS uq_phone_exc
      FROM WRK_TTF_PHN_S2_CHECKED c
      LEFT JOIN lkp_exc xp ON xp.EXCEPTION_CODE = c.phone_exception_code
      LEFT JOIN (SELECT DISTINCT PKEY_SRC_OBJECT FROM C_S_TTF_PTY_RLE_PHN WHERE VERSION_SEQ = 1) xph
             ON xph.PKEY_SRC_OBJECT = c.phn_pkey;
    SELECT COUNT(*) INTO :l_rows FROM WRK_TTF_PHN_S3_ROUTED;
    RETURN :l_rows;
END;
$$;
