-- ============================================================================
-- sp_snow_pub_ECI_ADR_C_S_ECI_PTY_RLE_ADDR.sql -- PUBLISH_DEST S10-only twin (C_S_* spine, first step only)
--
-- Twin of publish/sp_snow_pub_ECI_ADR_C_S_ECI_PTY_RLE_ADDR.sql. Same procedure, same target, same column list
-- -- but ONLY the first (source) step is inlined as a CTE (s10_src);
-- every later step (ACTIVE / DQ / ROUTED / READY / ranked / router)
-- and the WHERE gate are dropped. Each target column is aliased
-- from a first-step column, a literal, or a parameter (see map).
-- A column the first step does not carry is NULL (see map).
-- WHERE gate dropped: WHERE score = '100' AND uq_addr
-- P_RUN_TS: YES
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_pub_ECI_ADR_C_S_ECI_PTY_RLE_ADDR (
    P_RUN_TS TIMESTAMP_NTZ
)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
    -- ---- Publish branch 70: PUBLISH_C_S_ECI_PTY_RLE_ADDR (verbatim from current main)
INSERT INTO C_S_ECI_PTY_RLE_ADDR
           (PKEY_SRC_OBJECT, ROWID_OBJECT, DELETED_IND, DELETED_DATE, DELETED_BY, PERIOD_START_DATE,
            VERSION_SEQ, UPDATED_BY, CREATE_DATE, CREATOR, ADDR_TP, LAST_UPDATE_DATE, PREF_LVL, LOC_IDN,
            SRC_ROWID, HUB_STATE_IND, HIERARCHY_CODE, HM_REL_TP_CD, PERIOD_REFERENCE_TIME, ADDR_LN_1,
            ADDR_LN_2, CITY, PSTL_CD, CNTRY_CD, VLDTN_MSG, LATTD, LNGTD, PSTL_BRCD, RGN_CD, COUNTY,
            LCTN_CRDNT_DESC, MLBLTY_SCR, STATE, RSDNTL_DLVRY_IND, ORG_DESC, ADDR_TP_CD, ORG_NM, FLR_NUM,
            BLDNG_NM, GEOCD_STS_CD, SUB_BLDG_NM, SUB_BLDG_DESC, BLDG_NMBR, SRC_ADDR_LN_1, SRC_ADDR_LN_2,
            SRC_CITY, SRC_COUNTY, SRC_STATE, SRC_CNTRY, SRC_PSTL_CD, SRC_PSTL_CD_EXT, EFF_STRT_DT, EFF_END_DT,
            PTY_RLE_FK, SRC_LAST_UPD_DT, PSTL_CD_EXT)
    WITH
    s10_src AS (
WITH
        lkp_cv AS (SELECT * FROM TABLE(fn_snow_helper41_common()))
        SELECT s.ID, s.ID_FAMILY_ADDRESS, s.ADDRESS1, s.ADDRESS2, s.CITY_NAME, s.COUNTY_NAME, s.STATE_ABBREV, s.ZIP_CODE, s.ZIP_SFX, s.LAST_UPDATE_DATE,
               LPAD(TO_VARCHAR(s.ID), 10, '0') || IFF(s.SOURCE_TABLE = 'ECI_FAMILY', 'F', '')   AS pty_src_key,
               LPAD(TO_VARCHAR(s.ID), 10, '0') || IFF(s.SOURCE_TABLE = 'ECI_FAMILY', 'F', '') || '|Member' AS pty_rle_fk,
               at.MSTR_CODE_VALUE AS mstr_addr_tp
          FROM V_ECI_ETL_SRC_FAMILY_ADDRESS s
          LEFT JOIN lkp_cv at ON at.CODE_TYPE = 'ADDR_TP' AND at.SRC_SYS = 'ECI'
                             AND at.SRC_CODE_VALUE = s.ADDRESS_CD
    )
    SELECT PTY_RLE_FK || '|' || NVL(MSTR_ADDR_TP, '') || '|'
                   || NVL(LPAD(TO_VARCHAR(ID_FAMILY_ADDRESS), 10, '0'), '') || '|'
                   || NVL(TRIM(UPPER(ADDRESS1)), '') || '|' || NVL(TRIM(UPPER(ADDRESS2)), '') || '|'
                   || NVL(UPPER(CITY_NAME), '') || '|' || NVL(UPPER(STATE_ABBREV), '') || '|'
                   || NVL(ZIP_CODE, '') || '|' || NVL(ZIP_SFX, '') AS PKEY_SRC_OBJECT,
           NULL AS ROWID_OBJECT,
           NULL AS DELETED_IND,
           NULL AS DELETED_DATE,
           NULL AS DELETED_BY,
           LAST_UPDATE_DATE AS PERIOD_START_DATE,
           1 AS VERSION_SEQ,
           'm_Tgt_C_S_ECI_Pty_Addr' AS UPDATED_BY,
           LAST_UPDATE_DATE AS CREATE_DATE,
           NULL AS CREATOR,
           MSTR_ADDR_TP AS ADDR_TP,
           :P_RUN_TS AS LAST_UPDATE_DATE,
           'Primary' AS PREF_LVL,
           TO_VARCHAR(TRUNC(ID)) || '|' || TO_VARCHAR(TRUNC(ID_FAMILY_ADDRESS)) AS LOC_IDN,
           PTY_RLE_FK || '|' || NVL(MSTR_ADDR_TP, '') || '|'
                   || NVL(LPAD(TO_VARCHAR(ID_FAMILY_ADDRESS), 10, '0'), '') || '|'
                   || NVL(TRIM(UPPER(ADDRESS1)), '') || '|' || NVL(TRIM(UPPER(ADDRESS2)), '') || '|'
                   || NVL(UPPER(CITY_NAME), '') || '|' || NVL(UPPER(STATE_ABBREV), '') || '|'
                   || NVL(ZIP_CODE, '') || '|' || NVL(ZIP_SFX, '') AS SRC_ROWID,
           1 AS HUB_STATE_IND,
           'Member' AS HIERARCHY_CODE,
           'Member Addr' AS HM_REL_TP_CD,
           NULL AS PERIOD_REFERENCE_TIME,
           (ADDRESS1::VARCHAR) AS ADDR_LN_1,
           (ADDRESS1::VARCHAR) AS ADDR_LN_2,
           CITY_NAME::VARCHAR AS CITY,
           SUBSTR(TRIM(NVL(ZIP_CODE, '') || IFF(ZIP_SFX IS NOT NULL, '-' || ZIP_SFX, '')), 1, 5)::VARCHAR AS PSTL_CD,
           'US'::VARCHAR AS CNTRY_CD,
           NULL::VARCHAR AS VLDTN_MSG,
           0::NUMBER(38, 6) AS LATTD,
           0::NUMBER(38, 6) AS LNGTD,
           NULL AS PSTL_BRCD,
           NULL AS RGN_CD,
           NULL AS COUNTY,
           NULL AS LCTN_CRDNT_DESC,
           NULL::VARCHAR AS MLBLTY_SCR,
           (SUBSTR(TRIM(NVL(ZIP_CODE, '') || IFF(ZIP_SFX IS NOT NULL, '-' || ZIP_SFX, '')), 1, 5))::VARCHAR AS STATE,
           NULL::VARCHAR AS RSDNTL_DLVRY_IND,
           NULL::VARCHAR AS ORG_DESC,
           NULL::VARCHAR AS ADDR_TP_CD,
           NULL::VARCHAR AS ORG_NM,
           NULL AS FLR_NUM,
           NULL::VARCHAR AS BLDNG_NM,
           NULL::VARCHAR AS GEOCD_STS_CD,
           NULL::VARCHAR AS SUB_BLDG_NM,
           NULL::VARCHAR AS SUB_BLDG_DESC,
           NULL::VARCHAR AS BLDG_NMBR,
           ADDRESS1 AS SRC_ADDR_LN_1,
           ADDRESS2 AS SRC_ADDR_LN_2,
           CITY_NAME AS SRC_CITY,
           COUNTY_NAME AS SRC_COUNTY,
           STATE_ABBREV AS SRC_STATE,
           'US' AS SRC_CNTRY,
           ZIP_CODE AS SRC_PSTL_CD,
           ZIP_SFX AS SRC_PSTL_CD_EXT,
           LAST_UPDATE_DATE AS EFF_STRT_DT,
           NULL AS EFF_END_DT,
           PTY_RLE_FK AS PTY_RLE_FK,
           LAST_UPDATE_DATE AS SRC_LAST_UPD_DT,
           SUBSTR(TRIM(NVL(ZIP_CODE, '') || IFF(ZIP_SFX IS NOT NULL, '-' || ZIP_SFX, '')), 7, 4)::VARCHAR AS PSTL_CD_EXT
      FROM s10_src;

    RETURN SQLROWCOUNT;
END;
$$;
