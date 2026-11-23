-- ============================================================================
-- sp_snow_pub_TTF_ALT_C_S_TTF_PTY_RLE_ALT_ID.sql -- PUBLISH_DEST S10-only twin (C_S_* spine, first step only)
--
-- Twin of publish/sp_snow_pub_TTF_ALT_C_S_TTF_PTY_RLE_ALT_ID.sql. Same procedure, same target, same column list
-- -- but ONLY the first (source) step is inlined as a CTE (s1_keys);
-- every later step (ACTIVE / DQ / ROUTED / READY / ranked / router)
-- and the WHERE gate are dropped. Each target column is aliased
-- from a first-step column, a literal, or a parameter (see map).
-- A column the first step does not carry is NULL (see map).
-- WHERE gate dropped: none (no gate in original)
-- P_RUN_TS: YES
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_pub_TTF_ALT_C_S_TTF_PTY_RLE_ALT_ID (
    P_RUN_TS TIMESTAMP_NTZ
)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
INSERT INTO C_S_TTF_PTY_RLE_ALT_ID
           (PKEY_SRC_OBJECT, HUB_STATE_IND, SRC_ROWID, LAST_UPDATE_DATE, VERSION_SEQ, CREATE_DATE, PTY_RLE_FK,
            ALT_ID_TP, ALT_ID_VAL, ALT_ID_TP_FLTR, STS_CD, PERIOD_START_DATE, SRC_LAST_UPD_DT)
    WITH
    s1_keys AS (
SELECT v.PTY_SRC_KEY, v.SUBMITDATE,
               NVL(v.PTY_SRC_KEY, '') || '|Member|024|' || NVL(v.PTY_SRC_KEY, '') AS pkey_src_object
          FROM V_TTF_ETL_SRC v
         -- Lkp_STG_TTF_PTY_INACTIVE_STS + Filter
         WHERE NOT EXISTS (SELECT 1 FROM STG_TTF_PTY_INACTIVE_STS i
                            WHERE i.SRC_KEY = v.PTY_SRC_KEY AND i.ROWID_SYSTEM = 'TTF'
                              AND i.DEACTIVATION_STS IS NOT NULL)
    )
    SELECT PKEY_SRC_OBJECT AS PKEY_SRC_OBJECT,
           1 AS HUB_STATE_IND,
           PKEY_SRC_OBJECT AS SRC_ROWID,
           :P_RUN_TS AS LAST_UPDATE_DATE,
           1 AS VERSION_SEQ,
           SUBMITDATE AS CREATE_DATE,
           NVL(PTY_SRC_KEY, '') || '|Member' AS PTY_RLE_FK,
           '024' AS ALT_ID_TP,
           PTY_SRC_KEY AS ALT_ID_VAL,
           '024' AS ALT_ID_TP_FLTR,
           'Issued' AS STS_CD,
           :P_RUN_TS AS PERIOD_START_DATE,
           SUBMITDATE AS SRC_LAST_UPD_DT
      FROM s1_keys;
    RETURN SQLROWCOUNT;
END;
$$;
