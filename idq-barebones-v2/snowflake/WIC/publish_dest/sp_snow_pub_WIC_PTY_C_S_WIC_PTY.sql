-- ============================================================================
-- sp_snow_pub_WIC_PTY_C_S_WIC_PTY.sql -- PUBLISH_DEST S10-only twin (C_S_* spine, first step only)
--
-- Twin of publish/sp_snow_pub_WIC_PTY_C_S_WIC_PTY.sql. Same procedure, same target, same column list
-- -- but ONLY the first (source) step is inlined as a CTE (s10_active);
-- every later step (ACTIVE / DQ / ROUTED / READY / ranked / router)
-- and the WHERE gate are dropped. Each target column is aliased
-- from a first-step column, a literal, or a parameter (see map).
-- A column the first step does not carry is NULL (see map).
-- WHERE gate dropped: WHERE uq_pty
-- P_RUN_TS: YES
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_pub_WIC_PTY_C_S_WIC_PTY (
    P_RUN_TS TIMESTAMP_NTZ
)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
    INSERT INTO C_S_WIC_PTY
           (PKEY_SRC_OBJECT, VERSION_SEQ, LAST_UPDATE_DATE, SRC_ROWID, HUB_STATE_IND, PTY_BO_CLASS_CD,
            BIRTH_WGHT_GRMS, PERIOD_START_DATE, CREATE_DATE, PRFX_NM, FRST_NM, MDL_NM, LST_NM, FULL_NM, GNDR_CD,
            BIRTH_DT, SRC_RACE_CD, RACE_CD, ETHNCTY, SRC_ETHNCTY, PRFRD_LANG_CD, SRC_LAST_UPD_DT,
            SRC_PRFRD_LANG_CD, SRC_FULL_NM)
    WITH
    s10_active AS (
SELECT v.DATEKEY, v.ID, v.PTY_SRC_KEY, v.FIRST_NAME, v.LAST_NAME,
               v.MIDDLE_NAME, v.DOB, v.GENDER, v.BIRTH_WT_OZ, v.LANGUAGE_CD, v.ETHNICITY,
               v.RACE_WHITE_IND, v.RACE_AA_IND, v.RACE_ASIAN_IND, v.RACE_PI_IND, v.RACE_AN_IND
          FROM V_WIC_ETL_SRC v
         WHERE NOT EXISTS (SELECT 1 FROM STG_WIC_PTY_INACTIVE_STS i
                            WHERE i.SRC_KEY = v.PTY_SRC_KEY AND i.ROWID_SYSTEM = 'WIC'
                              AND i.DEACTIVATION_STS IS NOT NULL)
    )
    SELECT TRIM(PTY_SRC_KEY) AS PKEY_SRC_OBJECT,
           1 AS VERSION_SEQ,
           :P_RUN_TS AS LAST_UPDATE_DATE,
           TRIM(PTY_SRC_KEY) AS SRC_ROWID,
           1 AS HUB_STATE_IND,
           'Indv' AS PTY_BO_CLASS_CD,
           BIRTH_WT_OZ * 28.35 AS BIRTH_WGHT_GRMS,
           DATEKEY AS PERIOD_START_DATE,
           DATEKEY AS CREATE_DATE,
           NULL::VARCHAR AS PRFX_NM,
           ((INITCAP(FIRST_NAME, ' ')))::VARCHAR AS FRST_NM,
           ((INITCAP(MIDDLE_NAME, ' ')))::VARCHAR AS MDL_NM,
           ((INITCAP(LAST_NAME, ' ')))::VARCHAR AS LST_NM,
           TRIM(NVL(((INITCAP(FIRST_NAME, ' '))), '')
                            || (' ' || TRIM(((INITCAP(MIDDLE_NAME, ' ')))))
                            || ' '
                            || NVL(LTRIM(((INITCAP(LAST_NAME, ' ')))), ''))::VARCHAR AS FULL_NM,
           CASE WHEN 'Indv' IN ('I', 'Indv', 'INDV', 'HCP') AND LEFT(GENDER, 1) IN ('B', 'U') THEN NULL
                 WHEN 'Indv' IN ('I', 'Indv', 'INDV', 'HCP') AND LEFT(GENDER, 1) = 'M' THEN '1'
                 WHEN 'Indv' IN ('I', 'Indv', 'INDV', 'HCP') AND LEFT(GENDER, 1) = 'F' THEN '2'
                 ELSE NULL END::VARCHAR AS GNDR_CD,
           DOB AS BIRTH_DT,
           'WH' || NVL(TO_VARCHAR(RACE_WHITE_IND), '') || 'AA' || NVL(TO_VARCHAR(RACE_AA_IND), '')
            || 'AS' || NVL(TO_VARCHAR(RACE_ASIAN_IND), '') || 'PI' || NVL(TO_VARCHAR(RACE_PI_IND), '')
            || 'NA' || NVL(TO_VARCHAR(RACE_AN_IND), '')::VARCHAR AS SRC_RACE_CD,
           CASE WHEN RACE_WHITE_IND + RACE_AA_IND + RACE_ASIAN_IND + RACE_PI_IND + RACE_AN_IND = 2
                     THEN '006'
                 WHEN RACE_WHITE_IND + RACE_AA_IND + RACE_ASIAN_IND + RACE_PI_IND + RACE_AN_IND > 2
                     THEN '007'
                 WHEN RACE_WHITE_IND + RACE_AA_IND + RACE_ASIAN_IND + RACE_PI_IND + RACE_AN_IND = 0
                     THEN NULL
                 WHEN RACE_WHITE_IND + RACE_AA_IND + RACE_ASIAN_IND + RACE_PI_IND + RACE_AN_IND = 1
                     THEN CASE WHEN RACE_WHITE_IND = 1 THEN '001'
                               WHEN RACE_AA_IND = 1 THEN '002'
                               WHEN RACE_AN_IND = 1 THEN '003'
                               WHEN RACE_ASIAN_IND = 1 THEN '004'
                               WHEN RACE_PI_IND = 1 THEN '005' END
                 ELSE NULL END::VARCHAR AS RACE_CD,
           NULL AS ETHNCTY,
           ETHNICITY AS SRC_ETHNCTY,
           NULL AS PRFRD_LANG_CD,
           DATEKEY AS SRC_LAST_UPD_DT,
           LANGUAGE_CD AS SRC_PRFRD_LANG_CD,
           NVL(TRIM(NVL(FIRST_NAME, '') || IFF(MIDDLE_NAME IS NOT NULL, ' ' || TRIM(MIDDLE_NAME), '')
                        || ' ' || NVL(LTRIM(LAST_NAME), '')), NVL(TRIM(FIRST_NAME), '') || ' ' || NVL(TRIM(LAST_NAME), ''))::VARCHAR AS SRC_FULL_NM
      FROM s10_active;
    RETURN SQLROWCOUNT;
END;
$$;
