-- ============================================================================
-- sp_snow_step_TTF_PTY_S10_ACTIVE -- BARE-BONES variant (TTF)
--
-- Mapping: m_Tgt_C_S_TTF_Pty. No config table, no checkpointing, no job-run id,
-- no input-existence check: the CTAS below is verbatim from v2.1 and
-- names its source work table literally. Returns the row count.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_step_TTF_PTY_S10_ACTIVE (
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
    -- ---- Step 10: ACTIVE (verbatim from current main)
CREATE OR REPLACE TRANSIENT TABLE WRK_TTF_PTY_S1_ACTIVE AS
    SELECT v.CLIENTS_ID, v.FIRSTNAME, v.LASTNAME, v.MIDDLENAME, v.DOB, v.SUBMITDATE, v.SEXID,
           v.RACEETHNICITYID, v.PTY_SRC_KEY, v.LOAD_DATE,
           DECODE(v.SEXID, '33', 'F', '34', 'M', 'U')            AS gender,
           IFF(v.RACEETHNICITYID = '55', '55', NULL)             AS ethnicity
      FROM V_TTF_ETL_SRC v
     WHERE NOT EXISTS (SELECT 1 FROM STG_TTF_PTY_INACTIVE_STS i
                        WHERE i.SRC_KEY = v.PTY_SRC_KEY AND i.ROWID_SYSTEM = 'TTF'
                          AND i.DEACTIVATION_STS IS NOT NULL);
    SELECT COUNT(*) INTO :l_rows FROM WRK_TTF_PTY_S1_ACTIVE;
    RETURN :l_rows;
END;
$$;
