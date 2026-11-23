-- ============================================================================
-- sp_snow_pub_FSS_PTY_C_S_FSS_PTY.sql -- PUBLISH_DEST S10-only twin (C_S_* spine, first step only)
--
-- Twin of publish/sp_snow_pub_FSS_PTY_C_S_FSS_PTY.sql. Same procedure, same target, same column list
-- -- but ONLY the first (source) step is inlined as a CTE (s1_src);
-- every later step (ACTIVE / DQ / ROUTED / READY / ranked / router)
-- and the WHERE gate are dropped. Each target column is aliased
-- from a first-step column, a literal, or a parameter (see map).
-- A column the first step does not carry is NULL (see map).
-- WHERE gate dropped: WHERE uq_pty
-- P_RUN_TS: YES
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_pub_FSS_PTY_C_S_FSS_PTY (
    P_RUN_TS TIMESTAMP_NTZ
)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
INSERT INTO C_S_FSS_PTY
           (PKEY_SRC_OBJECT, PERIOD_START_DATE, VERSION_SEQ, LAST_UPDATE_DATE, CREATE_DATE, SRC_ROWID,
            HUB_STATE_IND, PTY_BO_CLASS_CD, PRFX_NM, FRST_NM, MDL_NM, LST_NM, FULL_NM, GNDR_CD, BIRTH_DT,
            SRC_FULL_NM, ETHNCTY, SRC_ETHNCTY, RACE_CD, SRC_RACE_CD, SRC_LAST_UPD_DT, PRFRD_LANG_CD, SFX_NM)
    WITH
    s1_src AS (
SELECT s.dt_last_update,
       s.pty_src_key,
       s.id_client,
       s.nm_first,
       s.nm_last,
       s.nm_middle,
       s.dt_dob,
       s.cd_gender,
       s.language_cd,
       s.cd_hispanic,
       s.race_an,
       s.race_asian,
       s.race_aa,
       s.race_white,
       s.race_pi,
       s.cd_suffix
FROM ( SELECT v.DT_LAST_UPDATE,
       v.PTY_SRC_KEY,
       v.ID_CLIENT,
       v.NM_FIRST,
       v.NM_LAST,
       v.NM_MIDDLE,
       v.DT_DOB,
       v.CD_GENDER,
       v.LANGUAGE_CD,
       v.CD_HISPANIC,
       v.RACE_AN,
       v.RACE_ASIAN,
       v.RACE_AA,
       v.RACE_WHITE,
       v.RACE_PI,
       v.CD_SUFFIX
FROM v_fss_etl_src v
WHERE v.LAST_ACTIVE_CLIENT_REGISTRATION_YN = 'Y' ) s
WHERE NOT EXISTS (SELECT 1 FROM STG_FSS_PTY_INACTIVE_STS i
                        WHERE i.SRC_KEY = s.PTY_SRC_KEY AND i.ROWID_SYSTEM = 'FSS'
                          AND i.DEACTIVATION_STS IS NOT NULL)
    )
    SELECT TRIM(PTY_SRC_KEY) AS PKEY_SRC_OBJECT,
           DT_LAST_UPDATE AS PERIOD_START_DATE,
           1 AS VERSION_SEQ,
           :P_RUN_TS AS LAST_UPDATE_DATE,
           DT_LAST_UPDATE AS CREATE_DATE,
           TRIM(PTY_SRC_KEY) AS SRC_ROWID,
           1 AS HUB_STATE_IND,
           'Indv' AS PTY_BO_CLASS_CD,
           NULL::VARCHAR AS PRFX_NM,
           ((INITCAP(NM_FIRST, ' ')))::VARCHAR AS FRST_NM,
           ((INITCAP(NM_MIDDLE, ' ')))::VARCHAR AS MDL_NM,
           ((INITCAP(NM_LAST, ' ')))::VARCHAR AS LST_NM,
           TRIM(NVL(((INITCAP(NM_FIRST, ' '))), '')
                            || (' ' || TRIM(((INITCAP(NM_MIDDLE, ' ')))))
                            || ' '
                            || NVL(LTRIM(((INITCAP(NM_LAST, ' ')))), ''))::VARCHAR AS FULL_NM,
           CASE WHEN 'Indv' IN ('I', 'Indv', 'INDV', 'HCP') AND LEFT(CD_GENDER, 1) IN ('B', 'U') THEN NULL
                 WHEN 'Indv' IN ('I', 'Indv', 'INDV', 'HCP') AND LEFT(CD_GENDER, 1) = 'M' THEN '1'
                 WHEN 'Indv' IN ('I', 'Indv', 'INDV', 'HCP') AND LEFT(CD_GENDER, 1) = 'F' THEN '2'
                 ELSE NULL END::VARCHAR AS GNDR_CD,
           DT_DOB AS BIRTH_DT,
           NVL(TRIM(NVL(NM_FIRST, '') || IFF(NM_MIDDLE IS NOT NULL, ' ' || TRIM(NM_MIDDLE), '')
                    || ' ' || NVL(LTRIM(NM_LAST), '')), NVL(TRIM(NM_FIRST), '') || ' ' || NVL(TRIM(NM_LAST), ''))::VARCHAR AS SRC_FULL_NM,
           NULL AS ETHNCTY,
           CD_HISPANIC AS SRC_ETHNCTY,
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
           'WH' || NVL(TO_VARCHAR(RACE_WHITE), '') || 'AA' || NVL(TO_VARCHAR(RACE_AA), '')
            || 'AS' || NVL(TO_VARCHAR(RACE_ASIAN), '') || 'PI' || NVL(TO_VARCHAR(RACE_PI), '')
            || 'NA' || NVL(TO_VARCHAR(RACE_AN), '')::VARCHAR AS SRC_RACE_CD,
           DT_LAST_UPDATE AS SRC_LAST_UPD_DT,
           NULL AS PRFRD_LANG_CD,
           NULL AS SFX_NM
      FROM s1_src;
    RETURN SQLROWCOUNT;
END;
$$;
