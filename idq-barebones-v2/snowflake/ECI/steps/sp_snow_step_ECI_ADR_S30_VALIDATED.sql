-- sp_snow_step_ECI_ADR_S30_VALIDATED -- BARE-BONES variant (ECI)
-- Mapping: m_Tgt_C_S_ECI_Pty_Addr, workflow wf_ECI_Stage_Load, step 30 (ADDR_VALIDATION).
-- Produces: WRK_ECI_ADR_S30_VALIDATED.
-- Runs unconditionally from the driver; no gating, no checkpointing.
-- Business SQL below is verbatim from the v2.1 step procedure.
CREATE OR REPLACE PROCEDURE sp_snow_step_ECI_ADR_S30_VALIDATED (
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
    -- ---- Step 30: ADDR_VALIDATION (verbatim from current main)
    CREATE OR REPLACE TRANSIENT TABLE WRK_ECI_ADR_S30_VALIDATED AS
    WITH
    lkp_cv AS (SELECT * FROM TABLE(fn_snow_helper41_common()))
    SELECT k.*,
           fn_snow_helper34_common(k.ADDRESS1, k.ADDRESS2, k.CITY_NAME, k.STATE_ABBREV,
                                   NVL(k.ZIP_CODE, '') || IFF(k.ZIP_SFX IS NOT NULL, '-' || k.ZIP_SFX, ''),
                                   'US', st.MSTR_CODE_VALUE) AS av
      FROM WRK_ECI_ADR_S20_KEYED k
      LEFT JOIN lkp_cv st ON st.CODE_TYPE = 'STATE' AND st.SRC_SYS = 'ECI'
                         AND st.SRC_CODE_VALUE = UPPER(TRIM(k.STATE_ABBREV));
    SELECT COUNT(*) INTO :l_rows FROM WRK_ECI_ADR_S30_VALIDATED;
    RETURN :l_rows;
END;
$$;
