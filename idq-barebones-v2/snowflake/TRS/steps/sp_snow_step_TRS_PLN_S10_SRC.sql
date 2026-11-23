-- ============================================================================
-- sp_snow_step_TRS_PLN_S10_SRC  --  BARE-BONES STEP (TRS)
--
-- Mapping: m_Tgt_C_S_TRS_Pty_Rle_Pln, workflow wf_TRS_Stage_Load_1_Ongoing.
-- Step name: MANAGED_CARE_SRC. Produces: WRK_TRS_PLN_S10_SRC.
-- Consumes (v2.1 declared inputs): (base tables only).
-- Original params used: none; plus P_RUN_TS (run timestamp).
--
-- The CTAS below is the v2.1 step SELECT verbatim. The only removals
-- were the work-table existence check and the step completion call.
-- No exception block (errors propagate to the driver handler), no
-- transactions, no target writes. Returns the row count.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_step_TRS_PLN_S10_SRC (

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

    -- ---- Step 10: MANAGED_CARE_SRC (verbatim from current main)
CREATE OR REPLACE TRANSIENT TABLE WRK_TRS_PLN_S10_SRC AS
    SELECT DISTINCT M.INDV_ID AS INDV_ID, M.BEGIN_DT, M.MC_PLAN, M.HISTORY_SEQ, M.END_DT, M.CREATE_DT
      FROM STG_TRS_D_IN_MANAGED_CARE M
      JOIN STG_TRS_VALID_MEMBERS VM ON M.INDV_ID = VM.INDV_ID AND VM.SRC_TBL = 'MCI'
     WHERE M.MC_PLAN IS NOT NULL
       AND (M.BEGIN_DT < M.END_DT OR M.END_DT IS NULL);
    SELECT COUNT(*) INTO :l_rows FROM WRK_TRS_PLN_S10_SRC;
    RETURN :l_rows;
END;$$;
