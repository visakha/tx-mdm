-- ============================================================================
-- sp_snow_pub_TRS_AUTHREP_C_S_TRS_PTY_MNG_ATTR.sql -- PUBLISH_DEST S10-only twin (C_S_* spine, first step only)
--
-- Twin of publish/sp_snow_pub_TRS_AUTHREP_C_S_TRS_PTY_MNG_ATTR.sql. Same procedure, same target, same column list
-- -- but ONLY the first (source) step is inlined as a CTE (s10_payee);
-- every later step (ACTIVE / DQ / ROUTED / READY / ranked / router)
-- and the WHERE gate are dropped. Each target column is aliased
-- from a first-step column, a literal, or a parameter (see map).
-- A column the first step does not carry is NULL (see map).
-- WHERE gate dropped: WHERE VERSION_SEQ = 1) xa ON xa.PKEY_SRC_OBJECT = g.pkey_src_object WHERE g.rn = 1 AND xa.PKEY_SRC_OBJECT IS NULL
-- P_RUN_TS: YES
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_pub_TRS_AUTHREP_C_S_TRS_PTY_MNG_ATTR (

    P_ATTR_TP_AUTH_REP VARCHAR DEFAULT 'Auth_Rep_Flag',
    P_RUN_TS       TIMESTAMP_NTZ DEFAULT NULL

)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
INSERT INTO C_S_TRS_PTY_MNG_ATTR
           (CREATE_DATE, LAST_UPDATE_DATE, MNG_ATTR_TP, PTY_FK, PERIOD_END_DATE, PERIOD_START_DATE, VERSION_SEQ,
            SRC_ROWID, PKEY_SRC_OBJECT, SRC_LAST_UPD_DT, MNG_ATTR_VAL)
    WITH
    s10_payee AS (
SELECT ed.indv_id,
        ' ' AS AR_FLAG,
        ed.elig_eff_begin_dt AS eff_begin_dt,
        ed.elig_eff_end_dt AS eff_end_dt,
        p.create_dt AS create_dt
          FROM STG_TRS_D_DC_PRIMARY_PAYEE p
          JOIN STG_TRS_CV_ED_MCI_EDG_INDV ed
            ON p.case_num = ed.case_num AND p.edg_num = ed.edg_num AND ed.elig_eff_end_dt IS NULL
          JOIN STG_TRS_DC_CASES c ON p.case_num = c.case_num
         WHERE (p.ADDR_TYPE_CD = 'MA' OR p.ADDR_TYPE_CD IS NULL) AND p.ALT_PAYEE_EXISTS_SW = 'Y'
           AND c.AUTHREP_VERF_CD IN ('CS', 'FH', 'LD', 'OA') AND c.SENT_AUTHREP_SW = 'Y'
        UNION ALL
        SELECT ed.indv_id,
        ' ',
        ed.elig_eff_begin_dt,
        ed.elig_eff_end_dt,
        p.create_dt
          FROM STG_TRS_D_DC_CASES c
          JOIN STG_TRS_DC_PRIMARY_PAYEE p ON p.case_num = c.case_num
          JOIN STG_TRS_CV_ED_MCI_EDG_INDV ed
            ON p.case_num = ed.case_num AND p.edg_num = ed.edg_num AND ed.elig_eff_end_dt IS NULL
         WHERE (p.ADDR_TYPE_CD = 'MA' OR p.ADDR_TYPE_CD IS NULL) AND p.ALT_PAYEE_EXISTS_SW = 'Y'
           AND c.AUTHREP_VERF_CD IN ('CS', 'FH', 'LD', 'OA') AND c.SENT_AUTHREP_SW = 'Y'
        UNION ALL
        SELECT ed.indv_id,
        ' ',
        ed.elig_eff_begin_dt,
        ed.elig_eff_end_dt,
        p.create_dt
          FROM STG_TRS_DC_CASES c
          JOIN STG_TRS_DC_PRIMARY_PAYEE p ON p.case_num = c.case_num
          JOIN STG_TRS_D_CV_ED_MCI_EDG_INDV ed
            ON p.case_num = ed.case_num AND p.edg_num = ed.edg_num AND ed.elig_eff_end_dt IS NULL
         WHERE (p.ADDR_TYPE_CD = 'MA' OR p.ADDR_TYPE_CD IS NULL) AND p.ALT_PAYEE_EXISTS_SW = 'Y'
           AND c.AUTHREP_VERF_CD IN ('CS', 'FH', 'LD', 'OA') AND c.SENT_AUTHREP_SW = 'Y'
        UNION ALL
        SELECT ci.indv_id,
        ' ',
        ed.elig_eff_begin_dt,
        ed.elig_eff_end_dt,
        NVL(p.create_dt, ed.create_dt)
          FROM STG_TRS_D_CV_ED_MCI_EDG_INDV ed
          LEFT JOIN STG_TRS_DC_PRIMARY_PAYEE p
            ON ed.case_num = p.case_num AND ed.edg_num = p.edg_num AND ed.elig_eff_end_dt IS NULL
           AND (p.ADDR_TYPE_CD = 'MA' OR p.ADDR_TYPE_CD IS NULL) AND p.ALT_PAYEE_EXISTS_SW = 'Y'
           AND p.edg_num IS NULL
          JOIN STG_TRS_DC_CASES c ON ed.case_num = c.case_num
          JOIN STG_TRS_DC_CASE_INDV ci ON c.case_num = ci.case_num
         WHERE c.AUTHREP_VERF_CD IN ('CS', 'FH', 'LD', 'OA') AND c.SENT_AUTHREP_SW = 'Y'
        UNION ALL
        SELECT ci.indv_id,
        ' ',
        ed.elig_eff_begin_dt,
        ed.elig_eff_end_dt,
        p.create_dt
          FROM STG_TRS_CV_ED_MCI_EDG_INDV ed
          JOIN STG_TRS_D_DC_PRIMARY_PAYEE p
            ON ed.case_num = ed.case_num AND ed.edg_num = ed.edg_num AND ed.elig_eff_end_dt IS NULL
           AND (p.ADDR_TYPE_CD = 'MA' OR p.ADDR_TYPE_CD IS NULL) AND p.ALT_PAYEE_EXISTS_SW = 'Y'
           AND p.edg_num IS NULL
          JOIN STG_TRS_DC_CASES c ON ed.case_num = c.case_num
          JOIN STG_TRS_DC_CASE_INDV ci ON c.case_num = ci.case_num
         WHERE c.AUTHREP_VERF_CD IN ('CS', 'FH', 'LD', 'OA') AND c.SENT_AUTHREP_SW = 'Y'
        UNION ALL
        SELECT ci.indv_id,
        ' ',
        ed.elig_eff_begin_dt,
        ed.elig_eff_end_dt,
        NVL(p.create_dt, ed.create_dt)
          FROM STG_TRS_CV_ED_MCI_EDG_INDV ed
          LEFT JOIN STG_TRS_DC_PRIMARY_PAYEE p
            ON ed.case_num = p.case_num AND ed.edg_num = p.edg_num AND ed.elig_eff_end_dt IS NULL
           AND (p.ADDR_TYPE_CD = 'MA' OR p.ADDR_TYPE_CD IS NULL) AND p.ALT_PAYEE_EXISTS_SW = 'Y'
           AND p.edg_num IS NULL
          JOIN STG_TRS_DC_CASES c ON ed.case_num = c.case_num
          JOIN STG_TRS_DC_CASE_INDV ci ON c.case_num = ci.case_num
         WHERE c.AUTHREP_VERF_CD IN ('CS', 'FH', 'LD', 'OA') AND c.SENT_AUTHREP_SW = 'Y'
    )
    SELECT CREATE_DT AS CREATE_DATE,
           :P_RUN_TS AS LAST_UPDATE_DATE,
           :P_ATTR_TP_AUTH_REP AS MNG_ATTR_TP,
           TO_VARCHAR(INDV_ID) AS PTY_FK,
           MAX(EFF_END_DT) OVER (PARTITION BY (TO_VARCHAR(INDV_ID) || ' ' || :P_ATTR_TP_AUTH_REP)) AS PERIOD_END_DATE,
           EFF_BEGIN_DT AS PERIOD_START_DATE,
           1 AS VERSION_SEQ,
           TO_VARCHAR(INDV_ID) || ' ' || :P_ATTR_TP_AUTH_REP AS SRC_ROWID,
           TO_VARCHAR(INDV_ID) || ' ' || :P_ATTR_TP_AUTH_REP AS PKEY_SRC_OBJECT,
           CREATE_DT AS SRC_LAST_UPD_DT,
           AR_FLAG AS MNG_ATTR_VAL
      FROM s10_payee;
    RETURN SQLROWCOUNT;
END;
$$;
