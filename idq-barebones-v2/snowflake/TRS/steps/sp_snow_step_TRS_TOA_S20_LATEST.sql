-- ============================================================================
-- sp_snow_step_TRS_TOA_S20_LATEST  --  BARE-BONES STEP (TRS)
--
-- Mapping: m_Tgt_C_S_TRS_Pty_Rle_TOA, workflow wf_TRS_Stage_Load_1_Ongoing.
-- Step name: TOA_LATEST. Produces: WRK_TRS_TOA_S20_SRC.
-- Consumes (v2.1 declared inputs): WRK_TRS_TOA_S10_RAW.
-- Original params used: none; plus P_RUN_TS (run timestamp).
--
-- The CTAS below is the v2.1 step SELECT verbatim. The only removals
-- were the work-table existence check and the step completion call.
-- No exception block (errors propagate to the driver handler), no
-- transactions, no target writes. Returns the row count.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_step_TRS_TOA_S20_LATEST (

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

    -- ---- Step 20: TOA_LATEST (verbatim from current main)
CREATE OR REPLACE TRANSIENT TABLE WRK_TRS_TOA_S20_SRC AS
    SELECT * FROM WRK_TRS_TOA_S10_RAW WHERE VERSION_SEQ = 1;
    SELECT COUNT(*) INTO :l_rows FROM WRK_TRS_TOA_S20_SRC;
    RETURN :l_rows;
END;$$;
