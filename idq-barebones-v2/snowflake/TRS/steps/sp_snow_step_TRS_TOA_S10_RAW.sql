-- ============================================================================
-- sp_snow_step_TRS_TOA_S10_RAW  --  BARE-BONES STEP (TRS)
--
-- Mapping: m_Tgt_C_S_TRS_Pty_Rle_TOA, workflow wf_TRS_Stage_Load_1_Ongoing.
-- Step name: TOA_SRC_RANKED. Produces: WRK_TRS_TOA_S10_RAW.
-- Consumes (v2.1 declared inputs): (base tables only).
-- Original params used: none; plus P_RUN_TS (run timestamp).
--
-- The CTAS below is the v2.1 step SELECT verbatim. The only removals
-- were the work-table existence check and the step completion call.
-- No exception block (errors propagate to the driver handler), no
-- transactions, no target writes. Returns the row count.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_step_TRS_TOA_S10_RAW (

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

    -- ---- Step 10: TOA_SRC_RANKED (verbatim from current main)
CREATE OR REPLACE TRANSIENT TABLE WRK_TRS_TOA_S10_RAW AS
    SELECT TO_VARCHAR(toa.INDV_ID) AS INDV_ID, toa.TYPE_OF_ASSISTANCE_CD, toa.ELIG_EFF_BEGIN_DT AS BEGIN_DT,
           toa.ELIG_EFF_END_DT AS END_DT, 'MCI_EDG_INDV' AS SRC_TBL,
           ROW_NUMBER() OVER (PARTITION BY TO_VARCHAR(toa.INDV_ID) || '|' || NVL(TO_VARCHAR(toa.EDG_NUM), '')
                                           || '|' || NVL(TO_VARCHAR(toa.PROGRAM_CD), '') || '|'
                                           || NVL(TO_VARCHAR(toa.MCI_CREATE_SEQ), '')
                              ORDER BY toa.CREATE_DT DESC) AS VERSION_SEQ,
           TO_VARCHAR(toa.INDV_ID) AS PTY_PK, toa.EDG_NUM, toa.CASE_NUM, toa.MCI_CREATE_SEQ, toa.PROGRAM_CD,
           toa.PART_STATUS_CD, toa.SYSTEM_CD, toa.CONVERT_DT, toa.CREATE_DT
      FROM STG_TRS_D_CV_MCI_EDG_INDV_TOA toa
      JOIN STG_TRS_VALID_MEMBERS vm ON TO_VARCHAR(toa.INDV_ID) = vm.PTY_PK
     WHERE toa.TYPE_OF_ASSISTANCE_CD IS NOT NULL
       AND (toa.CONVERSION_IND IS NULL OR toa.CONVERSION_IND = 'C');
    SELECT COUNT(*) INTO :l_rows FROM WRK_TRS_TOA_S10_RAW;
    RETURN :l_rows;
END;$$;
