-- ============================================================================
-- sp_snow_step_TRS_PHN_S10_SRC  --  BARE-BONES STEP (TRS)
--
-- Mapping: m_Tgt_C_S_TRS_Pty_Rle_Phn_And_EAddr, workflow wf_TRS_Stage_Load_1_Ongoing.
-- Step name: SRC_CASE_DELTA. Produces: WRK_TRS_PHN_S1_SRC.
-- Consumes (v2.1 declared inputs): (base tables only).
-- Original params used: none; plus P_RUN_TS (run timestamp).
--
-- The CTAS below is the v2.1 step SELECT verbatim. The only removals
-- were the work-table existence check and the step completion call.
-- No exception block (errors propagate to the driver handler), no
-- transactions, no target writes. Returns the row count.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_step_TRS_PHN_S10_SRC (

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

    -- ---- Step 10: SRC_CASE_DELTA (verbatim from current main)
CREATE OR REPLACE TRANSIENT TABLE WRK_TRS_PHN_S1_SRC AS
    SELECT DISTINCT I.INDV_ID, C.CASE_NUM, C.CREATE_DT, C.WORK_PH_NUM, C.OTHER_PH_NUM, C.EMAIL, C.PH_NUM,
           C.OFFICE_NUM, C.WORK_PH_NUM_EXT, TO_VARCHAR(I.INDV_ID) AS PTY_PK
      FROM STG_TRS_D_DC_CASES C
      JOIN STG_TRS_DC_CASE_INDV I ON C.CASE_NUM = I.CASE_NUM
      JOIN STG_TRS_VALID_MEMBERS VM ON TO_VARCHAR(I.INDV_ID) = VM.PTY_PK;
    SELECT COUNT(*) INTO :l_rows FROM WRK_TRS_PHN_S1_SRC;
    RETURN :l_rows;
END;$$;
