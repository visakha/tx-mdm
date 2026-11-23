-- ============================================================================
-- sp_snow_pub_TTF_PTY_C_S_TTF_PTY.sql -- PUBLISH_DEST S10-only twin (C_S_* spine, first step only)
--
-- Twin of publish/sp_snow_pub_TTF_PTY_C_S_TTF_PTY.sql. Same procedure, same target, same column list
-- -- but ONLY the first (source) step is inlined as a CTE (s1_active);
-- every later step (ACTIVE / DQ / ROUTED / READY / ranked / router)
-- and the WHERE gate are dropped. Each target column is aliased
-- from a first-step column, a literal, or a parameter (see map).
-- A column the first step does not carry is NULL (see map).
-- WHERE gate dropped: WHERE uq_pty
-- P_RUN_TS: YES
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_pub_TTF_PTY_C_S_TTF_PTY (
    P_RUN_TS TIMESTAMP_NTZ
)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
INSERT INTO C_S_TTF_PTY
           (PKEY_SRC_OBJECT, VERSION_SEQ, LAST_UPDATE_DATE, CREATE_DATE, SRC_ROWID, HUB_STATE_IND,
            PTY_BO_CLASS_CD, PRFX_NM, FRST_NM, MDL_NM, LST_NM, FULL_NM, GNDR_CD, SRC_FULL_NM, ETHNCTY,
            SRC_ETHNCTY, RACE_CD, SRC_RACE_CD, SRC_LAST_UPD_DT, PRFRD_LANG_CD, SFX_NM, PERIOD_START_DATE,
            BIRTH_DT)
    WITH
    s1_active AS (
SELECT v.CLIENTS_ID, v.FIRSTNAME, v.LASTNAME, v.MIDDLENAME, v.DOB, v.SUBMITDATE,
               v.RACEETHNICITYID, v.PTY_SRC_KEY,
               DECODE(v.SEXID, '33', 'F', '34', 'M', 'U')            AS gender,
               IFF(v.RACEETHNICITYID = '55', '55', NULL)             AS ethnicity
          FROM V_TTF_ETL_SRC v
         WHERE NOT EXISTS (SELECT 1 FROM STG_TTF_PTY_INACTIVE_STS i
                            WHERE i.SRC_KEY = v.PTY_SRC_KEY AND i.ROWID_SYSTEM = 'TTF'
                              AND i.DEACTIVATION_STS IS NOT NULL)
    )
    SELECT TRIM(PTY_SRC_KEY) AS PKEY_SRC_OBJECT,
           1 AS VERSION_SEQ,
           :P_RUN_TS AS LAST_UPDATE_DATE,
           SUBMITDATE AS CREATE_DATE,
           TRIM(PTY_SRC_KEY) AS SRC_ROWID,
           1 AS HUB_STATE_IND,
           'Indv' AS PTY_BO_CLASS_CD,
           NULL::VARCHAR AS PRFX_NM,
           ((INITCAP(FIRSTNAME, ' ')))::VARCHAR AS FRST_NM,
           ((INITCAP(MIDDLENAME, ' ')))::VARCHAR AS MDL_NM,
           ((INITCAP(LASTNAME, ' ')))::VARCHAR AS LST_NM,
           TRIM(NVL(((INITCAP(FIRSTNAME, ' '))), '')
                            || (' ' || TRIM(((INITCAP(MIDDLENAME, ' ')))))
                            || ' '
                            || NVL(LTRIM(((INITCAP(LASTNAME, ' ')))), ''))::VARCHAR AS FULL_NM,
           CASE WHEN 'Indv' IN ('I', 'Indv', 'INDV', 'HCP') AND LEFT(GENDER, 1) IN ('B', 'U') THEN NULL
                 WHEN 'Indv' IN ('I', 'Indv', 'INDV', 'HCP') AND LEFT(GENDER, 1) = 'M' THEN '1'
                 WHEN 'Indv' IN ('I', 'Indv', 'INDV', 'HCP') AND LEFT(GENDER, 1) = 'F' THEN '2'
                 ELSE NULL END::VARCHAR AS GNDR_CD,
           NVL(TRIM(NVL(FIRSTNAME, '') || IFF(MIDDLENAME IS NOT NULL, ' ' || TRIM(MIDDLENAME), '')
                        || ' ' || NVL(LTRIM(LASTNAME), '')), NVL(TRIM(FIRSTNAME), '') || ' ' || NVL(TRIM(LASTNAME), ''))::VARCHAR AS SRC_FULL_NM,
           NULL AS ETHNCTY,
           ETHNICITY AS SRC_ETHNCTY,
           NULL AS RACE_CD,
           RACEETHNICITYID AS SRC_RACE_CD,
           SUBMITDATE AS SRC_LAST_UPD_DT,
           NULL AS PRFRD_LANG_CD,
           NULL AS SFX_NM,
           :P_RUN_TS AS PERIOD_START_DATE,
           IFF(DOB IS NULL, DOB, NULL) AS BIRTH_DT
      FROM s1_active;
    RETURN SQLROWCOUNT;
END;
$$;
