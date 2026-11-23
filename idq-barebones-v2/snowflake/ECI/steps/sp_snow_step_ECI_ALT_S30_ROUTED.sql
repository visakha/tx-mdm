-- sp_snow_step_ECI_ALT_S30_ROUTED -- BARE-BONES variant (ECI)
-- Mapping: m_Tgt_C_S_ECI_Pty_Rle_Alt_Id, workflow wf_ECI_Stage_Load, step 30 (VALIDATED_ROUTED).
-- Produces: WRK_ECI_ALT_S30_ROUTED.
-- Runs unconditionally from the driver; no gating, no checkpointing.
-- Business SQL below is verbatim from the v2.1 step procedure.
CREATE OR REPLACE PROCEDURE sp_snow_step_ECI_ALT_S30_ROUTED (
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
    -- ---- Step 30: VALIDATION + ROUTING (verbatim from current main)
    -- Purpose: validate SSNs and Medicaid ids and sort rows into the
    -- valid group, the SSN-exception group and the Medicaid-exception
    -- group, with exception descriptions resolved. Reads ONLY step 20.
    -- This is the original dq + routed CTEs.
    CREATE OR REPLACE TRANSIENT TABLE WRK_ECI_ALT_S30_ROUTED AS
    WITH
    lkp_exc AS (SELECT * FROM TABLE(fn_snow_helper40_common())),
    dq AS (
        SELECT a.*,
               IFF(a.ALT_ID_TP = '004' AND fn_snow_helper26_common(a.ALT_ID_VAL):ssn_status::VARCHAR = 'Invalid',
                   'Invalid_SSN', NULL)                                                    AS ssn_exception_code,
               IFF(a.ALT_ID_TP = '002', fn_snow_helper27_common(a.ALT_ID_VAL):exception_code::VARCHAR, NULL)
                                                                                           AS medicaid_exception_code
          FROM WRK_ECI_ALT_S20_ACTIVE a
    )
    SELECT d.*,
           xs.EXCEPTION_CODE AS ssn_lkp_code, xs.EXCEPTION_DESC AS ssn_lkp_desc, xs.EXCEPTION_TYPE AS ssn_lkp_type,
           xm.EXCEPTION_TYPE AS medicaid_exception_type, xm.EXCEPTION_DESC AS medicaid_exception_desc,
           ((d.ALT_ID_TP = '004' AND d.ssn_exception_code IS NULL)
            OR d.ALT_ID_TP IN ('018', '019')
            OR (d.ALT_ID_TP = '002' AND d.medicaid_exception_code IS NULL))          AS grp_valid,
           (d.ALT_ID_TP = '004' AND d.ssn_exception_code IS NOT NULL)                 AS grp_ssn_exc,
           (d.ALT_ID_TP = '002' AND d.medicaid_exception_code IS NOT NULL)            AS grp_mcd_exc
      FROM dq d
      LEFT JOIN lkp_exc xs ON xs.EXCEPTION_CODE = d.ssn_exception_code
      LEFT JOIN lkp_exc xm ON xm.EXCEPTION_CODE = d.medicaid_exception_code;
    SELECT COUNT(*) INTO :l_rows FROM WRK_ECI_ALT_S30_ROUTED;
    RETURN :l_rows;
END;
$$;
