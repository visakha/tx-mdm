-- ============================================================================
-- sp_snow_pub_FSS_PHN_C_S_FSS_PTY_RLE_EADDR.sql -- PUBLISH_DEST S10-only twin (C_S_* spine, first step only)
--
-- Twin of publish/sp_snow_pub_FSS_PHN_C_S_FSS_PTY_RLE_EADDR.sql. Same procedure, same target, same column list
-- -- but ONLY the first (source) step is inlined as a CTE (s1_src);
-- every later step (ACTIVE / DQ / ROUTED / READY / ranked / router)
-- and the WHERE gate are dropped. Each target column is aliased
-- from a first-step column, a literal, or a parameter (see map).
-- A column the first step does not carry is NULL (see map).
-- WHERE gate dropped: WHERE grp_email_good AND uq_eaddr
-- P_RUN_TS: YES
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_pub_FSS_PHN_C_S_FSS_PTY_RLE_EADDR (
    P_RUN_TS TIMESTAMP_NTZ
)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
INSERT INTO C_S_FSS_PTY_RLE_EADDR
           (PKEY_SRC_OBJECT, PERIOD_START_DATE, VERSION_SEQ, LAST_UPDATE_DATE, CREATE_DATE, SRC_ROWID,
            HUB_STATE_IND, PTY_RLE_FK, ADDR_TP, USG_TP, ELEC_ADDR, STS_CD, IS_VLD, SRC_LAST_UPD_DT)
    WITH
    s1_src AS (
SELECT v.ADDR_EMAIL,
       v.ID_REGISTRATION_CLIENT,
       v.DT_LAST_UPDATE,
       NVL(v.PTY_SRC_KEY, '') || '|Member'                                             AS pty_rle_fk,
       NVL(v.PTY_SRC_KEY, '') || '|Member|001|' || NVL(LPAD(TO_VARCHAR(v.ID_REGISTRATION_CLIENT), 10, '0'), '')
           || '|' || NVL(TRIM(v.ADDR_EMAIL), '')                                           AS eaddr_pkey
FROM v_fss_etl_src v
WHERE v.DTL__CAPXACTION <> 'D'
       AND NOT EXISTS (SELECT 1 FROM STG_FSS_PTY_INACTIVE_STS i
                        WHERE i.SRC_KEY = v.PTY_SRC_KEY AND i.ROWID_SYSTEM = 'FSS'
                          AND i.DEACTIVATION_STS IS NOT NULL)
    )
    SELECT EADDR_PKEY AS PKEY_SRC_OBJECT,
           DT_LAST_UPDATE AS PERIOD_START_DATE,
           '1' AS VERSION_SEQ,
           :P_RUN_TS AS LAST_UPDATE_DATE,
           :P_RUN_TS AS CREATE_DATE,
           EADDR_PKEY AS SRC_ROWID,
           1 AS HUB_STATE_IND,
           PTY_RLE_FK AS PTY_RLE_FK,
           '001' AS ADDR_TP,
           NULL AS USG_TP,
           NULL AS ELEC_ADDR,
           'Active' AS STS_CD,
           'Y' AS IS_VLD,
           DT_LAST_UPDATE AS SRC_LAST_UPD_DT
      FROM s1_src;
    RETURN SQLROWCOUNT;
END;
$$;
