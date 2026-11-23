-- ============================================================================
-- sp_snow_pub_ECI_PHN_C_S_ECI_PTY_RLE_PHN.sql -- PUBLISH_DEST S10-only twin (C_S_* spine, first step only)
--
-- Twin of publish/sp_snow_pub_ECI_PHN_C_S_ECI_PTY_RLE_PHN.sql. Same procedure, same target, same column list
-- -- but ONLY the first (source) step is inlined as a CTE (s10_src);
-- every later step (ACTIVE / DQ / ROUTED / READY / ranked / router)
-- and the WHERE gate are dropped. Each target column is aliased
-- from a first-step column, a literal, or a parameter (see map).
-- A column the first step does not carry is NULL (see map).
-- WHERE gate dropped: WHERE grp_phone_good AND uq_phn
-- P_RUN_TS: YES
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_pub_ECI_PHN_C_S_ECI_PTY_RLE_PHN (
    P_RUN_TS TIMESTAMP_NTZ
)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    l_rows    NUMBER DEFAULT 0;
BEGIN
INSERT INTO C_S_ECI_PTY_RLE_PHN
           (PKEY_SRC_OBJECT, PERIOD_START_DATE, VERSION_SEQ, LAST_UPDATE_DATE, CREATE_DATE, SRC_ROWID,
            PTY_RLE_FK, PHN_TP, USG_TP, PHN_NUM, PREF_LVL, SRC_LAST_UPD_DT, PHN_NUM_EXT, HUB_STATE_IND)
    WITH
    s10_src AS (
SELECT s.WORK_EXT, s.PHONE_TP, s.USG_TP, s.PREF_LVL, s.PERIOD_START_DATE, s.PHONE_EMAIL, s.ID_FAMILY_PHONE,
               NVL(s.PHONE_EMAIL_TYPE = 'EADDRESS', FALSE)                                    AS is_email,
               NVL(TO_VARCHAR(s.ID), '') || IFF(s.SOURCE_TABLE = 'ECI_FAMILY', 'F', '')      AS pty_src_key,
               NVL(TO_VARCHAR(s.ID), '') || IFF(s.SOURCE_TABLE = 'ECI_FAMILY', 'F', '') || '|Member' AS pty_rle_fk,
               IFF(NVL(s.PHONE_EMAIL_TYPE = 'EADDRESS', FALSE),
                       NVL(TO_VARCHAR(s.ID), '') || IFF(s.SOURCE_TABLE = 'ECI_FAMILY', 'F', '') || '|Member|001|'
                       || NVL(TO_VARCHAR(s.ID_FAMILY_PHONE), '') || '|' || NVL(TRIM(s.PHONE_EMAIL), ''),
                       NVL(TO_VARCHAR(s.ID), '') || IFF(s.SOURCE_TABLE = 'ECI_FAMILY', 'F', '') || '|Member|'
                       || NVL(s.PHONE_TP, '') || '|' || NVL(s.USG_TP, '') || '|' || NVL(TO_VARCHAR(s.ID_FAMILY_PHONE), '')
                       || '|' || NVL(TRIM(s.PHONE_EMAIL), ''))                                     AS pkey_src_object,
               IFF(NVL(s.PHONE_EMAIL_TYPE = 'EADDRESS', FALSE),
                       NVL(TO_VARCHAR(s.ID), '') || IFF(s.SOURCE_TABLE = 'ECI_FAMILY', 'F', '') || '|Member|001|'
                       || NVL(TO_VARCHAR(s.ID_FAMILY_PHONE), '') || '|' || NVL(s.PHONE_EMAIL, ''),
                       NVL(TO_VARCHAR(s.ID), '') || IFF(s.SOURCE_TABLE = 'ECI_FAMILY', 'F', '') || '|Member|'
                       || NVL(s.PHONE_TP, '') || '|' || NVL(s.USG_TP, '') || '|' || NVL(TO_VARCHAR(s.ID_FAMILY_PHONE), '')
                       || '|' || NVL(s.PHONE_EMAIL, ''))                                           AS src_rowid
          FROM V_ECI_ETL_SRC_FAMILY_PHONE s
    )
    SELECT PKEY_SRC_OBJECT AS PKEY_SRC_OBJECT,
           PERIOD_START_DATE AS PERIOD_START_DATE,
           '1' AS VERSION_SEQ,
           :P_RUN_TS AS LAST_UPDATE_DATE,
           :P_RUN_TS AS CREATE_DATE,
           SRC_ROWID AS SRC_ROWID,
           PTY_RLE_FK AS PTY_RLE_FK,
           PHONE_TP AS PHN_TP,
           USG_TP AS USG_TP,
           (IFF(LENGTH(PHONE_EMAIL) = 7, '000' || PHONE_EMAIL, PHONE_EMAIL)) AS PHN_NUM,
           PREF_LVL AS PREF_LVL,
           PERIOD_START_DATE AS SRC_LAST_UPD_DT,
           WORK_EXT AS PHN_NUM_EXT,
           1 AS HUB_STATE_IND
      FROM s10_src;

    l_rows := SQLROWCOUNT;
    RETURN :l_rows;
END;
$$;
