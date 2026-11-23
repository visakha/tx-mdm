-- ============================================================================
-- sp_snow_step_TRS_PTYDEACT_S30_READY  --  BARE-BONES STEP (TRS)
--
-- Mapping: m_Tgt_C_S_TRS_Pty_Deactivation_1, workflow wf_TRS_Stage_Load_1_Ongoing.
-- Step name: READY_TO_PUBLISH. Produces: WRK_TRS_DEACT1_S30_READY.
-- Consumes (v2.1 declared inputs): WRK_TRS_DEACT1_S20_DEACTV_ID.
-- Original params used: none; plus P_RUN_TS (run timestamp).
--
-- The CTAS below is the v2.1 step SELECT verbatim. The only removals
-- were the work-table existence check and the step completion call.
-- No exception block (errors propagate to the driver handler), no
-- transactions, no target writes. Returns the row count.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_step_TRS_PTYDEACT_S30_READY (

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

    -- ---- Step 30: READY_TO_PUBLISH (verbatim from current main)
CREATE OR REPLACE TRANSIENT TABLE WRK_TRS_DEACT1_S30_READY AS
    SELECT vm.INDV_ID AS INDV_ID, vm.PTY_PK AS PTY_PK, vm.SRC_TBL AS SRC_TBL,
           vm.CREATE_DATE AS CREATE_DATE, d.src_deactivation_date AS SRC_DEACTIVATION_DATE,
           :P_RUN_TS AS LOAD_DATE, d.inactive_ind AS INACTIVE_IND, d.delete_sw AS DELETE_SW,
           'N' AS PROCESSED_YN
      FROM STG_TRS_VALID_MEMBERS vm
      JOIN WRK_TRS_DEACT1_S20_DEACTV_ID d ON d.indv_id = vm.indv_id
      LEFT JOIN (SELECT DISTINCT PTY_PK FROM STG_TRS_DEACTIVED_MEMBERS WHERE PTY_PK IS NOT NULL) dm
             ON dm.PTY_PK = vm.PTY_PK
      LEFT JOIN (SELECT DISTINCT INDV_ID FROM STG_TRS_DEACTIVED_MEMBERS) di ON di.INDV_ID = vm.INDV_ID
     WHERE dm.PTY_PK IS NULL
       AND di.INDV_ID IS NULL
    QUALIFY ROW_NUMBER() OVER (PARTITION BY vm.INDV_ID ORDER BY vm.CREATE_DATE, vm.PTY_PK) = 1;
    SELECT COUNT(*) INTO :l_rows FROM WRK_TRS_DEACT1_S30_READY;
    RETURN :l_rows;
END;$$;
