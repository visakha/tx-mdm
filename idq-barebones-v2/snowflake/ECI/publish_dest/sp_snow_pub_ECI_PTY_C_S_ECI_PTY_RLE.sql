-- ============================================================================
-- sp_snow_pub_ECI_PTY_C_S_ECI_PTY_RLE.sql -- PUBLISH_DEST S10-only twin (C_S_* spine, first step only)
--
-- Twin of publish/sp_snow_pub_ECI_PTY_C_S_ECI_PTY_RLE.sql. Same procedure, same target, same column list
-- -- but ONLY the first (source) step is inlined as a CTE (s10_src);
-- every later step (ACTIVE / DQ / ROUTED / READY / ranked / router)
-- and the WHERE gate are dropped. Each target column is aliased
-- from a first-step column, a literal, or a parameter (see map).
-- A column the first step does not carry is NULL (see map).
-- WHERE gate dropped: WHERE uq_rle
-- P_RUN_TS: YES
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_pub_ECI_PTY_C_S_ECI_PTY_RLE (
    P_RUN_TS TIMESTAMP_NTZ
)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
INSERT INTO C_S_ECI_PTY_RLE
           (PKEY_SRC_OBJECT, LAST_UPDATE_DATE, CREATOR, CREATE_DATE, VERSION_SEQ, PTY_FK, SRC_LAST_UPD_DT,
            RLE_BO_CLASS_CD, PERIOD_START_DATE, HUB_STATE_IND, SRC_ROWID)
    WITH
    s10_src AS (
WITH
        src AS (
            SELECT 'ECI_CHILD' AS SOURCE_TABLE, child.ID_CHILD AS ID, child.DATE_CREATED AS DATE_CREATED, COALESCE(child.DATE_MODIFIED, child.DATE_CREATED) AS DATE_MODIFIED, child.CREATED_BY AS CREATED_BY
              FROM STG_ECI_D_CHILD child
            UNION ALL
            SELECT 'ECI_FAMILY', fam.ID_FAMILY, fam.DATE_CREATED, COALESCE(fam.DATE_MODIFIED, fam.DATE_CREATED), fam.CREATED_BY
              FROM STG_ECI_D_FAMILY fam
        )
        SELECT s.ID, s.DATE_CREATED, s.DATE_MODIFIED, s.CREATED_BY,
               LPAD(TO_VARCHAR(s.ID), 10, '0') || IFF(s.SOURCE_TABLE = 'ECI_FAMILY', 'F', '')  AS pkey_src_object,
               'ECI'  AS src_system
          FROM src s
    )
    SELECT TRIM(PKEY_SRC_OBJECT) || '|' || 'Member' AS PKEY_SRC_OBJECT,
           :P_RUN_TS AS LAST_UPDATE_DATE,
           CREATED_BY AS CREATOR,
           DATE_CREATED AS CREATE_DATE,
           1 AS VERSION_SEQ,
           TRIM(PKEY_SRC_OBJECT) AS PTY_FK,
           DATE_MODIFIED AS SRC_LAST_UPD_DT,
           'Member' AS RLE_BO_CLASS_CD,
           DATE_CREATED AS PERIOD_START_DATE,
           1 AS HUB_STATE_IND,
           TRIM(PKEY_SRC_OBJECT) || '|' || 'Member' AS SRC_ROWID
      FROM s10_src;

    RETURN SQLROWCOUNT;
END;
$$;
