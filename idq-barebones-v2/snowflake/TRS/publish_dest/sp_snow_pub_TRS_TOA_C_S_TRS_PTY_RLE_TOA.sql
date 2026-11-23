-- ============================================================================
-- sp_snow_pub_TRS_TOA_C_S_TRS_PTY_RLE_TOA.sql -- PUBLISH_DEST S10-only twin (C_S_* spine, first step only)
--
-- Twin of publish/sp_snow_pub_TRS_TOA_C_S_TRS_PTY_RLE_TOA.sql. Same procedure, same target, same column list
-- -- but ONLY the first (source) step is inlined as a CTE (s10_raw);
-- every later step (ACTIVE / DQ / ROUTED / READY / ranked / router)
-- and the WHERE gate are dropped. Each target column is aliased
-- from a first-step column, a literal, or a parameter (see map).
-- A column the first step does not carry is NULL (see map).
-- WHERE gate dropped: WHERE NOT grp_bad_value AND NOT grp_dates AND uq_toa
-- P_RUN_TS: YES
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_pub_TRS_TOA_C_S_TRS_PTY_RLE_TOA (
    P_RUN_TS TIMESTAMP_NTZ
)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
INSERT INTO C_S_TRS_PTY_RLE_TOA
           (PKEY_SRC_OBJECT, ROWID_OBJECT, DELETED_IND, DELETED_DATE, DELETED_BY, PERIOD_START_DATE,
            PERIOD_END_DATE, VERSION_SEQ, PERIOD_REFERENCE_TIME, LAST_UPDATE_DATE, UPDATED_BY, CREATE_DATE,
            CREATOR, SRC_ROWID, HUB_STATE_IND, TOA_SOURCE, TOA_FK, EFF_STRT_DT, EFF_END_DT, PTY_RLE_FK, EDG_NUM,
            CASE_NUM, SGMNT_KEY, CNVRT_DT, CNVRT_SYS_CD, INDV_ID, PRTCPNT_STS_CD, SRC_LAST_UPD_DT)
    WITH
    s10_raw AS (
SELECT TO_VARCHAR(toa.INDV_ID) AS INDV_ID,
        toa.TYPE_OF_ASSISTANCE_CD,
        toa.ELIG_EFF_BEGIN_DT AS BEGIN_DT,
        toa.ELIG_EFF_END_DT AS END_DT,
        '            ' AS SRC_TBL,
        ROW_NUMBER() OVER (PARTITION BY TO_VARCHAR(toa.INDV_ID) || ' ' || NVL(TO_VARCHAR(toa.EDG_NUM), '')
                                               || ' ' || NVL(TO_VARCHAR(toa.PROGRAM_CD), '') || ' '
                                               || NVL(TO_VARCHAR(toa.MCI_CREATE_SEQ), '')
                                  ORDER BY toa.CREATE_DT DESC) AS VERSION_SEQ,
        TO_VARCHAR(toa.INDV_ID) AS PTY_PK,
        toa.EDG_NUM,
        toa.CASE_NUM,
        toa.MCI_CREATE_SEQ,
        toa.PROGRAM_CD,
        toa.PART_STATUS_CD,
        toa.SYSTEM_CD,
        toa.CONVERT_DT,
        toa.CREATE_DT
          FROM STG_TRS_D_CV_MCI_EDG_INDV_TOA toa
          JOIN STG_TRS_VALID_MEMBERS vm ON TO_VARCHAR(toa.INDV_ID) = vm.PTY_PK
         WHERE toa.TYPE_OF_ASSISTANCE_CD IS NOT NULL
           AND (toa.CONVERSION_IND IS NULL OR toa.CONVERSION_IND = 'C')
    )
    SELECT NULL AS PKEY_SRC_OBJECT,
           NULL AS ROWID_OBJECT,
           NULL AS DELETED_IND,
           NULL AS DELETED_DATE,
           NULL AS DELETED_BY,
           BEGIN_DT AS PERIOD_START_DATE,
           END_DT AS PERIOD_END_DATE,
           VERSION_SEQ AS VERSION_SEQ,
           NULL AS PERIOD_REFERENCE_TIME,
           :P_RUN_TS AS LAST_UPDATE_DATE,
           NULL AS UPDATED_BY,
           CREATE_DT AS CREATE_DATE,
           NULL AS CREATOR,
           NULL AS SRC_ROWID,
           NULL AS HUB_STATE_IND,
           DECODE(SRC_TBL, '             ', '    ', '            ', '     ') AS TOA_SOURCE,
           NULL AS TOA_FK,
           BEGIN_DT AS EFF_STRT_DT,
           END_DT AS EFF_END_DT,
           INDV_ID || '       ' AS PTY_RLE_FK,
           EDG_NUM AS EDG_NUM,
           CASE_NUM AS CASE_NUM,
           NVL(TO_VARCHAR(EDG_NUM), '') || ' ' || NVL(TO_VARCHAR(PROGRAM_CD), '') || ' '
               || NVL(TO_VARCHAR(MCI_CREATE_SEQ), '') AS SGMNT_KEY,
           CONVERT_DT AS CNVRT_DT,
           SYSTEM_CD AS CNVRT_SYS_CD,
           PTY_PK AS INDV_ID,
           PART_STATUS_CD AS PRTCPNT_STS_CD,
           CREATE_DT AS SRC_LAST_UPD_DT
      FROM s10_raw;
    RETURN SQLROWCOUNT;
END;
$$;
