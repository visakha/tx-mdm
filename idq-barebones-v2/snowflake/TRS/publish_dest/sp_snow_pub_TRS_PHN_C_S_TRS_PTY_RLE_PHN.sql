-- ============================================================================
-- sp_snow_pub_TRS_PHN_C_S_TRS_PTY_RLE_PHN.sql -- PUBLISH_DEST S10-only twin (C_S_* spine, first step only)
--
-- Twin of publish/sp_snow_pub_TRS_PHN_C_S_TRS_PTY_RLE_PHN.sql. Same procedure, same target, same column list
-- -- but ONLY the first (source) step is inlined as a CTE (s1_src);
-- every later step (ACTIVE / DQ / ROUTED / READY / ranked / router)
-- and the WHERE gate are dropped. Each target column is aliased
-- from a first-step column, a literal, or a parameter (see map).
-- A column the first step does not carry is NULL (see map).
-- WHERE gate dropped: WHERE rn = 1 AND uq_tgt
-- P_RUN_TS: YES
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_pub_TRS_PHN_C_S_TRS_PTY_RLE_PHN (

    P_RUN_TS       TIMESTAMP_NTZ DEFAULT NULL

)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
INSERT INTO C_S_TRS_PTY_RLE_PHN
           (PKEY_SRC_OBJECT, ROWID_OBJECT, DELETED_IND, DELETED_DATE, DELETED_BY, PERIOD_START_DATE, VERSION_SEQ,
            PERIOD_REFERENCE_TIME, TIMELINE_ACTION, LAST_UPDATE_DATE, UPDATED_BY, CREATE_DATE, CREATOR, SRC_ROWID,
            HUB_STATE_IND, PTY_RLE_FK, USG_TP, PHN_TP, PHN_NUM, PREF_LVL, PERIOD_END_DATE, SRC_LAST_UPD_DT)
    WITH
    s1_src AS (
SELECT DISTINCT C.CASE_NUM,
        C.CREATE_DT,
        C.WORK_PH_NUM,
        C.OTHER_PH_NUM,
        C.PH_NUM,
        C.WORK_PH_NUM_EXT,
        TO_VARCHAR(I.INDV_ID) AS PTY_PK
          FROM STG_TRS_D_DC_CASES C
          JOIN STG_TRS_DC_CASE_INDV I ON C.CASE_NUM = I.CASE_NUM
          JOIN STG_TRS_VALID_MEMBERS VM ON TO_VARCHAR(I.INDV_ID) = VM.PTY_PK
    )
    SELECT NULL AS PKEY_SRC_OBJECT,
           NULL AS ROWID_OBJECT,
           NULL AS DELETED_IND,
           NULL AS DELETED_DATE,
           NULL AS DELETED_BY,
           NULL AS PERIOD_START_DATE,
           '1' AS VERSION_SEQ,
           NULL AS PERIOD_REFERENCE_TIME,
           NULL AS TIMELINE_ACTION,
           :P_RUN_TS AS LAST_UPDATE_DATE,
           NULL AS UPDATED_BY,
           NULL AS CREATE_DATE,
           NULL AS CREATOR,
           NULL AS SRC_ROWID,
           NULL AS HUB_STATE_IND,
           NULL AS PTY_RLE_FK,
           NULL AS USG_TP,
           NULL AS PHN_TP,
           NULL AS PHN_NUM,
           NULL AS PREF_LVL,
           NULL AS PERIOD_END_DATE,
           NULL AS SRC_LAST_UPD_DT
      FROM s1_src;
    RETURN SQLROWCOUNT;
END;
$$;
