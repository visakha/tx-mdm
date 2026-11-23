-- ============================================================================
-- sp_snow_pub_TRS_NM_C_S_TRS_PTY_NM.sql -- PUBLISH_DEST S10-only twin (C_S_* spine, first step only)
--
-- Twin of publish/sp_snow_pub_TRS_NM_C_S_TRS_PTY_NM.sql. Same procedure, same target, same column list
-- -- but ONLY the first (source) step is inlined as a CTE (s10_src);
-- every later step (ACTIVE / DQ / ROUTED / READY / ranked / router)
-- and the WHERE gate are dropped. Each target column is aliased
-- from a first-step column, a literal, or a parameter (see map).
-- A column the first step does not carry is NULL (see map).
-- WHERE gate dropped: WHERE VERSION_SEQ = 1) xn ON xn.PKEY_SRC_OBJECT = d.pkey_src_object WHERE xn.PKEY_SRC_OBJECT IS NULL QUALIFY ROW_NUMBER() OVER (PARTITION BY d.pkey_src_object ORDER BY d.CREATE_DT DESC NULLS LAST, d.full_nm) = 1
-- P_RUN_TS: YES
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_pub_TRS_NM_C_S_TRS_PTY_NM (

    P_MEMBER_NAME_TYPE_CODE VARCHAR DEFAULT '002',
    P_RUN_TS       TIMESTAMP_NTZ DEFAULT NULL

)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
INSERT INTO C_S_TRS_PTY_NM
           (PTY_FK, SFX_NM, FRST_NM, PFX_NM, LST_NM, MDL_NM, FULL_NM, VERSION_SEQ, LAST_UPDATE_DATE, NM_TP, SRC_ROWID,
            ROWID_OBJECT, DELETED_IND, DELETED_DATE, DELETED_BY, PERIOD_END_DATE, PERIOD_REFERENCE_TIME, UPDATED_BY,
            CREATE_DATE, CREATOR, HUB_STATE_IND, SRC_FULL_NM, SRC_LAST_UPD_DT, PKEY_SRC_OBJECT, PERIOD_START_DATE)
    WITH
    s10_src AS (
SELECT DISTINCT DC_ALIAS.PKEY_PTY AS PKEY_PTY,
        RTRIM(LTRIM(DC_ALIAS.FIRST_NAME)) AS FIRST_NAME,
        RTRIM(LTRIM(DC_ALIAS.MID_NAME)) AS MID_NAME,
        RTRIM(LTRIM(DC_ALIAS.LAST_NAME)) AS LAST_NAME,
        RTRIM(DC_ALIAS.SUFX_NAME) AS SUFX_NAME,
        RTRIM(DC_ALIAS.PREFIX_NAME) AS PREFIX_NAME,
        DC_ALIAS.CREATE_DT AS CREATE_DT,
        DC_ALIAS.SEQUENCE_NUM AS SEQUENCE_NUM
          FROM (SELECT TO_VARCHAR(INDV_ID) AS PKEY_PTY,
        FIRST_NAME,
        MID_NAME,
        LAST_NAME,
        SUFX_NAME,
        PREFIX_NAME,
        CREATE_DT,
        SEQUENCE_NUM
                  FROM STG_TRS_D_CV_DC_MCI_ALIAS MCI_ALIAS
                UNION ALL
                SELECT TO_VARCHAR(INDV_ID) || '        ' AS PKEY_PTY,
        FIRST_NAME,
        MID_NAME,
        LAST_NAME,
        SUFX_NAME,
        PREFIX_NAME,
        CREATE_DT,
        SEQ_NUM
                  FROM STG_TRS_D_DC_ALIAS DC_ALIAS) DC_ALIAS
          JOIN STG_TRS_VALID_MEMBERS VM ON DC_ALIAS.PKEY_PTY = VM.PTY_PK
    )
    SELECT PKEY_PTY AS PTY_FK,
           NULL::VARCHAR AS SFX_NM,
           ((INITCAP((FIRST_NAME::VARCHAR), ' ')))::VARCHAR AS FRST_NM,
           NULL::VARCHAR AS PFX_NM,
           ((INITCAP((LAST_NAME::VARCHAR), ' ')))::VARCHAR AS LST_NM,
           ((INITCAP((MID_NAME::VARCHAR), ' ')))::VARCHAR AS MDL_NM,
           TRIM(NVL(((INITCAP((FIRST_NAME::VARCHAR), ' '))), '')
                            || (' ' || TRIM(((INITCAP((MID_NAME::VARCHAR), ' ')))))
                            || ' '
                            || NVL(LTRIM(((INITCAP((LAST_NAME::VARCHAR), ' ')))), ''))::VARCHAR AS FULL_NM,
           1 AS VERSION_SEQ,
           :P_RUN_TS AS LAST_UPDATE_DATE,
           :P_MEMBER_NAME_TYPE_CODE AS NM_TP,
           NVL(PKEY_PTY, '') || ' ' || :P_MEMBER_NAME_TYPE_CODE || ' ' || NVL(TO_VARCHAR(SEQUENCE_NUM), '') AS SRC_ROWID,
           NULL AS ROWID_OBJECT,
           NULL AS DELETED_IND,
           NULL AS DELETED_DATE,
           NULL AS DELETED_BY,
           NULL AS PERIOD_END_DATE,
           NULL AS PERIOD_REFERENCE_TIME,
           NULL AS UPDATED_BY,
           CREATE_DT AS CREATE_DATE,
           NULL AS CREATOR,
           NULL AS HUB_STATE_IND,
           TRIM(NVL(FIRST_NAME, '') || IFF(MID_NAME IS NOT NULL, ' ' || TRIM(MID_NAME), '')
                    || ' ' || NVL(LTRIM(LAST_NAME), '')) AS SRC_FULL_NM,
           CREATE_DT AS SRC_LAST_UPD_DT,
           NVL(PKEY_PTY, '') || ' ' || :P_MEMBER_NAME_TYPE_CODE || ' ' || NVL(TO_VARCHAR(SEQUENCE_NUM), '') AS PKEY_SRC_OBJECT,
           CREATE_DT AS PERIOD_START_DATE
      FROM s10_src;
    RETURN SQLROWCOUNT;
END;
$$;
