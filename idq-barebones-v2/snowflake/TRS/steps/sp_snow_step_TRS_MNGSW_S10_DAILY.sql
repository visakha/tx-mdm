-- ============================================================================
-- sp_snow_step_TRS_MNGSW_S10_DAILY  --  BARE-BONES STEP (TRS)
--
-- Mapping: m_Tgt_C_S_TRS_Pty_Mng_Attr_Sw, workflow wf_TRS_Stage_Load_1_Ongoing.
-- Step name: DAILY_INDV. Produces: WRK_TRS_MNGSW_S10_DAILY.
-- Consumes (v2.1 declared inputs): (base tables only).
-- Original params used: none; plus P_RUN_TS (run timestamp).
--
-- The CTAS below is the v2.1 step SELECT verbatim. The only removals
-- were the work-table existence check and the step completion call.
-- No exception block (errors propagate to the driver handler), no
-- transactions, no target writes. Returns the row count.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_step_TRS_MNGSW_S10_DAILY (

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

    -- ---- Step 10: DAILY_INDV (verbatim from current main)
CREATE OR REPLACE TRANSIENT TABLE WRK_TRS_MNGSW_S10_DAILY AS
    SELECT dc.indv_id AS INDV_ID, dc.FILE_CLEARANCE_SW, dc.SSA_VALIDATION_SW, dc.CREATE_DT AS EFF_BEGIN_DT,
           NULL AS TW_CONVERT_IND, NULL AS LTC_CONVERT_IND, TO_VARCHAR(dc.INDV_ID) || '|DC_INDV' AS PTY_PK,
           dc.create_dt AS CREATE_DT, 'DC_INDV' AS SRC_TBL,
           ROW_NUMBER() OVER (PARTITION BY dc.INDV_ID ORDER BY dc.CREATE_DT DESC) AS KEY_RN
      FROM STG_TRS_D_DC_INDV dc
    UNION
    SELECT cv.indv_id, NULL, NULL, cv.create_dt, cv.TW_CONVERT_IND, cv.LTC_CONVERT_IND, TO_VARCHAR(cv.INDV_ID),
           cv.create_dt, 'MCI', ROW_NUMBER() OVER (PARTITION BY cv.INDV_ID ORDER BY cv.CREATE_DT DESC)
      FROM STG_TRS_D_CV_DC_MCI_INDV cv;
    SELECT COUNT(*) INTO :l_rows FROM WRK_TRS_MNGSW_S10_DAILY;
    RETURN :l_rows;
END;$$;
