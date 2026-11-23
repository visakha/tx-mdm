-- ============================================================================
-- sp_snow_step_TRS_NM_S20_NAMED  --  BARE-BONES STEP (TRS)
--
-- Mapping: m_Tgt_C_S_TRS_Pty_Nm, workflow wf_TRS_Stage_Load_1_Ongoing.
-- Step name: NAMED_FILTERED. Produces: WRK_TRS_NM_S20_NAMED.
-- Consumes (v2.1 declared inputs): WRK_TRS_NM_S10_SRC.
-- Original params used: none; plus P_RUN_TS (run timestamp).
--
-- The CTAS below is the v2.1 step SELECT verbatim. The only removals
-- were the work-table existence check and the step completion call.
-- No exception block (errors propagate to the driver handler), no
-- transactions, no target writes. Returns the row count.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_step_TRS_NM_S20_NAMED (

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

    -- ---- Step 20: NAMED_FILTERED (verbatim from current main)
CREATE OR REPLACE TRANSIENT TABLE WRK_TRS_NM_S20_NAMED AS
    SELECT s.*,
           TRIM(NVL(s.FIRST_NAME, '') || IFF(s.MID_NAME IS NOT NULL, ' ' || TRIM(s.MID_NAME), '')
                || ' ' || NVL(LTRIM(s.LAST_NAME), '')) AS src_full_name,
           fn_snow_helper14_common(s.FIRST_NAME, s.MID_NAME, s.LAST_NAME, NULL) AS tn
      FROM WRK_TRS_NM_S10_SRC s
     WHERE s.FIRST_NAME IS NOT NULL AND s.LAST_NAME IS NOT NULL;
    SELECT COUNT(*) INTO :l_rows FROM WRK_TRS_NM_S20_NAMED;
    RETURN :l_rows;
END;$$;
