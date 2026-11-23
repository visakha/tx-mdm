-- ============================================================================
-- sp_snow_pub_TRS_PTY_C_S_TRS_PTY_RLE.sql -- PUBLISH_DEST S10-only twin (C_S_* spine, first step only)
--
-- Twin of publish/sp_snow_pub_TRS_PTY_C_S_TRS_PTY_RLE.sql. Same procedure, same target, same column list
-- -- but ONLY the first (source) step is inlined as a CTE (s1_src);
-- every later step (ACTIVE / DQ / ROUTED / READY / ranked / router)
-- and the WHERE gate are dropped. Each target column is aliased
-- from a first-step column, a literal, or a parameter (see map).
-- A column the first step does not carry is NULL (see map).
-- WHERE gate dropped: WHERE rn_pty = 1 AND uq_rle
-- P_RUN_TS: YES
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_pub_TRS_PTY_C_S_TRS_PTY_RLE (

    P_RLE_BO_CLASS_CD_MEMBER VARCHAR DEFAULT 'Member',
    P_RUN_TS       TIMESTAMP_NTZ DEFAULT NULL

)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
INSERT INTO C_S_TRS_PTY_RLE
           (PTY_FK, PKEY_SRC_OBJECT, ROWID_OBJECT, DELETED_IND, DELETED_DATE, DELETED_BY, RLE_BO_CLASS_CD,
            VERSION_SEQ, PERIOD_END_DATE, PERIOD_START_DATE, TIMELINE_ACTION, PERIOD_REFERENCE_TIME, UPDATED_BY,
            CREATE_DATE, CREATOR, SRC_LAST_UPD_DT, HUB_STATE_IND, SRC_ROWID, LAST_UPDATE_DATE)
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
        a.SRC_TBL
          FROM all_indv a
         INNER JOIN new_valid_indvs f ON f.indv_id = a.indv_id
    )
    SELECT TRIM((IFF(SRC_TBL = 'DC_INDV', TO_VARCHAR(INDV_ID) || ' ' || 'DC_INDV',
                       TO_VARCHAR(INDV_ID)))) AS PTY_FK,
           (TRIM((IFF(SRC_TBL = 'DC_INDV', TO_VARCHAR(INDV_ID) || ' ' || 'DC_INDV',
                       TO_VARCHAR(INDV_ID))))) || '|' || :P_RLE_BO_CLASS_CD_MEMBER AS PKEY_SRC_OBJECT,
           NULL AS ROWID_OBJECT,
           NULL AS DELETED_IND,
           NULL AS DELETED_DATE,
           NULL AS DELETED_BY,
           :P_RLE_BO_CLASS_CD_MEMBER AS RLE_BO_CLASS_CD,
           1 AS VERSION_SEQ,
           NULL AS PERIOD_END_DATE,
           CREATE_DT AS PERIOD_START_DATE,
           NULL AS TIMELINE_ACTION,
           NULL AS PERIOD_REFERENCE_TIME,
           NULL AS UPDATED_BY,
           NULL AS CREATE_DATE,
           NULL AS CREATOR,
           CREATE_DT AS SRC_LAST_UPD_DT,
           NULL AS HUB_STATE_IND,
           (TRIM((IFF(SRC_TBL = 'DC_INDV', TO_VARCHAR(INDV_ID) || ' ' || 'DC_INDV',
                       TO_VARCHAR(INDV_ID))))) || '|' || :P_RLE_BO_CLASS_CD_MEMBER AS SRC_ROWID,
           :P_RUN_TS AS LAST_UPDATE_DATE
      FROM s1_src;
    RETURN SQLROWCOUNT;
END;
$$;
