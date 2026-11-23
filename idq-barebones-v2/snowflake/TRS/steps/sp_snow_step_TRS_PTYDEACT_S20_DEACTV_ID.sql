-- ============================================================================
-- sp_snow_step_TRS_PTYDEACT_S20_DEACTV_ID  --  BARE-BONES STEP (TRS)
--
-- Mapping: m_Tgt_C_S_TRS_Pty_Deactivation_1, workflow wf_TRS_Stage_Load_1_Ongoing.
-- Step name: DEACTIVATED_PER_INDIVIDUAL. Produces: WRK_TRS_DEACT1_S20_DEACTV_ID.
-- Consumes (v2.1 declared inputs): WRK_TRS_DEACT1_S10_DEACTV.
-- Original params used: none; plus P_RUN_TS (run timestamp).
--
-- The CTAS below is the v2.1 step SELECT verbatim. The only removals
-- were the work-table existence check and the step completion call.
-- No exception block (errors propagate to the driver handler), no
-- transactions, no target writes. Returns the row count.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_step_TRS_PTYDEACT_S20_DEACTV_ID (

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

    -- ---- Step 20: DEACTIVATED_PER_INDIVIDUAL (verbatim from current main)
CREATE OR REPLACE TRANSIENT TABLE WRK_TRS_DEACT1_S20_DEACTV_ID AS
    SELECT indv_id, MAX(inactive_ind) inactive_ind, MAX(delete_sw) delete_sw, MIN(create_dt) src_deactivation_date
      FROM WRK_TRS_DEACT1_S10_DEACTV
     GROUP BY indv_id;
    SELECT COUNT(*) INTO :l_rows FROM WRK_TRS_DEACT1_S20_DEACTV_ID;
    RETURN :l_rows;
END;$$;
