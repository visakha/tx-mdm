-- ============================================================================
-- sp_snow_pub_TRS_PTY_C_S_TRS_PTY.sql -- PUBLISH_DEST S10-only twin (C_S_* spine, first step only)
--
-- Twin of publish/sp_snow_pub_TRS_PTY_C_S_TRS_PTY.sql. Same procedure, same target, same column list
-- -- but ONLY the first (source) step is inlined as a CTE (s1_src);
-- every later step (ACTIVE / DQ / ROUTED / READY / ranked / router)
-- and the WHERE gate are dropped. Each target column is aliased
-- from a first-step column, a literal, or a parameter (see map).
-- A column the first step does not carry is NULL (see map).
-- WHERE gate dropped: WHERE rn_pty = 1 AND uq_pty
-- P_RUN_TS: YES
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_pub_TRS_PTY_C_S_TRS_PTY (

    P_PTY_BO_CLASS_CD_MEMBER VARCHAR DEFAULT 'Indv',
    P_RUN_TS       TIMESTAMP_NTZ DEFAULT NULL

)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
INSERT INTO C_S_TRS_PTY
           (PKEY_SRC_OBJECT, ROWID_OBJECT, DELETED_IND, DELETED_DATE, DELETED_BY, GNDR_CD, SFX_NM,
            PTY_BO_CLASS_CD, FRST_NM, PRFX_NM, LST_NM, MDL_NM, FULL_NM, BIRTH_DT, VERSION_SEQ,
            PERIOD_REFERENCE_TIME, TIMELINE_ACTION, LAST_UPDATE_DATE, UPDATED_BY, CREATE_DATE, CREATOR,
            HUB_STATE_IND, FLAG_SRC, DEATH_DT, SRC_FULL_NM, PERIOD_START_DATE, PERIOD_END_DATE, SRC_LAST_UPD_DT,
            SRC_ROWID, RACE_CD, ETHNCTY, SRC_ETHNCTY, SRC_RACE_CD)
    WITH
    s1_src AS (
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
            SELECT INDV_ID,
        FIRST_NAME,
        MID_NAME,
        LAST_NAME,
        SUFX_NAME,
        PREFIX_NAME,
        GENDER_CD,
        RACE_CD,
        ETHNICITY_CD,
        DOB_DT,
        NULL AS DEATH_DT,
        CREATE_DT,
        'MCI' AS SRC_TBL
              FROM STG_TRS_D_CV_DC_MCI_INDV
            UNION ALL
            SELECT INDV_ID,
        FIRST_NAME,
        MID_NAME,
        LAST_NAME,
        SUFX_NAME,
        PREFIX_NAME,
        GENDER_CD,
        RACE_CD,
        ETHNICITY_CD,
        DOB_DT,
        DEATH_DT,
        CREATE_DT,
        'DC_INDV'
              FROM STG_TRS_D_DC_INDV
        )
        SELECT DISTINCT a.INDV_ID,
        RTRIM(LTRIM(a.FIRST_NAME)) AS FIRST_NAME,
        RTRIM(LTRIM(a.MID_NAME)) AS MID_NAME,
        RTRIM(LTRIM(a.LAST_NAME)) AS LAST_NAME,
        RTRIM(a.SUFX_NAME) AS SUFX_NAME,
        RTRIM(a.PREFIX_NAME) AS PREFIX_NAME,
        a.GENDER_CD,
        a.RACE_CD,
        a.ETHNICITY_CD,
        a.DOB_DT,
        a.CREATE_DT,
        a.SRC_TBL,
        a.DEATH_DT
          FROM all_indv a
         INNER JOIN new_valid_indvs f ON f.indv_id = a.indv_id
    )
    SELECT TRIM((IFF(SRC_TBL = 'DC_INDV', TO_VARCHAR(INDV_ID) || ' ' || 'DC_INDV',
                       TO_VARCHAR(INDV_ID)))) AS PKEY_SRC_OBJECT,
           NULL AS ROWID_OBJECT,
           NULL AS DELETED_IND,
           NULL AS DELETED_DATE,
           NULL AS DELETED_BY,
           CASE WHEN '    ' IN ('I', 'Indv', 'INDV', 'HCP') AND LEFT(GENDER_CD, 1) IN ('B', 'U') THEN NULL
                 WHEN '    ' IN ('I', 'Indv', 'INDV', 'HCP') AND LEFT(GENDER_CD, 1) = 'M' THEN '1'
                 WHEN '    ' IN ('I', 'Indv', 'INDV', 'HCP') AND LEFT(GENDER_CD, 1) = 'F' THEN '2'
                 ELSE NULL END::VARCHAR AS GNDR_CD,
           NULL AS SFX_NM,
           :P_PTY_BO_CLASS_CD_MEMBER AS PTY_BO_CLASS_CD,
           ((INITCAP(FIRST_NAME, ' ')))::VARCHAR AS FRST_NM,
           NULL AS PRFX_NM,
           ((INITCAP(LAST_NAME, ' ')))::VARCHAR AS LST_NM,
           ((INITCAP(MID_NAME, ' ')))::VARCHAR AS MDL_NM,
           TRIM(NVL(((INITCAP(FIRST_NAME, ' '))), '')
                            || (' ' || TRIM(((INITCAP(MID_NAME, ' ')))))
                            || ' '
                            || NVL(LTRIM(((INITCAP(LAST_NAME, ' ')))), ''))::VARCHAR AS FULL_NM,
           IFF(DOB_DT IS NULL, DOB_DT, NULL) AS BIRTH_DT,
           1 AS VERSION_SEQ,
           NULL AS PERIOD_REFERENCE_TIME,
           NULL AS TIMELINE_ACTION,
           :P_RUN_TS AS LAST_UPDATE_DATE,
           NULL AS UPDATED_BY,
           NULL AS CREATE_DATE,
           NULL AS CREATOR,
           NULL AS HUB_STATE_IND,
           NULL AS FLAG_SRC,
           DEATH_DT AS DEATH_DT,
           TRIM(NVL(FIRST_NAME, '') || IFF(MID_NAME IS NOT NULL, ' ' || TRIM(MID_NAME), '')
                        || ' ' || NVL(LTRIM(LAST_NAME), '')) AS SRC_FULL_NM,
           CREATE_DT AS PERIOD_START_DATE,
           NULL AS PERIOD_END_DATE,
           CREATE_DT AS SRC_LAST_UPD_DT,
           TRIM((IFF(SRC_TBL = 'DC_INDV', TO_VARCHAR(INDV_ID) || ' ' || 'DC_INDV',
                       TO_VARCHAR(INDV_ID)))) AS SRC_ROWID,
           NULL AS RACE_CD,
           NULL AS ETHNCTY,
           ETHNICITY_CD AS SRC_ETHNCTY,
           RACE_CD AS SRC_RACE_CD
      FROM s1_src;
    RETURN SQLROWCOUNT;
END;
$$;
