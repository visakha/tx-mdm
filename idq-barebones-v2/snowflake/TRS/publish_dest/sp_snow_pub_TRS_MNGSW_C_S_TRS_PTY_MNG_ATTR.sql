-- ============================================================================
-- sp_snow_pub_TRS_MNGSW_C_S_TRS_PTY_MNG_ATTR.sql -- PUBLISH_DEST S10-only twin (C_S_* spine, first step only)
--
-- Twin of publish/sp_snow_pub_TRS_MNGSW_C_S_TRS_PTY_MNG_ATTR.sql. Same procedure, same target, same column list
-- -- but ONLY the first (source) step is inlined as a CTE (s10_daily);
-- every later step (ACTIVE / DQ / ROUTED / READY / ranked / router)
-- and the WHERE gate are dropped. Each target column is aliased
-- from a first-step column, a literal, or a parameter (see map).
-- A column the first step does not carry is NULL (see map).
-- WHERE gate dropped: WHERE VERSION_SEQ = 1) xa ON xa.PKEY_SRC_OBJECT = t.pkey_src_object WHERE xa.PKEY_SRC_OBJECT IS NULL QUALIFY ROW_NUMBER() OVER (PARTITION BY t.pkey_src_object ORDER BY t.EFF_BEGIN_DT DESC NULLS LAST) = 1
-- P_RUN_TS: YES
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_pub_TRS_MNGSW_C_S_TRS_PTY_MNG_ATTR (

    P_RUN_TS       TIMESTAMP_NTZ DEFAULT NULL

)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
INSERT INTO C_S_TRS_PTY_MNG_ATTR
           (PKEY_SRC_OBJECT, ROWID_OBJECT, DELETED_IND, DELETED_DATE, DELETED_BY, PERIOD_START_DATE, PERIOD_END_DATE,
            MNG_ATTR_TP, MNG_ATTR_VAL, VERSION_SEQ, PERIOD_REFERENCE_TIME, TIMELINE_ACTION, UPDATED_BY, CREATE_DATE,
            SRC_ROWID, CREATOR, LAST_UPDATE_DATE, SRC_LAST_UPD_DT, PTY_FK, HUB_STATE_IND)
    WITH
    s10_daily AS (
SELECT dc.indv_id AS INDV_ID,
        dc.FILE_CLEARANCE_SW,
        dc.SSA_VALIDATION_SW,
        dc.CREATE_DT AS EFF_BEGIN_DT,
        NULL AS TW_CONVERT_IND,
        NULL AS LTC_CONVERT_IND,
        TO_VARCHAR(dc.INDV_ID) || '        ' AS PTY_PK,
        dc.create_dt AS CREATE_DT,
        '       ' AS SRC_TBL,
        ROW_NUMBER() OVER (PARTITION BY dc.INDV_ID ORDER BY dc.CREATE_DT DESC) AS KEY_RN
          FROM STG_TRS_D_DC_INDV dc
        UNION
        SELECT cv.indv_id,
        NULL,
        NULL,
        cv.create_dt,
        cv.TW_CONVERT_IND,
        cv.LTC_CONVERT_IND,
        TO_VARCHAR(cv.INDV_ID),
        cv.create_dt,
        '   ',
        ROW_NUMBER() OVER (PARTITION BY cv.INDV_ID ORDER BY cv.CREATE_DT DESC)
          FROM STG_TRS_D_CV_DC_MCI_INDV cv
    )
    SELECT NVL(PTY_PK, '') || ' ' || '                 ' AS PKEY_SRC_OBJECT,
           NULL AS ROWID_OBJECT,
           NULL AS DELETED_IND,
           NULL AS DELETED_DATE,
           NULL AS DELETED_BY,
           EFF_BEGIN_DT AS PERIOD_START_DATE,
           NULL AS PERIOD_END_DATE,
           '                 ' AS MNG_ATTR_TP,
           TO_VARCHAR(FILE_CLEARANCE_SW) AS MNG_ATTR_VAL,
           1 AS VERSION_SEQ,
           NULL AS PERIOD_REFERENCE_TIME,
           NULL AS TIMELINE_ACTION,
           NULL AS UPDATED_BY,
           :P_RUN_TS AS CREATE_DATE,
           NVL(PTY_PK, '') || ' ' || '                 ' AS SRC_ROWID,
           NULL AS CREATOR,
           :P_RUN_TS AS LAST_UPDATE_DATE,
           CREATE_DT AS SRC_LAST_UPD_DT,
           PTY_PK AS PTY_FK,
           NULL AS HUB_STATE_IND
      FROM s10_daily;
    RETURN SQLROWCOUNT;
END;
$$;
