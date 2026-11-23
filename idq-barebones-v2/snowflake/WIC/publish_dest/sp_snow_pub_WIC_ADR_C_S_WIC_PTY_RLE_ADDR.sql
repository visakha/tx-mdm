-- ============================================================================
-- sp_snow_pub_WIC_ADR_C_S_WIC_PTY_RLE_ADDR.sql -- PUBLISH_DEST S10-only twin (C_S_* spine, first step only)
--
-- Twin of publish/sp_snow_pub_WIC_ADR_C_S_WIC_PTY_RLE_ADDR.sql. Same procedure, same target, same column list
-- -- but ONLY the first (source) step is inlined as a CTE (s10_active);
-- every later step (ACTIVE / DQ / ROUTED / READY / ranked / router)
-- and the WHERE gate are dropped. Each target column is aliased
-- from a first-step column, a literal, or a parameter (see map).
-- A column the first step does not carry is NULL (see map).
-- WHERE gate dropped: WHERE score = '100' AND uq_addr
-- P_RUN_TS: YES
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_pub_WIC_ADR_C_S_WIC_PTY_RLE_ADDR (
    P_RUN_TS TIMESTAMP_NTZ
)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
    INSERT INTO C_S_WIC_PTY_RLE_ADDR
           (PKEY_SRC_OBJECT, ROWID_OBJECT, DELETED_IND, DELETED_DATE, DELETED_BY, PERIOD_START_DATE,
            VERSION_SEQ, UPDATED_BY, LAST_UPDATE_DATE, PREF_LVL, LOC_IDN, HM_REL_TP_CD, HUB_STATE_IND,
            SRC_ROWID, USG_TP, HIERARCHY_CODE, ADDR_LN_1, ADDR_LN_2, SRC_LAST_UPD_DT, FLR_NUM, LCTN_CRDNT_DESC,
            PSTL_BRCD, RGN_CD, SRC_ADDR_LN_1, SRC_ADDR_LN_2, SRC_CITY, SRC_COUNTY, SRC_STATE, SRC_CNTRY,
            SRC_PSTL_CD, SRC_PSTL_CD_EXT, EFF_STRT_DT, EFF_END_DT, ADDR_TP, PTY_RLE_FK, CREATE_DATE, CREATOR,
            PERIOD_REFERENCE_TIME, CITY, PSTL_CD, CNTRY_CD, VLDTN_MSG, LATTD, LNGTD, COUNTY, MLBLTY_SCR, STATE,
            RSDNTL_DLVRY_IND, ORG_DESC, ADDR_TP_CD, ORG_NM, BLDNG_NM, GEOCD_STS_CD, SUB_BLDG_NM,
            SUB_BLDG_DESC, BLDG_NMBR, PSTL_CD_EXT)
    WITH
    s10_active AS (
SELECT v.ID, v.FID, v.DATE_ADDRESS_VALID_FROM, v.ADDRESS1, v.ADDRESS2, v.CITY, v.COUNTY,
               v.ZIP_CODE, v.PTY_SRC_KEY,
               NVL(v.PTY_SRC_KEY, '') || '|Member|002|' || NVL(LPAD(TO_VARCHAR(v.FID), 12, '0'), '') || '|'
               || NVL(TRIM(UPPER(v.ADDRESS1)), '') || '|' || NVL(TRIM(UPPER(v.ADDRESS2)), '') || '|'
               || NVL(UPPER(v.CITY), '') || '||' || NVL(v.ZIP_CODE, '')                      AS pkey_src_object
          FROM V_WIC_ETL_SRC v
         WHERE NOT EXISTS (SELECT 1 FROM STG_WIC_PTY_INACTIVE_STS i
                            WHERE i.SRC_KEY = v.PTY_SRC_KEY AND i.ROWID_SYSTEM = 'WIC'
                              AND i.DEACTIVATION_STS IS NOT NULL)
    )
    SELECT PKEY_SRC_OBJECT AS PKEY_SRC_OBJECT,
           NULL AS ROWID_OBJECT,
           NULL AS DELETED_IND,
           NULL AS DELETED_DATE,
           NULL AS DELETED_BY,
           DATE_ADDRESS_VALID_FROM AS PERIOD_START_DATE,
           1 AS VERSION_SEQ,
           'm_Tgt_C_S_WIC_Pty_Addr' AS UPDATED_BY,
           :P_RUN_TS AS LAST_UPDATE_DATE,
           'Primary' AS PREF_LVL,
           NVL(TO_VARCHAR(ID), '') || '|' || NVL(TO_VARCHAR(FID), '') AS LOC_IDN,
           'Member Addr' AS HM_REL_TP_CD,
           1 AS HUB_STATE_IND,
           PKEY_SRC_OBJECT AS SRC_ROWID,
           NULL AS USG_TP,
           'Member' AS HIERARCHY_CODE,
           (ADDRESS1::VARCHAR) AS ADDR_LN_1,
           (ADDRESS1::VARCHAR) AS ADDR_LN_2,
           DATE_ADDRESS_VALID_FROM AS SRC_LAST_UPD_DT,
           NULL AS FLR_NUM,
           NULL AS LCTN_CRDNT_DESC,
           NULL AS PSTL_BRCD,
           NULL AS RGN_CD,
           ADDRESS1 AS SRC_ADDR_LN_1,
           ADDRESS2 AS SRC_ADDR_LN_2,
           CITY AS SRC_CITY,
           COUNTY AS SRC_COUNTY,
           NULL AS SRC_STATE,
           'US' AS SRC_CNTRY,
           ZIP_CODE AS SRC_PSTL_CD,
           NULL AS SRC_PSTL_CD_EXT,
           DATE_ADDRESS_VALID_FROM AS EFF_STRT_DT,
           NULL AS EFF_END_DT,
           '002' AS ADDR_TP,
           NVL(PTY_SRC_KEY, '') || '|Member' AS PTY_RLE_FK,
           DATE_ADDRESS_VALID_FROM AS CREATE_DATE,
           NULL AS CREATOR,
           NULL AS PERIOD_REFERENCE_TIME,
           CITY::VARCHAR AS CITY,
           SUBSTR(TRIM(ZIP_CODE), 1, 5)::VARCHAR AS PSTL_CD,
           'US'::VARCHAR AS CNTRY_CD,
           NULL::VARCHAR AS VLDTN_MSG,
           0::NUMBER(38, 6) AS LATTD,
           0::NUMBER(38, 6) AS LNGTD,
           NULL AS COUNTY,
           NULL::VARCHAR AS MLBLTY_SCR,
           (SUBSTR(TRIM(ZIP_CODE), 1, 5))::VARCHAR AS STATE,
           NULL::VARCHAR AS RSDNTL_DLVRY_IND,
           NULL::VARCHAR AS ORG_DESC,
           NULL::VARCHAR AS ADDR_TP_CD,
           NULL::VARCHAR AS ORG_NM,
           NULL::VARCHAR AS BLDNG_NM,
           NULL::VARCHAR AS GEOCD_STS_CD,
           NULL::VARCHAR AS SUB_BLDG_NM,
           NULL::VARCHAR AS SUB_BLDG_DESC,
           NULL::VARCHAR AS BLDG_NMBR,
           SUBSTR(TRIM(ZIP_CODE), 7, 4)::VARCHAR AS PSTL_CD_EXT
      FROM s10_active;
    RETURN SQLROWCOUNT;
END;
$$;
