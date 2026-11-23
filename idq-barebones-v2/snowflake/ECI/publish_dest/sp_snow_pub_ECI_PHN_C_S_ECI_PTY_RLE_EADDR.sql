-- ============================================================================
-- sp_snow_pub_ECI_PHN_C_S_ECI_PTY_RLE_EADDR.sql -- PUBLISH_DEST S10-only twin (C_S_* spine, first step only)
--
-- Twin of publish/sp_snow_pub_ECI_PHN_C_S_ECI_PTY_RLE_EADDR.sql. Same procedure, same target, same column list
-- -- but ONLY the first (source) step is inlined as a CTE (s10_src);
-- every later step (ACTIVE / DQ / ROUTED / READY / ranked / router)
-- and the WHERE gate are dropped. Each target column is aliased
-- from a first-step column, a literal, or a parameter (see map).
-- A column the first step does not carry is NULL (see map).
-- WHERE gate dropped: WHERE grp_email_good AND uq_eaddr
-- P_RUN_TS: YES
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_pub_ECI_PHN_C_S_ECI_PTY_RLE_EADDR (
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
INSERT INTO C_S_ECI_PTY_RLE_EADDR
           (PKEY_SRC_OBJECT, PERIOD_START_DATE, PERIOD_REFERENCE_TIME, LAST_UPDATE_DATE, CREATE_DATE, SRC_ROWID,
            PTY_RLE_FK, ELEC_ADDR, USG_TP, ADDR_TP, STS_CD, IS_VLD, SRC_LAST_UPD_DT, VERSION_SEQ, HUB_STATE_IND)
    WITH
    s10_src AS (
SELECT s.PERIOD_START_DATE, s.PHONE_EMAIL, s.ID_FAMILY_PHONE,
               NVL(s.PHONE_EMAIL_TYPE = 'EADDRESS', FALSE)                                    AS is_email,
               NVL(TO_VARCHAR(s.ID), '') || IFF(s.SOURCE_TABLE = 'ECI_FAMILY', 'F', '')      AS pty_src_key,
               NVL(TO_VARCHAR(s.ID), '') || IFF(s.SOURCE_TABLE = 'ECI_FAMILY', 'F', '') || '|Member' AS pty_rle_fk,
               IFF(NVL(s.PHONE_EMAIL_TYPE = 'EADDRESS', FALSE),
                       NVL(TO_VARCHAR(s.ID), '') || IFF(s.SOURCE_TABLE = 'ECI_FAMILY', 'F', '') || '|Member|001|'
                       || NVL(TO_VARCHAR(s.ID_FAMILY_PHONE), '') || '|' || NVL(TRIM(s.PHONE_EMAIL), ''),
                       NVL(TO_VARCHAR(s.ID), '') || IFF(s.SOURCE_TABLE = 'ECI_FAMILY', 'F', '') || '|Member|'
                       || NVL(s.PHONE_TP, '') || '|' || NVL(s.USG_TP, '') || '|' || NVL(TO_VARCHAR(s.ID_FAMILY_PHONE), '')
                       || '|' || NVL(TRIM(s.PHONE_EMAIL), ''))                                     AS pkey_src_object
          FROM V_ECI_ETL_SRC_FAMILY_PHONE s
    )
    SELECT PKEY_SRC_OBJECT AS PKEY_SRC_OBJECT,
           PERIOD_START_DATE AS PERIOD_START_DATE,
           NULL AS PERIOD_REFERENCE_TIME,
           :P_RUN_TS AS LAST_UPDATE_DATE,
           :P_RUN_TS AS CREATE_DATE,
           PKEY_SRC_OBJECT AS SRC_ROWID,
           PTY_RLE_FK AS PTY_RLE_FK,
           NULL AS ELEC_ADDR,
           NULL AS USG_TP,
           '001' AS ADDR_TP,
           'Active' AS STS_CD,
           'Y' AS IS_VLD,
           PERIOD_START_DATE AS SRC_LAST_UPD_DT,
           '1' AS VERSION_SEQ,
           1 AS HUB_STATE_IND
      FROM s10_src;

    l_rows := SQLROWCOUNT;
    RETURN :l_rows;
END;
$$;
