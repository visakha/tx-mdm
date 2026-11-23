-- ============================================================================
-- sp_snow_pub_CRE_CARE_C_S_CRE_PTY.sql -- PUBLISH_DEST S10-only twin (C_S_* spine, first step only)
--
-- Twin of publish/sp_snow_pub_CRE_CARE_C_S_CRE_PTY.sql. Same procedure, same target, same column list
-- -- but ONLY the first (source) step is inlined as a CTE (s1_src_mrg);
-- every later step (ACTIVE / DQ / ROUTED / READY / ranked / router)
-- and the WHERE gate are dropped. Each target column is aliased
-- from a first-step column, a literal, or a parameter (see map).
-- A column the first step does not carry is NULL (see map).
-- WHERE gate dropped: WHERE is_member AND uq_pty
-- P_RUN_TS: YES
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_pub_CRE_CARE_C_S_CRE_PTY (
    P_RUN_TS TIMESTAMP_NTZ
)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
    INSERT INTO C_S_CRE_PTY
           (PKEY_SRC_OBJECT, PERIOD_START_DATE, PERIOD_END_DATE, VERSION_SEQ, PERIOD_REFERENCE_TIME,
            TIMELINE_ACTION, LAST_UPDATE_DATE, CREATE_DATE, SRC_ROWID, BIRTH_DT, FULL_NM, GNDR_CD, SFX_NM,
            LST_NM, FRST_NM, PTY_BO_CLASS_CD, SRC_FULL_NM, SRC_LAST_UPD_DT, ETHNCTY, RACE_CD, SRC_ETHNCTY,
            SRC_RACE_CD)
    WITH
    s1_src_mrg AS (
WITH
    -- Read_Stg_CRE_D_CARE_Clients (custom SQL; the parallel hint and commented test filters left out)
    src AS (
        SELECT DISTINCT CLIENTS.CARE_ID, CLIENTS.CARE_LASTUP_DT, CLIENTS.FIRSTNM, CLIENTS.LASTNM, CLIENTS.LAST_SUF,
               CLIENTS.BIRTH_DT, CLIENTS.SEX, CLIENTS.STREET, CLIENTS.CITY, CLIENTS.CNTY, CLIENTS.STATE,
               CLIENTS.ZIP, CLIENTS.ZIPSUF, CLIENTS.PHONE, CLIENTS.RECIP_NO, CLIENTS.MAINT_FLAG, CLIENTS.SSN,
               CLIENTS.INSERT_DATE, CLIENTS.FEDETH, CLIENTS.RACE, CAST(NULL AS VARCHAR) AS SOURCE_ID,
               CAST(NULL AS VARCHAR) AS TARGET_ID, CAST(NULL AS VARCHAR) AS REC, 'I' AS REC_TYPE
          FROM STG_CRE_D_CARE_CLIENTS CLIENTS
         WHERE CLIENTS.MAINT_FLAG IS NULL
        UNION ALL
        SELECT DISTINCT CLIENTS.CARE_ID, CLIENTS.CARE_LASTUP_DT, CLIENTS.FIRSTNM, CLIENTS.LASTNM, CLIENTS.LAST_SUF,
               CLIENTS.BIRTH_DT, CLIENTS.SEX, CLIENTS.STREET, CLIENTS.CITY, CLIENTS.CNTY, CLIENTS.STATE,
               CLIENTS.ZIP, CLIENTS.ZIPSUF, CLIENTS.PHONE, CLIENTS.RECIP_NO, DELTAS.MAINT_FLAG, CLIENTS.SSN,
               CLIENTS.INSERT_DATE, CLIENTS.FEDETH, CLIENTS.RACE, MAINT.SOURCE_ID, MAINT.TARGET_ID, MAINT.REC,
               DECODE(MAINT.REC, 'CASEMOV', 'B', 'D')
          FROM STG_CRE_D_CARE_CLIENTS DELTAS
          LEFT JOIN STG_CRE_SN_CARE_CLIENTS CLIENTS
            ON DELTAS.CARE_ID = CLIENTS.CARE_ID
          JOIN STG_CRE_D_CARE_CASE_MAINT MAINT
            ON CLIENTS.CARE_ID = MAINT.SOURCE_ID
           AND DELTAS.MAINT_FLAG = 'D'
           AND MAINT.REC IN ('CASEMOV', 'CASEDEL')
        UNION ALL
        SELECT DISTINCT CLIENTS.CARE_ID, CLIENTS.CARE_LASTUP_DT, CLIENTS.FIRSTNM, CLIENTS.LASTNM, CLIENTS.LAST_SUF,
               CLIENTS.BIRTH_DT, CLIENTS.SEX, CLIENTS.STREET, CLIENTS.CITY, CLIENTS.CNTY, CLIENTS.STATE,
               CLIENTS.ZIP, CLIENTS.ZIPSUF, CLIENTS.PHONE, CLIENTS.RECIP_NO, CLIENTS.MAINT_FLAG, CLIENTS.SSN,
               CLIENTS.INSERT_DATE, CLIENTS.FEDETH, CLIENTS.RACE, MAINT.SOURCE_ID, MAINT.TARGET_ID, MAINT.REC,
               'A' AS REC_TYPE
          FROM STG_CRE_SN_CARE_CLIENTS CLIENTS
          JOIN STG_CRE_D_CARE_CASE_MAINT MAINT
            ON CLIENTS.CARE_ID = MAINT.TARGET_ID
           AND MAINT.REC = 'CASEMOV'
    ),
    -- LKP_XREF_SRC / LKP_XREF_TGT: CHAR columns are not compared blank-padded in Snowflake, hence the trims
    xref AS (
        SELECT x.PKEY_SRC_OBJECT, RTRIM(x.ROWID_OBJECT) AS ROWID_OBJECT,
               RTRIM(x.ORIG_ROWID_OBJECT) AS ORIG_ROWID_OBJECT
          FROM C_B_PTY_XREF x
         WHERE TRIM(x.ROWID_SYSTEM) = 'CRE'
       QUALIFY ROW_NUMBER() OVER (PARTITION BY x.PKEY_SRC_OBJECT ORDER BY x.ROWID_XREF) = 1
    ),
    -- LKP_HMRG_SRC1 / LKP_HMRG_TGT1 (by SRC_ROWID_OBJECT) and LKP_HMRG_SRC2 / LKP_HMRG_TGT2 (by TGT_ROWID_OBJECT)
    hmrg_src AS (SELECT DISTINCT RTRIM(SRC_ROWID_OBJECT) AS ROWID_OBJECT FROM C_B_PTY_HMRG
                  WHERE SRC_ROWID_OBJECT IS NOT NULL),
    hmrg_tgt AS (SELECT DISTINCT RTRIM(TGT_ROWID_OBJECT) AS ROWID_OBJECT FROM C_B_PTY_HMRG
                  WHERE TGT_ROWID_OBJECT IS NOT NULL)
    -- RTR_MERGES (VALIDATION: NULL conditions route to the default group) + EXP_SRC_TGT_MRG_RSLT
SELECT s.CARE_ID, s.CARE_LASTUP_DT, s.FIRSTNM, s.LASTNM, s.LAST_SUF, s.BIRTH_DT, s.SEX, s.INSERT_DATE, s.FEDETH, s.RACE, s.REC_TYPE
      FROM src s
    )
    SELECT CARE_ID AS PKEY_SRC_OBJECT,
           CARE_LASTUP_DT AS PERIOD_START_DATE,
           NULL AS PERIOD_END_DATE,
           '1' AS VERSION_SEQ,
           NULL AS PERIOD_REFERENCE_TIME,
           IFF((REC_TYPE IN ('B', 'D')), 2, NULL) AS TIMELINE_ACTION,
           :P_RUN_TS AS LAST_UPDATE_DATE,
           :P_RUN_TS AS CREATE_DATE,
           CARE_ID AS SRC_ROWID,
           BIRTH_DT AS BIRTH_DT,
           TRIM(NVL(((INITCAP(FIRSTNM, ' '))), '')
                            || (' ' || TRIM(((INITCAP(('~`!@#$%^&*()_-+=}{[]|\"'':;?/>.<,' || CHR(9)), ' ')))))
                            || ' '
                            || NVL(LTRIM(((INITCAP(LASTNM, ' ')))), ''))::VARCHAR AS FULL_NM,
           CASE WHEN 'Indv' IN ('I', 'Indv', 'INDV', 'HCP') AND LEFT(SEX, 1) IN ('B', 'U') THEN NULL
                 WHEN 'Indv' IN ('I', 'Indv', 'INDV', 'HCP') AND LEFT(SEX, 1) = 'M' THEN '1'
                 WHEN 'Indv' IN ('I', 'Indv', 'INDV', 'HCP') AND LEFT(SEX, 1) = 'F' THEN '2'
                 ELSE NULL END::VARCHAR AS GNDR_CD,
           NULL AS SFX_NM,
           ((INITCAP(LASTNM, ' ')))::VARCHAR AS LST_NM,
           ((INITCAP(FIRSTNM, ' ')))::VARCHAR AS FRST_NM,
           'Indv' AS PTY_BO_CLASS_CD,
           NVL(NULL, NVL(TRIM(FIRSTNM), '') || ' ' || NVL(TRIM(LASTNM), ''))::VARCHAR AS SRC_FULL_NM,
           NVL(CARE_LASTUP_DT, INSERT_DATE) AS SRC_LAST_UPD_DT,
           NULL AS ETHNCTY,
           NULL AS RACE_CD,
           FEDETH AS SRC_ETHNCTY,
           RACE AS SRC_RACE_CD
      FROM s1_src_mrg;
    RETURN SQLROWCOUNT;
END;
$$;
