-- ============================================================================
-- sp_snow_pub_FSS_ALT_C_S_FSS_PTY_RLE_ALT_ID.sql -- PUBLISH_DEST S10-only twin (C_S_* spine, first step only)
--
-- Twin of publish/sp_snow_pub_FSS_ALT_C_S_FSS_PTY_RLE_ALT_ID.sql. Same procedure, same target, same column list
-- -- but ONLY the first (source) step is inlined as a CTE (s1_src);
-- every later step (ACTIVE / DQ / ROUTED / READY / ranked / router)
-- and the WHERE gate are dropped. Each target column is aliased
-- from a first-step column, a literal, or a parameter (see map).
-- A column the first step does not carry is NULL (see map).
-- WHERE gate dropped: none (no gate in original)
-- P_RUN_TS: YES
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_pub_FSS_ALT_C_S_FSS_PTY_RLE_ALT_ID (
    P_RUN_TS TIMESTAMP_NTZ
)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
INSERT INTO C_S_FSS_PTY_RLE_ALT_ID
           (PKEY_SRC_OBJECT, PTY_RLE_FK, ALT_ID_TP, ALT_ID_VAL, SRC_LAST_UPD_DT, HUB_STATE_IND, STS_CD, SRC_ROWID,
            LAST_UPDATE_DATE, VERSION_SEQ, ALT_ID_TP_FLTR, CREATE_DATE, PERIOD_START_DATE)
    WITH
    s1_src AS (
SELECT v.DT_CREATED,
       v.DT_LAST_UPDATE,
       v.PTY_SRC_KEY,
       v.ID_CLIENT,
       NVL(v.PTY_SRC_KEY, '') || '|Member'                                      AS pty_rle_fk,
       IFF(v.SOURCE_TYPE = 'CLIENT', '022', '023')                              AS alt_id_tp,
       NVL(v.PTY_SRC_KEY, '') || '|Member|' || IFF(v.SOURCE_TYPE = 'CLIENT', '022', '023') || '|'
           || NVL(LPAD(TO_VARCHAR(v.ID_CLIENT), 10, '0'), '')                        AS pkey_src_object
FROM v_fss_etl_src v
WHERE v.LAST_ACTIVE_CLIENT_REGISTRATION_YN = 'Y'
    )
    SELECT PKEY_SRC_OBJECT AS PKEY_SRC_OBJECT,
           PTY_RLE_FK AS PTY_RLE_FK,
           ALT_ID_TP AS ALT_ID_TP,
           LPAD(TO_VARCHAR(ID_CLIENT), 10, '0') AS ALT_ID_VAL,
           :P_RUN_TS AS SRC_LAST_UPD_DT,
           1 AS HUB_STATE_IND,
           'Issued' AS STS_CD,
           NVL(TO_VARCHAR(ID_CLIENT), '') || '|' || ALT_ID_TP AS SRC_ROWID,
           :P_RUN_TS AS LAST_UPDATE_DATE,
           1 AS VERSION_SEQ,
           ALT_ID_TP AS ALT_ID_TP_FLTR,
           DT_CREATED AS CREATE_DATE,
           DT_CREATED AS PERIOD_START_DATE
      FROM s1_src;
    RETURN SQLROWCOUNT;
END;
$$;
