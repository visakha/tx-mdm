-- ============================================================================
-- sp_snow_pub_TRS_REL1_C_S_TRS_PTY_RLE_REL.sql -- PUBLISH_DEST S10-only twin (C_S_* spine, first step only)
--
-- Twin of publish/sp_snow_pub_TRS_REL1_C_S_TRS_PTY_RLE_REL.sql. Same procedure, same target, same column list
-- -- but ONLY the first (source) step is inlined as a CTE (s1_src);
-- every later step (ACTIVE / DQ / ROUTED / READY / ranked / router)
-- and the WHERE gate are dropped. Each target column is aliased
-- from a first-step column, a literal, or a parameter (see map).
-- A column the first step does not carry is NULL (see map).
-- WHERE gate dropped: WHERE uq_rel
-- P_RUN_TS: YES
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_pub_TRS_REL1_C_S_TRS_PTY_RLE_REL (

    P_RUN_TS       TIMESTAMP_NTZ DEFAULT NULL

)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
INSERT INTO C_S_TRS_PTY_RLE_REL
           (PKEY_SRC_OBJECT, ROWID_OBJECT, DELETED_IND, DELETED_DATE, DELETED_BY, PERIOD_START_DATE,
            PERIOD_END_DATE, VERSION_SEQ, PERIOD_REFERENCE_TIME, TIMELINE_ACTION, LAST_UPDATE_DATE, UPDATED_BY,
            CREATE_DATE, CREATOR, SRC_ROWID, HUB_STATE_IND, PTY_RLE_FK_1, PTY_RLE_FK_2, REL_TYPE_CODE,
            HIERARCHY_CODE, REL_TP, SRC_LAST_UPD_DT)
    WITH
    s1_src AS (
WITH
        min_pk AS (
            SELECT indv_id,
        MIN(pty_pk) pty_pk FROM STG_TRS_VALID_MEMBERS GROUP BY indv_id
        )
        SELECT rel.eff_begin_dt AS EFF_BEGIN_DT,
        rel.eff_end_dt AS EFF_END_DT,
        rel.relationship_type_cd AS RELATIONSHIP_TYPE_CD,
        pk1.pty_pk AS PTY_PKEY,
        pk2.pty_pk AS REF_PTY_PKEY,
        rel.create_dt AS CREATE_DT,
        rel.update_dt AS UPDATE_DT
          FROM STG_TRS_D_DC_RELATIONSHIPS rel
          JOIN min_pk pk1 ON rel.indv_id = pk1.indv_id
          JOIN min_pk pk2 ON rel.ref_indv_id = pk2.indv_id
    )
    SELECT NULL AS PKEY_SRC_OBJECT,
           NULL AS ROWID_OBJECT,
           NULL AS DELETED_IND,
           NULL AS DELETED_DATE,
           NULL AS DELETED_BY,
           EFF_BEGIN_DT AS PERIOD_START_DATE,
           EFF_BEGIN_DT AS PERIOD_END_DATE,
           '1' AS VERSION_SEQ,
           EFF_BEGIN_DT AS PERIOD_REFERENCE_TIME,
           IFF(EFF_BEGIN_DT IS NOT NULL, 2, NULL) AS TIMELINE_ACTION,
           :P_RUN_TS AS LAST_UPDATE_DATE,
           NULL AS UPDATED_BY,
           CREATE_DT AS CREATE_DATE,
           NULL AS CREATOR,
           NULL AS SRC_ROWID,
           1 AS HUB_STATE_IND,
           IFF(PTY_PKEY IS NULL, NULL, TRIM(PTY_PKEY) || '       ') AS PTY_RLE_FK_1,
           IFF(REF_PTY_PKEY IS NULL, NULL, TRIM(REF_PTY_PKEY) || '       ') AS PTY_RLE_FK_2,
           NULL AS REL_TYPE_CODE,
           NULL AS HIERARCHY_CODE,
           NULL AS REL_TP,
           IFF(CREATE_DT IS NOT NULL AND UPDATE_DT IS NOT NULL, GREATEST(CREATE_DT, UPDATE_DT),
                   NVL(CREATE_DT, UPDATE_DT)) AS SRC_LAST_UPD_DT
      FROM s1_src;
    RETURN SQLROWCOUNT;
END;
$$;
