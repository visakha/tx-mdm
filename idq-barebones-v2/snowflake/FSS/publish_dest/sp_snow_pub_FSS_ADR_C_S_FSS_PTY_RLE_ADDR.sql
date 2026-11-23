-- ============================================================================
-- sp_snow_pub_FSS_ADR_C_S_FSS_PTY_RLE_ADDR.sql -- PUBLISH_DEST S10-only twin (C_S_* spine, first step only)
--
-- Twin of publish/sp_snow_pub_FSS_ADR_C_S_FSS_PTY_RLE_ADDR.sql. Same procedure, same target, same column list
-- -- but ONLY the first (source) step is inlined as a CTE (s1_src);
-- every later step (ACTIVE / DQ / ROUTED / READY / ranked / router)
-- and the WHERE gate are dropped. Each target column is aliased
-- from a first-step column, a literal, or a parameter (see map).
-- A column the first step does not carry is NULL (see map).
-- WHERE gate dropped: WHERE score = '100' AND uq_addr
-- P_RUN_TS: YES
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_pub_FSS_ADR_C_S_FSS_PTY_RLE_ADDR (
    P_RUN_TS TIMESTAMP_NTZ
)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
INSERT INTO C_S_FSS_PTY_RLE_ADDR
           (PKEY_SRC_OBJECT, ROWID_OBJECT, DELETED_IND, DELETED_DATE, DELETED_BY, VERSION_SEQ,
            PERIOD_REFERENCE_TIME, LAST_UPDATE_DATE, UPDATED_BY, CREATE_DATE, CREATOR, SRC_ROWID, HUB_STATE_IND,
            PTY_RLE_FK, ADDR_TP, USG_TP, PREF_LVL, HIERARCHY_CODE, HM_REL_TP_CD, LOC_IDN, SRC_LAST_UPD_DT,
            ADDR_LN_1, ADDR_LN_2, BLDNG_NM, FLR_NUM, CITY, COUNTY, STATE, CNTRY_CD, PSTL_CD, PSTL_CD_EXT,
            LCTN_CRDNT_DESC, LATTD, LNGTD, PSTL_BRCD, VLDTN_MSG, RGN_CD, MLBLTY_SCR, ADDR_TP_CD, ORG_DESC,
            ORG_NM, BLDG_NMBR, SUB_BLDG_NM, SUB_BLDG_DESC, GEOCD_STS_CD, RSDNTL_DLVRY_IND, SRC_ADDR_LN_1,
            SRC_ADDR_LN_2, SRC_CITY, SRC_COUNTY, SRC_STATE, SRC_CNTRY, SRC_PSTL_CD, SRC_PSTL_CD_EXT, EFF_STRT_DT,
            EFF_END_DT, PERIOD_START_DATE)
    WITH
    s1_src AS (
SELECT s.id_client,
       s.addr_line1,
       s.addr_line2,
       s.addr_city,
       s.cd_cnty,
       s.addr_zip,
       s.addr_state,
       s.pty_src_key,
       s.id_registration_client,
       s.dt_last_update,
       s.dt_created,
       s.pkey_src_object
FROM ( SELECT v.ID_CLIENT,
       v.ADDR_LINE1,
       v.ADDR_LINE2,
       v.ADDR_CITY,
       v.CD_CNTY,
       v.ADDR_ZIP,
       v.ADDR_STATE,
       v.PTY_SRC_KEY,
       v.ID_REGISTRATION_CLIENT,
       v.DT_LAST_UPDATE,
       v.DT_CREATED,
       NVL(v.PTY_SRC_KEY, '') || '|Member|002|' || NVL(LPAD(TO_VARCHAR(v.ID_REGISTRATION_CLIENT), 10, '0'), '')
                   || '|' || NVL(TRIM(UPPER(v.ADDR_LINE1)), '') || '|' || NVL(TRIM(UPPER(v.ADDR_LINE2)), '') || '|'
                   || NVL(UPPER(v.ADDR_CITY), '') || '|' || NVL(UPPER(v.ADDR_STATE), '') || '|' || NVL(v.ADDR_ZIP, '')
                                                                                                   AS pkey_src_object
FROM v_fss_etl_src v
WHERE v.DTL__CAPXACTION <> 'D' ) s
WHERE NOT EXISTS (SELECT 1 FROM STG_FSS_PTY_INACTIVE_STS i
                        WHERE i.SRC_KEY = s.PTY_SRC_KEY AND i.ROWID_SYSTEM = 'FSS'
                          AND i.DEACTIVATION_STS IS NOT NULL)
    )
    SELECT PKEY_SRC_OBJECT AS PKEY_SRC_OBJECT,
           NULL AS ROWID_OBJECT,
           NULL AS DELETED_IND,
           NULL AS DELETED_DATE,
           NULL AS DELETED_BY,
           1 AS VERSION_SEQ,
           NULL AS PERIOD_REFERENCE_TIME,
           :P_RUN_TS AS LAST_UPDATE_DATE,
           'm_Tgt_C_S_FSS_Pty_Addr' AS UPDATED_BY,
           DT_LAST_UPDATE AS CREATE_DATE,
           NULL AS CREATOR,
           PKEY_SRC_OBJECT AS SRC_ROWID,
           1 AS HUB_STATE_IND,
           NVL(PTY_SRC_KEY, '') || '|Member' AS PTY_RLE_FK,
           '002' AS ADDR_TP,
           NULL AS USG_TP,
           'Primary' AS PREF_LVL,
           'Member' AS HIERARCHY_CODE,
           'Member Addr' AS HM_REL_TP_CD,
           NVL(TO_VARCHAR(ID_CLIENT), '') || '|' || NVL(TO_VARCHAR(ID_REGISTRATION_CLIENT), '') AS LOC_IDN,
           DT_LAST_UPDATE AS SRC_LAST_UPD_DT,
           (ADDR_LINE1::VARCHAR) AS ADDR_LN_1,
           (ADDR_LINE1::VARCHAR) AS ADDR_LN_2,
           NULL::VARCHAR AS BLDNG_NM,
           NULL AS FLR_NUM,
           ADDR_CITY::VARCHAR AS CITY,
           NULL AS COUNTY,
           (SUBSTR(TRIM(ADDR_ZIP), 1, 5))::VARCHAR AS STATE,
           'US'::VARCHAR AS CNTRY_CD,
           SUBSTR(TRIM(ADDR_ZIP), 1, 5)::VARCHAR AS PSTL_CD,
           SUBSTR(TRIM(ADDR_ZIP), 7, 4)::VARCHAR AS PSTL_CD_EXT,
           NULL AS LCTN_CRDNT_DESC,
           0::NUMBER(38, 6) AS LATTD,
           0::NUMBER(38, 6) AS LNGTD,
           NULL AS PSTL_BRCD,
           NULL::VARCHAR AS VLDTN_MSG,
           NULL AS RGN_CD,
           NULL::VARCHAR AS MLBLTY_SCR,
           NULL::VARCHAR AS ADDR_TP_CD,
           NULL::VARCHAR AS ORG_DESC,
           NULL::VARCHAR AS ORG_NM,
           NULL::VARCHAR AS BLDG_NMBR,
           NULL::VARCHAR AS SUB_BLDG_NM,
           NULL::VARCHAR AS SUB_BLDG_DESC,
           NULL::VARCHAR AS GEOCD_STS_CD,
           NULL::VARCHAR AS RSDNTL_DLVRY_IND,
           ADDR_LINE1 AS SRC_ADDR_LN_1,
           ADDR_LINE2 AS SRC_ADDR_LN_2,
           ADDR_CITY AS SRC_CITY,
           CD_CNTY AS SRC_COUNTY,
           ADDR_STATE AS SRC_STATE,
           'US' AS SRC_CNTRY,
           ADDR_ZIP AS SRC_PSTL_CD,
           NULL AS SRC_PSTL_CD_EXT,
           DT_LAST_UPDATE AS EFF_STRT_DT,
           NULL AS EFF_END_DT,
           DT_CREATED AS PERIOD_START_DATE
      FROM s1_src;
    RETURN SQLROWCOUNT;
END;
$$;
