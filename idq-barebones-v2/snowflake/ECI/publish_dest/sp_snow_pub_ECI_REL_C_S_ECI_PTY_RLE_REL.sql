-- ============================================================================
-- sp_snow_pub_ECI_REL_C_S_ECI_PTY_RLE_REL.sql -- PUBLISH_DEST S10-only twin (C_S_* spine, first step only)
--
-- Twin of publish/sp_snow_pub_ECI_REL_C_S_ECI_PTY_RLE_REL.sql. Same procedure, same target, same column list
-- -- but ONLY the first (source) step is inlined as a CTE (s10_src);
-- every later step (ACTIVE / DQ / ROUTED / READY / ranked / router)
-- and the WHERE gate are dropped. Each target column is aliased
-- from a first-step column, a literal, or a parameter (see map).
-- A column the first step does not carry is NULL (see map).
-- WHERE gate dropped: WHERE mstr_ref_code IS NOT NULL AND uq_rel
-- P_RUN_TS: YES
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_pub_ECI_REL_C_S_ECI_PTY_RLE_REL (
    P_RUN_TS TIMESTAMP_NTZ
)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
    -- 50a. Valid relationships -> C_S_ECI_PTY_RLE_REL (verbatim from the main)
INSERT INTO C_S_ECI_PTY_RLE_REL
           (PTY_RLE_FK_1, PTY_RLE_FK_2, PKEY_SRC_OBJECT, VERSION_SEQ, SRC_ROWID, HUB_STATE_IND, REL_TYPE_CODE,
            HIERARCHY_CODE, REL_TP, SRC_LAST_UPD_DT, LAST_UPDATE_DATE, UPDATED_BY, CREATE_DATE, CREATOR,
            PERIOD_START_DATE)
    WITH
    s10_src AS (
SELECT d.RELATION_DIRECTION, f.ID_FAMILY, f.ID_CHILD, f.FAMILY_CD,
               COALESCE(f.DATE_MODIFIED, f.DATE_CREATED) AS DATE_MODIFIED, f.DATE_CREATED
          FROM STG_ECI_D_FAMILY f
         CROSS JOIN (SELECT column1 AS RELATION_DIRECTION FROM VALUES ('From Child'), ('To Child')) d
    )
    SELECT IFF(RELATION_DIRECTION = 'To Child', (LPAD(TO_VARCHAR(ID_FAMILY), 10, '0') || 'F'), (LPAD(TO_VARCHAR(ID_CHILD), 10, '0'))) || '|Member' AS PTY_RLE_FK_1,
           IFF(RELATION_DIRECTION = 'To Child', (LPAD(TO_VARCHAR(ID_CHILD), 10, '0')), (LPAD(TO_VARCHAR(ID_FAMILY), 10, '0') || 'F')) || '|Member' AS PTY_RLE_FK_2,
           NULL AS PKEY_SRC_OBJECT,
           1 AS VERSION_SEQ,
           NULL AS SRC_ROWID,
           1 AS HUB_STATE_IND,
           'Member Relationship' AS REL_TYPE_CODE,
           'Member' AS HIERARCHY_CODE,
           NULL AS REL_TP,
           DATE_MODIFIED AS SRC_LAST_UPD_DT,
           :P_RUN_TS AS LAST_UPDATE_DATE,
           'm_Tgt_C_S_ECI_Pty_Rle_Rel' AS UPDATED_BY,
           DATE_MODIFIED AS CREATE_DATE,
           'm_Tgt_C_S_ECI_Pty_Rle_Rel' AS CREATOR,
           DATE_CREATED AS PERIOD_START_DATE
      FROM s10_src;

    RETURN SQLROWCOUNT;
END;
$$;
