-- ============================================================================
-- sp_snow_pub_ECI_PTY_C_S_ECI_PTY.sql -- PUBLISH_DEST S10-only twin (C_S_* spine, first step only)
--
-- Twin of publish/sp_snow_pub_ECI_PTY_C_S_ECI_PTY.sql. Same procedure, same target, same column list
-- -- but ONLY the first (source) step is inlined as a CTE (s10_src);
-- every later step (ACTIVE / DQ / ROUTED / READY / ranked / router)
-- and the WHERE gate are dropped. Each target column is aliased
-- from a first-step column, a literal, or a parameter (see map).
-- A column the first step does not carry is NULL (see map).
-- WHERE gate dropped: WHERE uq_pty
-- P_RUN_TS: YES
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_pub_ECI_PTY_C_S_ECI_PTY (
    P_RUN_TS TIMESTAMP_NTZ
)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
INSERT INTO C_S_ECI_PTY
           (PKEY_SRC_OBJECT, VERSION_SEQ, LAST_UPDATE_DATE, UPDATED_BY, CREATE_DATE, CREATOR, SRC_ROWID,
            PTY_BO_CLASS_CD, PRFX_NM, FULL_NM, LST_NM, MDL_NM, FRST_NM, GNDR_CD, BIRTH_DT, SRC_FULL_NM,
            SRC_LAST_UPD_DT, BIRTH_WGHT_GRMS, HUB_STATE_IND, SRC_ETHNCTY, ETHNCTY, RACE_CD, PRFRD_LANG_CD,
            SRC_PRFRD_LANG_CD, SRC_RACE_CD, PERIOD_START_DATE)
    WITH
    s10_src AS (
WITH
        src AS (
            SELECT 'ECI_CHILD' AS SOURCE_TABLE, child.ID_CHILD AS ID, child.FIRST_NAME AS FIRST_NAME, child.LAST_NAME AS LAST_NAME, child.MIDDLE_INITIAL AS MIDDLE_INITIAL, child.DOB AS DOB, child.GENDER AS GENDER, child.BIRTH_WT_LB AS BIRTH_WT_LB, child.BIRTH_WT_OZ AS BIRTH_WT_OZ, child.LANGUAGE_CD AS LANGUAGE_CD, child.DATE_CREATED AS DATE_CREATED, COALESCE(child.DATE_MODIFIED, child.DATE_CREATED) AS DATE_MODIFIED, child.MODIFIED_BY AS MODIFIED_BY, child.CREATED_BY AS CREATED_BY, child.ETHNICITY AS ETHNICITY, child.RACE_WHITE AS RACE_WHITE, child.RACE_AA AS RACE_AA, child.RACE_ASIAN AS RACE_ASIAN, child.RACE_PI AS RACE_PI, child.RACE_AN AS RACE_AN
              FROM STG_ECI_D_CHILD child
            UNION ALL
            SELECT 'ECI_FAMILY', fam.ID_FAMILY, fam.FIRST_NAME, fam.LAST_NAME, fam.MIDDLE_INITIAL, fam.DOB, fam.GENDER, NULL, NULL, NULL, fam.DATE_CREATED, COALESCE(fam.DATE_MODIFIED, fam.DATE_CREATED), fam.MODIFIED_BY, fam.CREATED_BY, NULL, NULL, NULL, NULL, NULL, NULL
              FROM STG_ECI_D_FAMILY fam
        )
        SELECT s.ID, s.FIRST_NAME, s.LAST_NAME, s.MIDDLE_INITIAL, s.DOB, s.GENDER, s.BIRTH_WT_LB, s.BIRTH_WT_OZ, s.LANGUAGE_CD, s.DATE_CREATED, s.DATE_MODIFIED, s.MODIFIED_BY, s.CREATED_BY, s.ETHNICITY, s.RACE_WHITE, s.RACE_AA, s.RACE_ASIAN, s.RACE_PI, s.RACE_AN,
               LPAD(TO_VARCHAR(s.ID), 10, '0') || IFF(s.SOURCE_TABLE = 'ECI_FAMILY', 'F', '')  AS pkey_src_object,
               'Indv' AS party_type,
               'ECI'  AS src_system,
               TRIM(NVL(s.FIRST_NAME, '')
                        || IFF(s.MIDDLE_INITIAL IS NOT NULL, ' ' || TRIM(s.MIDDLE_INITIAL), '')
                        || ' ' || NVL(LTRIM(s.LAST_NAME), ''))                                      AS src_full_name
          FROM src s
    )
    SELECT TRIM(PKEY_SRC_OBJECT) AS PKEY_SRC_OBJECT,
           1 AS VERSION_SEQ,
           :P_RUN_TS AS LAST_UPDATE_DATE,
           MODIFIED_BY AS UPDATED_BY,
           DATE_CREATED AS CREATE_DATE,
           CREATED_BY AS CREATOR,
           TRIM(PKEY_SRC_OBJECT) AS SRC_ROWID,
           'Indv' AS PTY_BO_CLASS_CD,
           NULL::VARCHAR AS PRFX_NM,
           TRIM(NVL(((INITCAP(FIRST_NAME, ' '))), '')
                            || (' ' || TRIM(((INITCAP(MIDDLE_INITIAL, ' ')))))
                            || ' '
                            || NVL(LTRIM(((INITCAP(LAST_NAME, ' ')))), ''))::VARCHAR AS FULL_NM,
           ((INITCAP(LAST_NAME, ' ')))::VARCHAR AS LST_NM,
           ((INITCAP(MIDDLE_INITIAL, ' ')))::VARCHAR AS MDL_NM,
           ((INITCAP(FIRST_NAME, ' ')))::VARCHAR AS FRST_NM,
           CASE WHEN PARTY_TYPE IN ('I', 'Indv', 'INDV', 'HCP') AND LEFT(GENDER, 1) IN ('B', 'U') THEN NULL
                 WHEN PARTY_TYPE IN ('I', 'Indv', 'INDV', 'HCP') AND LEFT(GENDER, 1) = 'M' THEN '1'
                 WHEN PARTY_TYPE IN ('I', 'Indv', 'INDV', 'HCP') AND LEFT(GENDER, 1) = 'F' THEN '2'
                 ELSE NULL END::VARCHAR AS GNDR_CD,
           IFF(DOB IS NULL, DOB, NULL) AS BIRTH_DT,
           NVL(SRC_FULL_NAME, NVL(TRIM(FIRST_NAME), '') || ' ' || NVL(TRIM(LAST_NAME), ''))::VARCHAR AS SRC_FULL_NM,
           DATE_MODIFIED AS SRC_LAST_UPD_DT,
           BIRTH_WT_LB * 453.6 + BIRTH_WT_OZ * 28.35 AS BIRTH_WGHT_GRMS,
           1 AS HUB_STATE_IND,
           ETHNICITY AS SRC_ETHNCTY,
           NULL AS ETHNCTY,
           CASE WHEN RACE_WHITE + RACE_AA + RACE_ASIAN + RACE_PI + RACE_AN = 2
                     THEN '006'
                 WHEN RACE_WHITE + RACE_AA + RACE_ASIAN + RACE_PI + RACE_AN > 2
                     THEN '007'
                 WHEN RACE_WHITE + RACE_AA + RACE_ASIAN + RACE_PI + RACE_AN = 0
                     THEN NULL
                 WHEN RACE_WHITE + RACE_AA + RACE_ASIAN + RACE_PI + RACE_AN = 1
                     THEN CASE WHEN RACE_WHITE = 1 THEN '001'
                               WHEN RACE_AA = 1 THEN '002'
                               WHEN RACE_AN = 1 THEN '003'
                               WHEN RACE_ASIAN = 1 THEN '004'
                               WHEN RACE_PI = 1 THEN '005' END
                 ELSE NULL END::VARCHAR AS RACE_CD,
           NULL AS PRFRD_LANG_CD,
           LANGUAGE_CD AS SRC_PRFRD_LANG_CD,
           'WH' || NVL(TO_VARCHAR(RACE_WHITE), '') || 'AA' || NVL(TO_VARCHAR(RACE_AA), '')
            || 'AS' || NVL(TO_VARCHAR(RACE_ASIAN), '') || 'PI' || NVL(TO_VARCHAR(RACE_PI), '')
            || 'NA' || NVL(TO_VARCHAR(RACE_AN), '')::VARCHAR AS SRC_RACE_CD,
           DATE_MODIFIED AS PERIOD_START_DATE
      FROM s10_src;

    RETURN SQLROWCOUNT;
END;
$$;
