-- ============================================================================
-- sp_snow_pub_WIC_ALT_C_S_WIC_PTY_RLE_ALT_ID.sql -- PUBLISH_DEST S10-only twin (C_S_* spine, first step only)
--
-- Twin of publish/sp_snow_pub_WIC_ALT_C_S_WIC_PTY_RLE_ALT_ID.sql. Same procedure, same target, same column list
-- -- but ONLY the first (source) step is inlined as a CTE (s10_keys);
-- every later step (ACTIVE / DQ / ROUTED / READY / ranked / router)
-- and the WHERE gate are dropped. Each target column is aliased
-- from a first-step column, a literal, or a parameter (see map).
-- A column the first step does not carry is NULL (see map).
-- WHERE gate dropped: none (no gate in original)
-- P_RUN_TS: YES
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_pub_WIC_ALT_C_S_WIC_PTY_RLE_ALT_ID (
    P_RUN_TS TIMESTAMP_NTZ
)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
    INSERT INTO C_S_WIC_PTY_RLE_ALT_ID
           (PKEY_SRC_OBJECT, SRC_ROWID, VERSION_SEQ, PTY_RLE_FK, ALT_ID_TP, ALT_ID_VAL, CREATE_DATE, LAST_UPDATE_DATE,
            ALT_ID_TP_FLTR, SRC_LAST_UPD_DT, STS_CD, PERIOD_START_DATE)
    WITH
    s10_keys AS (
SELECT v.ID, v.PTY_SRC_KEY, v.DATEKEY,
               NVL(v.PTY_SRC_KEY, '') || '|Member'                                    AS pty_rle_fk,
               IFF(v.SOURCE_TABLE = 'CLIENT', '020', '021')                           AS alt_id_tp,
               NVL(v.PTY_SRC_KEY, '') || '|Member|' || IFF(v.SOURCE_TABLE = 'CLIENT', '020', '021') || '|'
               || NVL(LPAD(TO_VARCHAR(v.ID), 12, '0'), '')                             AS pkey_src_object
          FROM V_WIC_ETL_SRC v
    )
    SELECT PKEY_SRC_OBJECT AS PKEY_SRC_OBJECT,
           NVL(TO_VARCHAR(ID), '') || '|' || ALT_ID_TP AS SRC_ROWID,
           1 AS VERSION_SEQ,
           PTY_RLE_FK AS PTY_RLE_FK,
           ALT_ID_TP AS ALT_ID_TP,
           LPAD(TO_VARCHAR(ID), 12, '0') AS ALT_ID_VAL,
           DATEKEY AS CREATE_DATE,
           :P_RUN_TS AS LAST_UPDATE_DATE,
           ALT_ID_TP AS ALT_ID_TP_FLTR,
           DATEKEY AS SRC_LAST_UPD_DT,
           'Issued' AS STS_CD,
           DATEKEY AS PERIOD_START_DATE
      FROM s10_keys;
    RETURN SQLROWCOUNT;
END;
$$;
