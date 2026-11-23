-- ============================================================================
-- sp_snow_step_TRS_AUTHREP_S10_PAYEE  --  BARE-BONES STEP (TRS)
--
-- Mapping: m_Tgt_C_S_TRS_Pty_Mng_Attr_Auth_Rep_Ongoing, workflow wf_TRS_Stage_Load_1_Ongoing.
-- Step name: PAYEE_CASE_ROWS. Produces: WRK_TRS_MNGAR_S10_PAYEE.
-- Consumes (v2.1 declared inputs): (base tables only).
-- Original params used: none; plus P_RUN_TS (run timestamp).
--
-- The CTAS below is the v2.1 step SELECT verbatim. The only removals
-- were the work-table existence check and the step completion call.
-- No exception block (errors propagate to the driver handler), no
-- transactions, no target writes. Returns the row count.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_step_TRS_AUTHREP_S10_PAYEE (

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

    -- ---- Step 10: PAYEE_CASE_ROWS (verbatim from current main)
CREATE OR REPLACE TRANSIENT TABLE WRK_TRS_MNGAR_S10_PAYEE AS
    SELECT ed.indv_id, 'Y' AS AR_FLAG, ed.elig_eff_begin_dt AS eff_begin_dt, ed.elig_eff_end_dt AS eff_end_dt,
           p.create_dt AS create_dt
      FROM STG_TRS_D_DC_PRIMARY_PAYEE p
      JOIN STG_TRS_CV_ED_MCI_EDG_INDV ed
        ON p.case_num = ed.case_num AND p.edg_num = ed.edg_num AND ed.elig_eff_end_dt IS NULL
      JOIN STG_TRS_DC_CASES c ON p.case_num = c.case_num
     WHERE (p.ADDR_TYPE_CD = 'MA' OR p.ADDR_TYPE_CD IS NULL) AND p.ALT_PAYEE_EXISTS_SW = 'Y'
       AND c.AUTHREP_VERF_CD IN ('CS', 'FH', 'LD', 'OA') AND c.SENT_AUTHREP_SW = 'Y'
    UNION ALL
    SELECT ed.indv_id, 'Y', ed.elig_eff_begin_dt, ed.elig_eff_end_dt, p.create_dt
      FROM STG_TRS_D_DC_CASES c
      JOIN STG_TRS_DC_PRIMARY_PAYEE p ON p.case_num = c.case_num
      JOIN STG_TRS_CV_ED_MCI_EDG_INDV ed
        ON p.case_num = ed.case_num AND p.edg_num = ed.edg_num AND ed.elig_eff_end_dt IS NULL
     WHERE (p.ADDR_TYPE_CD = 'MA' OR p.ADDR_TYPE_CD IS NULL) AND p.ALT_PAYEE_EXISTS_SW = 'Y'
       AND c.AUTHREP_VERF_CD IN ('CS', 'FH', 'LD', 'OA') AND c.SENT_AUTHREP_SW = 'Y'
    UNION ALL
    SELECT ed.indv_id, 'Y', ed.elig_eff_begin_dt, ed.elig_eff_end_dt, p.create_dt
      FROM STG_TRS_DC_CASES c
      JOIN STG_TRS_DC_PRIMARY_PAYEE p ON p.case_num = c.case_num
      JOIN STG_TRS_D_CV_ED_MCI_EDG_INDV ed
        ON p.case_num = ed.case_num AND p.edg_num = ed.edg_num AND ed.elig_eff_end_dt IS NULL
     WHERE (p.ADDR_TYPE_CD = 'MA' OR p.ADDR_TYPE_CD IS NULL) AND p.ALT_PAYEE_EXISTS_SW = 'Y'
       AND c.AUTHREP_VERF_CD IN ('CS', 'FH', 'LD', 'OA') AND c.SENT_AUTHREP_SW = 'Y'
    UNION ALL
    SELECT ci.indv_id, 'Y', ed.elig_eff_begin_dt, ed.elig_eff_end_dt, NVL(p.create_dt, ed.create_dt)
      FROM STG_TRS_D_CV_ED_MCI_EDG_INDV ed
      LEFT JOIN STG_TRS_DC_PRIMARY_PAYEE p
        ON ed.case_num = p.case_num AND ed.edg_num = p.edg_num AND ed.elig_eff_end_dt IS NULL
       AND (p.ADDR_TYPE_CD = 'MA' OR p.ADDR_TYPE_CD IS NULL) AND p.ALT_PAYEE_EXISTS_SW = 'Y'
       AND p.edg_num IS NULL
      JOIN STG_TRS_DC_CASES c ON ed.case_num = c.case_num
      JOIN STG_TRS_DC_CASE_INDV ci ON c.case_num = ci.case_num
     WHERE c.AUTHREP_VERF_CD IN ('CS', 'FH', 'LD', 'OA') AND c.SENT_AUTHREP_SW = 'Y'
    UNION ALL
    SELECT ci.indv_id, 'Y', ed.elig_eff_begin_dt, ed.elig_eff_end_dt, p.create_dt
      FROM STG_TRS_CV_ED_MCI_EDG_INDV ed
      JOIN STG_TRS_D_DC_PRIMARY_PAYEE p
        ON ed.case_num = ed.case_num AND ed.edg_num = ed.edg_num AND ed.elig_eff_end_dt IS NULL
       AND (p.ADDR_TYPE_CD = 'MA' OR p.ADDR_TYPE_CD IS NULL) AND p.ALT_PAYEE_EXISTS_SW = 'Y'
       AND p.edg_num IS NULL
      JOIN STG_TRS_DC_CASES c ON ed.case_num = c.case_num
      JOIN STG_TRS_DC_CASE_INDV ci ON c.case_num = ci.case_num
     WHERE c.AUTHREP_VERF_CD IN ('CS', 'FH', 'LD', 'OA') AND c.SENT_AUTHREP_SW = 'Y'
    UNION ALL
    SELECT ci.indv_id, 'Y', ed.elig_eff_begin_dt, ed.elig_eff_end_dt, NVL(p.create_dt, ed.create_dt)
      FROM STG_TRS_CV_ED_MCI_EDG_INDV ed
      LEFT JOIN STG_TRS_DC_PRIMARY_PAYEE p
        ON ed.case_num = p.case_num AND ed.edg_num = p.edg_num AND ed.elig_eff_end_dt IS NULL
       AND (p.ADDR_TYPE_CD = 'MA' OR p.ADDR_TYPE_CD IS NULL) AND p.ALT_PAYEE_EXISTS_SW = 'Y'
       AND p.edg_num IS NULL
      JOIN STG_TRS_DC_CASES c ON ed.case_num = c.case_num
      JOIN STG_TRS_DC_CASE_INDV ci ON c.case_num = ci.case_num
     WHERE c.AUTHREP_VERF_CD IN ('CS', 'FH', 'LD', 'OA') AND c.SENT_AUTHREP_SW = 'Y';
    SELECT COUNT(*) INTO :l_rows FROM WRK_TRS_MNGAR_S10_PAYEE;
    RETURN :l_rows;
END;$$;
