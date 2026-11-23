-- ============================================================================
-- sp_snow_pub_WIC_PTY_C_S_WIC_PTY_RLE.sql -- PUBLISH_DEST S10-only twin (C_S_* spine, first step only)
--
-- Twin of publish/sp_snow_pub_WIC_PTY_C_S_WIC_PTY_RLE.sql. Same procedure, same target, same column list
-- -- but ONLY the first (source) step is inlined as a CTE (s10_active);
-- every later step (ACTIVE / DQ / ROUTED / READY / ranked / router)
-- and the WHERE gate are dropped. Each target column is aliased
-- from a first-step column, a literal, or a parameter (see map).
-- A column the first step does not carry is NULL (see map).
-- WHERE gate dropped: WHERE uq_rle
-- P_RUN_TS: YES
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_pub_WIC_PTY_C_S_WIC_PTY_RLE (
    P_RUN_TS TIMESTAMP_NTZ
)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
    INSERT INTO C_S_WIC_PTY_RLE
           (PKEY_SRC_OBJECT, SRC_ROWID, RLE_BO_CLASS_CD, PTY_FK, VERSION_SEQ, LAST_UPDATE_DATE, HUB_STATE_IND,
            CREATE_DATE, PERIOD_START_DATE, SRC_LAST_UPD_DT)
    WITH
    s10_active AS (
SELECT v.DATEKEY, v.ID, v.PTY_SRC_KEY
          FROM V_WIC_ETL_SRC v
         WHERE NOT EXISTS (SELECT 1 FROM STG_WIC_PTY_INACTIVE_STS i
                            WHERE i.SRC_KEY = v.PTY_SRC_KEY AND i.ROWID_SYSTEM = 'WIC'
                              AND i.DEACTIVATION_STS IS NOT NULL)
    )
    SELECT TRIM(PTY_SRC_KEY) || '|Member' AS PKEY_SRC_OBJECT,
           TRIM(PTY_SRC_KEY) || '|Member' AS SRC_ROWID,
           'Member' AS RLE_BO_CLASS_CD,
           TRIM(PTY_SRC_KEY) AS PTY_FK,
           1 AS VERSION_SEQ,
           :P_RUN_TS AS LAST_UPDATE_DATE,
           1 AS HUB_STATE_IND,
           DATEKEY AS CREATE_DATE,
           DATEKEY AS PERIOD_START_DATE,
           DATEKEY AS SRC_LAST_UPD_DT
      FROM s10_active;
    RETURN SQLROWCOUNT;
END;
$$;
