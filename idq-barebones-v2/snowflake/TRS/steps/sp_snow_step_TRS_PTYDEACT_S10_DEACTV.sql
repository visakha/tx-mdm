-- ============================================================================
-- sp_snow_step_TRS_PTYDEACT_S10_DEACTV  --  BARE-BONES STEP (TRS)
--
-- Mapping: m_Tgt_C_S_TRS_Pty_Deactivation_1, workflow wf_TRS_Stage_Load_1_Ongoing.
-- Step name: DEACTIVATED_INDIVIDUALS. Produces: WRK_TRS_DEACT1_S10_DEACTV.
-- Consumes (v2.1 declared inputs): (base tables only).
-- Original params used: none; plus P_RUN_TS (run timestamp).
--
-- The CTAS below is the v2.1 step SELECT verbatim. The only removals
-- were the work-table existence check and the step completion call.
-- No exception block (errors propagate to the driver handler), no
-- transactions, no target writes. Returns the row count.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_step_TRS_PTYDEACT_S10_DEACTV (

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

    -- ---- Step 10: DEACTIVATED_INDIVIDUALS (verbatim from current main)
CREATE OR REPLACE TRANSIENT TABLE WRK_TRS_DEACT1_S10_DEACTV AS
    SELECT indv_id, inactive_ind, delete_sw, create_dt
      FROM STG_TRS_D_DC_INDV
     WHERE inactive_ind = 'Y' OR delete_sw = 'Y'
    UNION ALL
    SELECT indv_id, inactive_ind, NULL, create_dt
      FROM STG_TRS_D_CV_DC_MCI_INDV
     WHERE inactive_ind = 'Y';
    SELECT COUNT(*) INTO :l_rows FROM WRK_TRS_DEACT1_S10_DEACTV;
    RETURN :l_rows;
END;$$;
