-- ============================================================================
-- sp_snow_pub_FSS_PHN_C_S_FSS_PTY_RLE_PHN.sql -- PUBLISH_DEST S10-only twin (C_S_* spine, first step only)
--
-- Twin of publish/sp_snow_pub_FSS_PHN_C_S_FSS_PTY_RLE_PHN.sql. Same procedure, same target, same column list
-- -- but ONLY the first (source) step is inlined as a CTE (s1_src);
-- every later step (ACTIVE / DQ / ROUTED / READY / ranked / router)
-- and the WHERE gate are dropped. Each target column is aliased
-- from a first-step column, a literal, or a parameter (see map).
-- A column the first step does not carry is NULL (see map).
-- WHERE gate dropped: WHERE grp_phone_good AND uq_phn
-- P_RUN_TS: YES
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_pub_FSS_PHN_C_S_FSS_PTY_RLE_PHN (
    P_RUN_TS TIMESTAMP_NTZ
)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
INSERT INTO C_S_FSS_PTY_RLE_PHN
           (PKEY_SRC_OBJECT, PERIOD_START_DATE, VERSION_SEQ, LAST_UPDATE_DATE, SRC_ROWID, HUB_STATE_IND,
            PTY_RLE_FK, PHN_TP, USG_TP, PHN_NUM, PREF_LVL, SRC_LAST_UPD_DT, PHN_NUM_EXT)
    WITH
    s1_src AS (
SELECT v.NBR_PHONE,
       v.NBR_PHONE_EXT,
       v.ID_REGISTRATION_CLIENT,
       v.DT_LAST_UPDATE,
       NVL(v.PTY_SRC_KEY, '') || '|Member'                                             AS pty_rle_fk,
       NVL(v.PTY_SRC_KEY, '') || '|Member|Telephone|001|'
           || NVL(LPAD(TO_VARCHAR(v.ID_REGISTRATION_CLIENT), 10, '0'), '') || '|' || NVL(TRIM(v.NBR_PHONE), '')
                                                                                           AS phn_pkey
FROM v_fss_etl_src v
WHERE v.DTL__CAPXACTION <> 'D'
       AND NOT EXISTS (SELECT 1 FROM STG_FSS_PTY_INACTIVE_STS i
                        WHERE i.SRC_KEY = v.PTY_SRC_KEY AND i.ROWID_SYSTEM = 'FSS'
                          AND i.DEACTIVATION_STS IS NOT NULL)
    )
    SELECT PHN_PKEY AS PKEY_SRC_OBJECT,
           DT_LAST_UPDATE AS PERIOD_START_DATE,
           '1' AS VERSION_SEQ,
           :P_RUN_TS AS LAST_UPDATE_DATE,
           PHN_PKEY AS SRC_ROWID,
           1 AS HUB_STATE_IND,
           PTY_RLE_FK AS PTY_RLE_FK,
           'Telephone' AS PHN_TP,
           '001' AS USG_TP,
           NBR_PHONE AS PHN_NUM,
           'Primary' AS PREF_LVL,
           DT_LAST_UPDATE AS SRC_LAST_UPD_DT,
           NULL AS PHN_NUM_EXT
      FROM s1_src;
    RETURN SQLROWCOUNT;
END;
$$;
