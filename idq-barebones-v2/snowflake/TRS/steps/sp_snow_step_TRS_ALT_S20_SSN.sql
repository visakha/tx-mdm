-- ============================================================================
-- sp_snow_step_TRS_ALT_S20_SSN  --  BARE-BONES STEP (TRS)
--
-- Mapping: m_Tgt_C_S_TRS_Pty_Rle_Alt_Id, workflow wf_TRS_Stage_Load_1_Ongoing.
-- Step name: SSN_VALIDATED. Produces: WRK_TRS_ALT_S2_SSN.
-- Consumes (v2.1 declared inputs): WRK_TRS_ALT_S1_SRC.
-- Original params used: none; plus P_RUN_TS (run timestamp).
--
-- The CTAS below is the v2.1 step SELECT verbatim. The only removals
-- were the work-table existence check and the step completion call.
-- No exception block (errors propagate to the driver handler), no
-- transactions, no target writes. Returns the row count.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_step_TRS_ALT_S20_SSN (

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

    -- ---- Step 20: SSN_VALIDATED (verbatim from current main)
CREATE OR REPLACE TRANSIENT TABLE WRK_TRS_ALT_S2_SSN AS
    SELECT s.*, v.SSN AS valid_ssn
      FROM WRK_TRS_ALT_S1_SRC s
      LEFT JOIN (SELECT DISTINCT INDV_ID, SSN FROM STG_TRS_H_DC_INDV
                  WHERE SSA_VALIDATION_SW = 'Y' AND SSN > 0) v
             ON v.INDV_ID = fn_snow_helper04_common(s.MEMBER_ID, 0) AND v.SSN = s.SSN
    QUALIFY ROW_NUMBER() OVER (PARTITION BY s.PTY_PKEY ORDER BY v.SSN) = 1;
    SELECT COUNT(*) INTO :l_rows FROM WRK_TRS_ALT_S2_SSN;
    RETURN :l_rows;
END;$$;
