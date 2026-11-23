-- sp_snow_step_ECI_PHN_S40_ROUTED -- BARE-BONES variant (ECI)
-- Mapping: m_Tgt_C_S_ECI_Pty_Rle_Phn_And_EAddr, workflow wf_ECI_Stage_Load, step 40 (ROUTED_GROUPS).
-- Produces: WRK_ECI_PHN_S40_ROUTED.
-- Runs unconditionally from the driver; no gating, no checkpointing.
-- Business SQL below is verbatim from the v2.1 step procedure.
CREATE OR REPLACE PROCEDURE sp_snow_step_ECI_PHN_S40_ROUTED (
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
    -- ---- Step 40 CTAS (verbatim from the original main procedure) ----
CREATE OR REPLACE TRANSIENT TABLE WRK_ECI_PHN_S40_ROUTED AS
    WITH
    lkp_exc  AS (SELECT * FROM TABLE(fn_snow_helper40_common())),
    lkp_area AS (SELECT * FROM TABLE(fn_snow_helper44_common())),
    checked AS (
        SELECT d.*,
               IFF(NOT d.is_email,
                   fn_snow_helper24_common(d.std_phone, 'ECI', d.USG_TP, ar.NPA_ID, ar.SERVICE), NULL) AS phone_exception_code,
               d.em:email_address::VARCHAR                                        AS std_email
          FROM WRK_ECI_PHN_S30_DQ d
          LEFT JOIN lkp_area ar ON ar.NPA_ID = SUBSTR(d.std_phone, 1, 3)
    )
    SELECT c.*,
           xp.EXCEPTION_DESC                                                  AS phone_exception_desc,
           xe.EXCEPTION_CODE                                                  AS email_exception_code,
           xe.EXCEPTION_DESC                                                  AS email_exception_desc,
           xe.EXCEPTION_TYPE                                                  AS email_exception_type,
           (NOT c.is_email AND (c.phone_exception_code IS NULL
                                OR c.phone_exception_code = 'Missing_AreaCode')) AS grp_phone_good,
           (NOT c.is_email AND c.phone_exception_code IS NOT NULL)            AS grp_phone_bad,
           (c.is_email AND xe.EXCEPTION_CODE IS NULL)                          AS grp_email_good,
           (c.is_email AND xe.EXCEPTION_CODE IS NOT NULL)                      AS grp_email_bad
      FROM checked c
      LEFT JOIN lkp_exc xp ON xp.EXCEPTION_CODE = c.phone_exception_code
      LEFT JOIN lkp_exc xe ON xe.EXCEPTION_CODE = c.em:exception_code::VARCHAR;
    SELECT COUNT(*) INTO :l_rows FROM WRK_ECI_PHN_S40_ROUTED;
    RETURN :l_rows;
END;
$$;
