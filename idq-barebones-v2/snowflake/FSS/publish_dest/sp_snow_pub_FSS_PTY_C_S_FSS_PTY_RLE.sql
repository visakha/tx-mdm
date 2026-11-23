-- ============================================================================
-- sp_snow_pub_FSS_PTY_C_S_FSS_PTY_RLE.sql -- PUBLISH_DEST S10-only twin (C_S_* spine, first step only)
--
-- Twin of publish/sp_snow_pub_FSS_PTY_C_S_FSS_PTY_RLE.sql. Same procedure, same target, same column list
-- -- but ONLY the first (source) step is inlined as a CTE (s1_src);
-- every later step (ACTIVE / DQ / ROUTED / READY / ranked / router)
-- and the WHERE gate are dropped. Each target column is aliased
-- from a first-step column, a literal, or a parameter (see map).
-- A column the first step does not carry is NULL (see map).
-- WHERE gate dropped: WHERE uq_rle
-- P_RUN_TS: YES
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_pub_FSS_PTY_C_S_FSS_PTY_RLE (
    P_RUN_TS TIMESTAMP_NTZ
)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
INSERT INTO C_S_FSS_PTY_RLE
           (PKEY_SRC_OBJECT, PERIOD_START_DATE, VERSION_SEQ, LAST_UPDATE_DATE, CREATE_DATE, SRC_ROWID,
            HUB_STATE_IND, PTY_FK, RLE_BO_CLASS_CD, SRC_LAST_UPD_DT)
    WITH
    s1_src AS (
SELECT s.dt_last_update,
       s.pty_src_key,
       s.id_client
FROM ( SELECT v.DT_LAST_UPDATE,
       v.PTY_SRC_KEY,
       v.ID_CLIENT
FROM v_fss_etl_src v
WHERE v.LAST_ACTIVE_CLIENT_REGISTRATION_YN = 'Y' ) s
WHERE NOT EXISTS (SELECT 1 FROM STG_FSS_PTY_INACTIVE_STS i
                        WHERE i.SRC_KEY = s.PTY_SRC_KEY AND i.ROWID_SYSTEM = 'FSS'
                          AND i.DEACTIVATION_STS IS NOT NULL)
    )
    SELECT TRIM(PTY_SRC_KEY) || '|' || 'Member' AS PKEY_SRC_OBJECT,
           DT_LAST_UPDATE AS PERIOD_START_DATE,
           1 AS VERSION_SEQ,
           :P_RUN_TS AS LAST_UPDATE_DATE,
           DT_LAST_UPDATE AS CREATE_DATE,
           TRIM(PTY_SRC_KEY) || '|' || 'Member' AS SRC_ROWID,
           1 AS HUB_STATE_IND,
           TRIM(PTY_SRC_KEY) AS PTY_FK,
           'Member' AS RLE_BO_CLASS_CD,
           DT_LAST_UPDATE AS SRC_LAST_UPD_DT
      FROM s1_src;
    RETURN SQLROWCOUNT;
END;
$$;
