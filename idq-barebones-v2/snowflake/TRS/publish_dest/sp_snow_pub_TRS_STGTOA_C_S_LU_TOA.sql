-- ============================================================================
-- sp_snow_pub_TRS_STGTOA_C_S_LU_TOA.sql -- PUBLISH_DEST S10-only twin (C_S_* spine, first step only)
--
-- Twin of publish/sp_snow_pub_TRS_STGTOA_C_S_LU_TOA.sql. Same procedure, same target, same column list
-- -- but ONLY the first (source) step is inlined as a CTE (s10_keyed);
-- every later step (ACTIVE / DQ / ROUTED / READY / ranked / router)
-- and the WHERE gate are dropped. Each target column is aliased
-- from a first-step column, a literal, or a parameter (see map).
-- A column the first step does not carry is NULL (see map).
-- WHERE gate dropped: none (no gate in original)
-- P_RUN_TS: YES
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_pub_TRS_STGTOA_C_S_LU_TOA (

    P_RUN_TS       TIMESTAMP_NTZ DEFAULT NULL

)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
INSERT INTO C_S_LU_TOA
           (PKEY_SRC_OBJECT, ROWID_OBJECT, DELETED_IND, DELETED_DATE, DELETED_BY, PERIOD_START_DATE, PERIOD_END_DATE,
            VERSION_SEQ, PERIOD_REFERENCE_TIME, LAST_UPDATE_DATE, UPDATED_BY, CREATE_DATE, CREATOR, SRC_ROWID,
            HUB_STATE_IND, TOA_CD, TOA_LBL, TOA_DESC, MBR_PRG_CD, EFF_STRT_DT, EFF_END_DT)
    WITH
    s10_keyed AS (
WITH
        lkp_toa AS (
            SELECT l.MSTR_REF_LABEL,
        l.MSTR_REF_CODE FROM LOOKUP_CODE_VALUE l
             WHERE l.CODE_TYPE = 'TOA'
            QUALIFY ROW_NUMBER() OVER (PARTITION BY l.MSTR_REF_LABEL ORDER BY l.MSTR_REF_CODE) = 1
        ),
        lkp_pgm AS (
            SELECT l.MSTR_REF_LABEL,
        l.MSTR_REF_CODE FROM LOOKUP_CODE_VALUE l
             WHERE l.CODE_TYPE = 'MEMBER_PRG'
            QUALIFY ROW_NUMBER() OVER (PARTITION BY l.MSTR_REF_LABEL ORDER BY l.MSTR_REF_CODE) = 1
        )
        SELECT S.TOA_DESC,
        S.EFF_BEGIN_DT,
        S.EFF_END_DT,
        S.UNIQUE_TRANS_ID,
        S.CREATE_DT,
        S.UPDATE_USER_ID,
        S.UPDATE_DT,
        SUBSTR(lt.MSTR_REF_CODE, 1, 10) AS pkey_src_object,
        lt.MSTR_REF_LABEL AS toa_lbl,
        SUBSTR(lp.MSTR_REF_CODE, 1, 9) AS mbr_prg_cd
          FROM STG_TRS_D_LU_TOA s
          LEFT JOIN lkp_toa lt ON lt.MSTR_REF_LABEL = s.TOA_CODE
          LEFT JOIN lkp_pgm lp ON lp.MSTR_REF_LABEL = s.PROGRAM_CODE
    )
    SELECT PKEY_SRC_OBJECT AS PKEY_SRC_OBJECT,
           NULL AS ROWID_OBJECT,
           NULL AS DELETED_IND,
           NULL AS DELETED_DATE,
           NULL AS DELETED_BY,
           NULL AS PERIOD_START_DATE,
           NULL AS PERIOD_END_DATE,
           1 AS VERSION_SEQ,
           NULL AS PERIOD_REFERENCE_TIME,
           :P_RUN_TS AS LAST_UPDATE_DATE,
           SUBSTR(UPDATE_USER_ID, 1, 50) AS UPDATED_BY,
           CREATE_DT AS CREATE_DATE,
           'admin' AS CREATOR,
           SUBSTR(PKEY_SRC_OBJECT, 1, 30) AS SRC_ROWID,
           1 AS HUB_STATE_IND,
           PKEY_SRC_OBJECT AS TOA_CD,
           SUBSTR(TOA_LBL, 1, 100) AS TOA_LBL,
           SUBSTR(TOA_DESC, 1, 250) AS TOA_DESC,
           MBR_PRG_CD AS MBR_PRG_CD,
           EFF_BEGIN_DT AS EFF_STRT_DT,
           EFF_END_DT AS EFF_END_DT
      FROM s10_keyed;
    RETURN SQLROWCOUNT;
END;
$$;
