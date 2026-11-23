-- ============================================================================
-- sp_snow_step_TRS_PTY_S10_SRC  --  BARE-BONES STEP (TRS)
--
-- Mapping: m_Tgt_C_S_TRS_Pty_OnGoing, workflow wf_TRS_Stage_Load_1_Ongoing.
-- Step name: SRC_VALID_LIST. Produces: WRK_TRS_PTY_S1_SRC.
-- Consumes (v2.1 declared inputs): (base tables only).
-- Original params used: P_DC_INDV_TBL_SRC, P_MCI_TBL_SRC; plus P_RUN_TS (run timestamp).
--
-- The CTAS below is the v2.1 step SELECT verbatim. The only removals
-- were the work-table existence check and the step completion call.
-- No exception block (errors propagate to the driver handler), no
-- transactions, no target writes. Returns the row count.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_step_TRS_PTY_S10_SRC (

    P_DC_INDV_TBL_SRC VARCHAR DEFAULT 'DC_INDV',
    P_MCI_TBL_SRC VARCHAR DEFAULT 'MCI',
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

    -- ---- Step 10: SRC_VALID_LIST (verbatim from current main)
CREATE OR REPLACE TRANSIENT TABLE WRK_TRS_PTY_S1_SRC AS
    WITH
    new_valid_indvs AS (
        SELECT DISTINCT indv_id FROM STG_TRS_D_CV_MCI_EDG_INDV_TOA WHERE conversion_ind = 'C'
        UNION
        SELECT DISTINCT indv_id FROM STG_TRS_D_DC_INDV
         WHERE FILE_CLEARANCE_SW = 'Y' AND Inactive_ind = 'N' AND delete_sw = 'N'
        UNION
        SELECT DISTINCT indv_id FROM STG_TRS_D_CV_DC_MCI_INDV WHERE Inactive_ind = 'N'
        UNION
        SELECT DISTINCT indv_id FROM STG_TRS_VALID_MEMBERS
        MINUS
        SELECT DISTINCT indv_id FROM STG_TRS_D_DC_INDV WHERE Inactive_ind = 'Y' OR delete_sw = 'Y'
        MINUS
        SELECT DISTINCT indv_id FROM STG_TRS_D_CV_DC_MCI_INDV WHERE Inactive_ind = 'Y'
        MINUS
        SELECT indv_id FROM STG_TRS_DEACTIVED_MEMBERS
    ),
    all_indv AS (
        SELECT INDV_ID, FIRST_NAME, MID_NAME, LAST_NAME, SUFX_NAME, PREFIX_NAME, GENDER_CD, RACE_CD, ETHNICITY_CD,
               NULL AS SSA_VAL_SW, NULL AS FILE_CL_SW, DOB_DT, NULL AS DEATH_DT, CREATE_DT,
               :P_MCI_TBL_SRC AS SRC_TBL
          FROM STG_TRS_D_CV_DC_MCI_INDV
        UNION ALL
        SELECT INDV_ID, FIRST_NAME, MID_NAME, LAST_NAME, SUFX_NAME, PREFIX_NAME, GENDER_CD, RACE_CD, ETHNICITY_CD,
               SSA_VALIDATION_SW, FILE_CLEARANCE_SW, DOB_DT, DEATH_DT, CREATE_DT, :P_DC_INDV_TBL_SRC
          FROM STG_TRS_D_DC_INDV
    )
    SELECT DISTINCT a.INDV_ID, RTRIM(LTRIM(a.FIRST_NAME)) AS FIRST_NAME, RTRIM(LTRIM(a.MID_NAME)) AS MID_NAME,
           RTRIM(LTRIM(a.LAST_NAME)) AS LAST_NAME, RTRIM(a.SUFX_NAME) AS SUFX_NAME,
           RTRIM(a.PREFIX_NAME) AS PREFIX_NAME, a.GENDER_CD, a.RACE_CD, a.ETHNICITY_CD, a.SSA_VAL_SW,
           a.FILE_CL_SW, a.DOB_DT, a.CREATE_DT, a.SRC_TBL, a.DEATH_DT
      FROM all_indv a
     INNER JOIN new_valid_indvs f ON f.indv_id = a.indv_id;
    SELECT COUNT(*) INTO :l_rows FROM WRK_TRS_PTY_S1_SRC;
    RETURN :l_rows;
END;$$;
