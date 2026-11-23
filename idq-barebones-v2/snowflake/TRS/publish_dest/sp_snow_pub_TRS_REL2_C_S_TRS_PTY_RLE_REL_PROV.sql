-- ============================================================================
-- sp_snow_pub_TRS_REL2_C_S_TRS_PTY_RLE_REL_PROV.sql -- PUBLISH_DEST S10-only twin (C_S_* spine, first step only)
--
-- Twin of publish/sp_snow_pub_TRS_REL2_C_S_TRS_PTY_RLE_REL_PROV.sql. Same procedure, same target, same column list
-- -- but ONLY the first (source) step is inlined as a CTE (s1_src);
-- every later step (ACTIVE / DQ / ROUTED / READY / ranked / router)
-- and the WHERE gate are dropped. Each target column is aliased
-- from a first-step column, a literal, or a parameter (see map).
-- A column the first step does not carry is NULL (see map).
-- WHERE gate dropped: WHERE uq_rel
-- P_RUN_TS: YES
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_pub_TRS_REL2_C_S_TRS_PTY_RLE_REL_PROV (

    P_PCP_REL_TP VARCHAR DEFAULT '100',
    P_RUN_TS       TIMESTAMP_NTZ DEFAULT NULL

)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
INSERT INTO C_S_TRS_PTY_RLE_REL_PROV
           (PKEY_SRC_OBJECT, PERIOD_START_DATE, PERIOD_END_DATE, VERSION_SEQ, LAST_UPDATE_DATE, CREATE_DATE,
            SRC_ROWID, HUB_STATE_IND, PTY_RLE_FK_1, PTY_RLE_FK_2, REL_TYPE_CODE, HIERARCHY_CODE, REL_TP,
            SRC_LAST_UPD_DT, PERIOD_REFERENCE_TIME, TIMELINE_ACTION, ROWID_OBJECT, DELETED_IND, DELETED_DATE,
            DELETED_BY, UPDATED_BY, CREATOR)
    WITH
    s1_src AS (
WITH
        min_pk AS (
            SELECT indv_id,
        MIN(pty_pk) pty_pk FROM STG_TRS_VALID_MEMBERS GROUP BY indv_id
        )
        SELECT mc.begin_dt AS BEGIN_DT,
        mc.create_dt AS CREATE_DT,
        mc.provider_num AS PROVIDER_NUM,
        mc.end_dt AS END_DT,
        vm.pty_pk AS PTY_PK
          FROM STG_TRS_D_IN_MANAGED_CARE mc
          JOIN min_pk vm ON mc.indv_id = vm.indv_id
         WHERE mc.provider_num IS NOT NULL
           AND fn_snow_helper01_common(mc.provider_num) = 1
    )
    SELECT NULL AS PKEY_SRC_OBJECT,
           BEGIN_DT AS PERIOD_START_DATE,
           BEGIN_DT AS PERIOD_END_DATE,
           '1' AS VERSION_SEQ,
           :P_RUN_TS AS LAST_UPDATE_DATE,
           NULL AS CREATE_DATE,
           NULL AS SRC_ROWID,
           1 AS HUB_STATE_IND,
           IFF(PTY_PK IS NULL, NULL, TRIM(PTY_PK) || '       ') AS PTY_RLE_FK_1,
           NULL AS PTY_RLE_FK_2,
           NULL AS REL_TYPE_CODE,
           'Member' AS HIERARCHY_CODE,
           :P_PCP_REL_TP AS REL_TP,
           CREATE_DT AS SRC_LAST_UPD_DT,
           BEGIN_DT AS PERIOD_REFERENCE_TIME,
           IFF(BEGIN_DT IS NOT NULL, 2, NULL) AS TIMELINE_ACTION,
           NULL AS ROWID_OBJECT,
           NULL AS DELETED_IND,
           NULL AS DELETED_DATE,
           NULL AS DELETED_BY,
           NULL AS UPDATED_BY,
           NULL AS CREATOR
      FROM s1_src;
    RETURN SQLROWCOUNT;
END;
$$;
