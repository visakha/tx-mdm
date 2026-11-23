-- ============================================================================
-- sp_snow_step_TRS_MNGSW_S30_NORM  --  BARE-BONES STEP (TRS)
--
-- Mapping: m_Tgt_C_S_TRS_Pty_Mng_Attr_Sw, workflow wf_TRS_Stage_Load_1_Ongoing.
-- Step name: UNPIVOT_SWITCHES. Produces: WRK_TRS_MNGSW_S30_NORM.
-- Consumes (v2.1 declared inputs): WRK_TRS_MNGSW_S20_SRC.
-- Original params used: none; plus P_RUN_TS (run timestamp).
--
-- The CTAS below is the v2.1 step SELECT verbatim. The only removals
-- were the work-table existence check and the step completion call.
-- No exception block (errors propagate to the driver handler), no
-- transactions, no target writes. Returns the row count.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_step_TRS_MNGSW_S30_NORM (

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

    -- ---- Step 30: UNPIVOT_SWITCHES (verbatim from current main)
CREATE OR REPLACE TRANSIENT TABLE WRK_TRS_MNGSW_S30_NORM AS
    SELECT s.PTY_PK, s.EFF_BEGIN_DT, s.CREATE_DT AS SRC_LAST_UPD_DT, 'File_Clearance_SW' AS ATTR_TYPE,
           TO_VARCHAR(s.FILE_CLEARANCE_SW) AS ATTR_VALUE FROM WRK_TRS_MNGSW_S20_SRC s
    UNION ALL
    SELECT s.PTY_PK, s.EFF_BEGIN_DT, s.CREATE_DT, 'SSA_Validation_SW', TO_VARCHAR(s.SSA_VALIDATION_SW) FROM WRK_TRS_MNGSW_S20_SRC s
    UNION ALL
    SELECT s.PTY_PK, s.EFF_BEGIN_DT, s.CREATE_DT, 'TW_Convert_Ind', TO_VARCHAR(s.TW_CONVERT_IND) FROM WRK_TRS_MNGSW_S20_SRC s
    UNION ALL
    SELECT s.PTY_PK, s.EFF_BEGIN_DT, s.CREATE_DT, 'LTC_Convert_Ind', TO_VARCHAR(s.LTC_CONVERT_IND) FROM WRK_TRS_MNGSW_S20_SRC s
    UNION ALL
    SELECT s.PTY_PK, s.EFF_BEGIN_DT, s.CREATE_DT, 'Source_Table', TO_VARCHAR(s.SRC_TBL) FROM WRK_TRS_MNGSW_S20_SRC s;
    SELECT COUNT(*) INTO :l_rows FROM WRK_TRS_MNGSW_S30_NORM;
    RETURN :l_rows;
END;$$;
