-- ============================================================================
-- sp_snow_pub_TRS_PLN_C_S_TRS_PTY_RLE_PLN.sql -- PUBLISH_DEST S10-only twin (C_S_* spine, first step only)
--
-- Twin of publish/sp_snow_pub_TRS_PLN_C_S_TRS_PTY_RLE_PLN.sql. Same procedure, same target, same column list
-- -- but ONLY the first (source) step is inlined as a CTE (s10_src);
-- every later step (ACTIVE / DQ / ROUTED / READY / ranked / router)
-- and the WHERE gate are dropped. Each target column is aliased
-- from a first-step column, a literal, or a parameter (see map).
-- A column the first step does not carry is NULL (see map).
-- WHERE gate dropped: WHERE pln_mstr_cd IS NOT NULL AND rn_key = 1 AND uq_pln
-- P_RUN_TS: YES
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_pub_TRS_PLN_C_S_TRS_PTY_RLE_PLN (
    P_RUN_TS TIMESTAMP_NTZ
)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
INSERT INTO C_S_TRS_PTY_RLE_PLN
           (PKEY_SRC_OBJECT, PERIOD_START_DATE, PERIOD_END_DATE, VERSION_SEQ, LAST_UPDATE_DATE, PTY_RLE_FK,
            PLN_FK, UPDATED_BY, CREATOR, HUB_STATE_IND, ROWID_OBJECT, DELETED_IND, DELETED_DATE, DELETED_BY,
            SRC_ROWID, CREATE_DATE, SRC_LAST_UPD_DT)
    WITH
    s10_src AS (
SELECT DISTINCT M.INDV_ID AS INDV_ID,
        M.BEGIN_DT,
        M.MC_PLAN,
        M.END_DT,
        M.CREATE_DT
          FROM STG_TRS_D_IN_MANAGED_CARE M
          JOIN STG_TRS_VALID_MEMBERS VM ON M.INDV_ID = VM.INDV_ID AND VM.SRC_TBL = 'MCI'
         WHERE M.MC_PLAN IS NOT NULL
           AND (M.BEGIN_DT < M.END_DT OR M.END_DT IS NULL)
    )
    SELECT NULL AS PKEY_SRC_OBJECT,
           BEGIN_DT AS PERIOD_START_DATE,
           END_DT AS PERIOD_END_DATE,
           1 AS VERSION_SEQ,
           :P_RUN_TS AS LAST_UPDATE_DATE,
           TO_VARCHAR(INDV_ID) || '       ' AS PTY_RLE_FK,
           NULL AS PLN_FK,
           NULL AS UPDATED_BY,
           NULL AS CREATOR,
           NULL AS HUB_STATE_IND,
           NULL AS ROWID_OBJECT,
           NULL AS DELETED_IND,
           NULL AS DELETED_DATE,
           NULL AS DELETED_BY,
           NULL AS SRC_ROWID,
           :P_RUN_TS AS CREATE_DATE,
           CREATE_DT AS SRC_LAST_UPD_DT
      FROM s10_src;
    RETURN SQLROWCOUNT;
END;
$$;
