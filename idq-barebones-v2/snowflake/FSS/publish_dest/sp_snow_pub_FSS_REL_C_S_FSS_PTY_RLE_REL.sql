-- ============================================================================
-- sp_snow_pub_FSS_REL_C_S_FSS_PTY_RLE_REL.sql -- PUBLISH_DEST S10-only twin (C_S_* spine, first step only)
--
-- Twin of publish/sp_snow_pub_FSS_REL_C_S_FSS_PTY_RLE_REL.sql. Same procedure, same target, same column list
-- -- but ONLY the first (source) step is inlined as a CTE (s1_src);
-- every later step (ACTIVE / DQ / ROUTED / READY / ranked / router)
-- and the WHERE gate are dropped. Each target column is aliased
-- from a first-step column, a literal, or a parameter (see map).
-- A column the first step does not carry is NULL (see map).
-- WHERE gate dropped: WHERE mstr_ref_code IS NOT NULL AND uq_rel
-- P_RUN_TS: YES
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_pub_FSS_REL_C_S_FSS_PTY_RLE_REL (
    P_RUN_TS TIMESTAMP_NTZ
)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
INSERT INTO C_S_FSS_PTY_RLE_REL
           (REL_TP, VERSION_SEQ, HUB_STATE_IND, REL_TYPE_CODE, HIERARCHY_CODE, UPDATED_BY, LAST_UPDATE_DATE,
            PERIOD_START_DATE, PKEY_SRC_OBJECT, PTY_RLE_FK_1, PTY_RLE_FK_2, SRC_LAST_UPD_DT, CREATOR, SRC_ROWID,
            CREATE_DATE)
    WITH
    s1_src AS (
SELECT r.RELATION_DIRECTION,
       r.RELN_DT_LAST_UPDATE,
       r.RELN_DT_CREATED,
       r.CD_RELTSHP_TO_TC,
       r.PTY_SRC_KEY,
       r.RELN_PTY_SRC_KEY,
       r.RELN_CD_GENDER,
       r.CD_GENDER,
       r.ID_REGISTRATION
FROM v_fss_etl_src_relations r
WHERE NOT EXISTS (SELECT 1 FROM STG_FSS_PTY_INACTIVE_STS i
                        WHERE i.SRC_KEY = r.PTY_SRC_KEY AND i.ROWID_SYSTEM = 'FSS'
                          AND i.DEACTIVATION_STS IS NOT NULL)
       AND NOT EXISTS (SELECT 1 FROM STG_FSS_PTY_INACTIVE_STS i
                        WHERE i.SRC_KEY = r.RELN_PTY_SRC_KEY AND i.ROWID_SYSTEM = 'FSS'
                          AND i.DEACTIVATION_STS IS NOT NULL)
    )
    SELECT NULL AS REL_TP,
           1 AS VERSION_SEQ,
           1 AS HUB_STATE_IND,
           'Member Relationship' AS REL_TYPE_CODE,
           'Member' AS HIERARCHY_CODE,
           'batchload' AS UPDATED_BY,
           :P_RUN_TS AS LAST_UPDATE_DATE,
           RELN_DT_CREATED AS PERIOD_START_DATE,
           NULL AS PKEY_SRC_OBJECT,
           NVL(IFF(RELATION_DIRECTION = 'To Child', RELN_PTY_SRC_KEY, PTY_SRC_KEY), '') || '|Member' AS PTY_RLE_FK_1,
           NVL(IFF(RELATION_DIRECTION = 'To Child', PTY_SRC_KEY, RELN_PTY_SRC_KEY), '') || '|Member' AS PTY_RLE_FK_2,
           RELN_DT_LAST_UPDATE AS SRC_LAST_UPD_DT,
           'batchload' AS CREATOR,
           NULL AS SRC_ROWID,
           RELN_DT_LAST_UPDATE AS CREATE_DATE
      FROM s1_src;
    RETURN SQLROWCOUNT;
END;
$$;
