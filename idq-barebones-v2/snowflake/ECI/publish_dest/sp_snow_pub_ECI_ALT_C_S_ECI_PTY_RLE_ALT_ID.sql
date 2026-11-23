-- ============================================================================
-- sp_snow_pub_ECI_ALT_C_S_ECI_PTY_RLE_ALT_ID.sql -- PUBLISH_DEST S10-only twin (C_S_* spine, first step only)
--
-- Twin of publish/sp_snow_pub_ECI_ALT_C_S_ECI_PTY_RLE_ALT_ID.sql. Same procedure, same target, same column list
-- -- but ONLY the first (source) step is inlined as a CTE (s10_src);
-- every later step (ACTIVE / DQ / ROUTED / READY / ranked / router)
-- and the WHERE gate are dropped. Each target column is aliased
-- from a first-step column, a literal, or a parameter (see map).
-- A column the first step does not carry is NULL (see map).
-- WHERE gate dropped: WHERE grp_valid AND uq_alt_id
-- P_RUN_TS: YES
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_pub_ECI_ALT_C_S_ECI_PTY_RLE_ALT_ID (
    P_RUN_TS TIMESTAMP_NTZ
)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    l_rows       NUMBER DEFAULT 0;
BEGIN
    -- ---- Publish branch 50a: valid alternate ids -> C_S_ECI_PTY_RLE_ALT_ID (SPINE, verbatim)
INSERT INTO C_S_ECI_PTY_RLE_ALT_ID
           (PTY_RLE_FK, ALT_ID_TP, ALT_ID_VAL, CREATE_DATE, LAST_UPDATE_DATE, PKEY_SRC_OBJECT, SRC_ROWID,
            VERSION_SEQ, STS_CD, HUB_STATE_IND, SRC_LAST_UPD_DT, ALT_ID_TP_FLTR, PERIOD_START_DATE)
    WITH
    s10_src AS (
SELECT ID_CHILD AS ID, LPAD(TO_VARCHAR(ID_CHILD), 10, '0') || '|Member' AS PTY_REL_FK,
               '018' AS ALT_ID_TP,
               LPAD(TO_VARCHAR(ID_CHILD), 10, '0') AS ALT_ID_VAL, DATE_CREATED, DATE_MODIFIED,
               LPAD(TO_VARCHAR(ID_CHILD), 10, '0') || '|Member' || '|018' || '|'
               || LPAD(TO_VARCHAR(ID_CHILD), 10, '0') AS PKEY_SRC_OBJECT
          FROM STG_ECI_D_CHILD
        UNION ALL
        SELECT ID_CHILD, LPAD(TO_VARCHAR(ID_CHILD), 10, '0') || '|Member',
               '004', CHILD_SSN, DATE_CREATED, DATE_MODIFIED,
               LPAD(TO_VARCHAR(ID_CHILD), 10, '0') || '|Member' || '|004' || '|' || LPAD(TO_VARCHAR(ID_CHILD), 10, '0')
          FROM STG_ECI_D_CHILD
         WHERE CHILD_SSN IS NOT NULL
        UNION ALL
        SELECT C.ID_CHILD, LPAD(TO_VARCHAR(C.ID_CHILD), 10, '0') || '|Member',
               '002', M.MEDICAID_NBR, M.DATE_CREATED, M.DATE_MODIFIED,
               LPAD(TO_VARCHAR(C.ID_CHILD), 10, '0') || '|Member' || '|002' || '|' || LPAD(TO_VARCHAR(M.ID_MEDICAID), 10, '0')
          FROM STG_ECI_D_MEDICAID M
         INNER JOIN STG_ECI_SN_CASE C ON M.ID_CASE = C.ID_CASE
        UNION ALL
        SELECT ID_FAMILY, LPAD(TO_VARCHAR(ID_FAMILY), 10, '0') || 'F|Member',
               '019', LPAD(TO_VARCHAR(ID_FAMILY), 10, '0'), DATE_CREATED, DATE_MODIFIED,
               LPAD(TO_VARCHAR(ID_FAMILY), 10, '0') || 'F|Member' || '|019' || '|' || LPAD(TO_VARCHAR(ID_FAMILY), 10, '0')
          FROM STG_ECI_D_FAMILY
    )
    SELECT PTY_REL_FK AS PTY_RLE_FK,
           ALT_ID_TP AS ALT_ID_TP,
           ALT_ID_VAL AS ALT_ID_VAL,
           DATE_CREATED AS CREATE_DATE,
           :P_RUN_TS AS LAST_UPDATE_DATE,
           PKEY_SRC_OBJECT AS PKEY_SRC_OBJECT,
           TO_VARCHAR(ID) || '|' || ALT_ID_TP AS SRC_ROWID,
           1 AS VERSION_SEQ,
           'Issued' AS STS_CD,
           1 AS HUB_STATE_IND,
           NVL(DATE_MODIFIED, DATE_CREATED) AS SRC_LAST_UPD_DT,
           ALT_ID_TP AS ALT_ID_TP_FLTR,
           DATE_CREATED AS PERIOD_START_DATE
      FROM s10_src;

    l_rows := SQLROWCOUNT;
    RETURN :l_rows;
END;
$$;
