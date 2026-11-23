-- ============================================================================
-- sp_snow_step_TRS_ADDR1_S30_VALIDATED  --  BARE-BONES STEP (TRS)
--
-- Mapping: m_Tgt_C_S_TRS_Addr_1, workflow wf_TRS_Stage_Load_1_Ongoing.
-- Step name: ADDR_VALIDATION. Produces: WRK_TRS_ADDR1_S30_VALIDATED.
-- Consumes (v2.1 declared inputs): WRK_TRS_ADDR1_S20_DERIVED.
-- Original params used: none; plus P_RUN_TS (run timestamp).
--
-- The CTAS below is the v2.1 step SELECT verbatim. The only removals
-- were the work-table existence check and the step completion call.
-- No exception block (errors propagate to the driver handler), no
-- transactions, no target writes. Returns the row count.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_step_TRS_ADDR1_S30_VALIDATED (

    P_RUN_TS                 TIMESTAMP_NTZ DEFAULT NULL

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
CREATE OR REPLACE TRANSIENT TABLE WRK_TRS_ADDR1_S30_VALIDATED AS
    WITH
    lkp_cv AS (SELECT * FROM TABLE(fn_snow_helper41_common()))
    SELECT d.*,
           fn_snow_helper34_common(d.addr_line_1, d.addr_line_2, d.ADDR_CITY, d.ADDR_STATE_CD,
                                   NVL(TO_VARCHAR(d.ADDR_ZIP5), '') || '-' || NVL(TO_VARCHAR(d.ADDR_ZIP4), ''),
                                   'US', stc.MSTR_CODE_VALUE) AS av
      FROM WRK_TRS_ADDR1_S20_DERIVED d
      LEFT JOIN lkp_cv stc ON stc.CODE_TYPE = 'STATE' AND stc.SRC_SYS = 'TRS'
                          AND stc.SRC_CODE_VALUE = UPPER(TRIM(d.ADDR_STATE_CD));
    SELECT COUNT(*) INTO :l_rows FROM WRK_TRS_ADDR1_S30_VALIDATED;
    RETURN :l_rows;
END;$$;
