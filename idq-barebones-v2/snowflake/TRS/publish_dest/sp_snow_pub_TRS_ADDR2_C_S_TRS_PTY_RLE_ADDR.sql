-- ============================================================================
-- sp_snow_pub_TRS_ADDR2_C_S_TRS_PTY_RLE_ADDR.sql -- PUBLISH_DEST S10-only twin (C_S_* spine, first step only)
--
-- Twin of publish/sp_snow_pub_TRS_ADDR2_C_S_TRS_PTY_RLE_ADDR.sql. Same procedure, same target, same column list
-- -- but ONLY the first (source) step is inlined as a CTE (s10_dedup);
-- every later step (ACTIVE / DQ / ROUTED / READY / ranked / router)
-- and the WHERE gate are dropped. Each target column is aliased
-- from a first-step column, a literal, or a parameter (see map).
-- A column the first step does not carry is NULL (see map).
-- WHERE gate dropped: WHERE score = '100' AND uq_addr
-- P_RUN_TS: YES
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_pub_TRS_ADDR2_C_S_TRS_PTY_RLE_ADDR (
    P_RUN_TS TIMESTAMP_NTZ
)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
INSERT INTO C_S_TRS_PTY_RLE_ADDR
           (PKEY_SRC_OBJECT, PERIOD_START_DATE, VERSION_SEQ, PERIOD_REFERENCE_TIME, HIERARCHY_CODE, HM_REL_TP_CD,
            LAST_UPDATE_DATE, ROWID_OBJECT, DELETED_IND, DELETED_DATE, DELETED_BY, UPDATED_BY, SRC_ROWID,
            HUB_STATE_IND, PREF_LVL, LOC_IDN, ADDR_TP, PTY_RLE_FK, USG_TP, ADDR_LN_1, ADDR_LN_2, CITY, PSTL_CD,
            PSTL_CD_EXT, CNTRY_CD, CRDNT_SYS, LATTD, LNGTD, PSTL_BRCD, FLR_NUM, BLDNG_NM, COUNTY, STATE,
            LCTN_CRDNT_DESC, VLDTN_MSG, RGN_CD, MLBLTY_SCR, ADDR_TP_CD, ORG_DESC, ORG_NM, GEOCD_STS_CD,
            SUB_BLDG_NM, BLDG_NMBR, SUB_BLDG_DESC, RSDNTL_DLVRY_IND, SRC_ADDR_LN_1, SRC_ADDR_LN_2, SRC_CITY,
            SRC_COUNTY, SRC_STATE, SRC_CNTRY, SRC_PSTL_CD, SRC_PSTL_CD_EXT, SRC_LAST_UPD_DT, CREATOR, CREATE_DATE,
            EFF_STRT_DT, PERIOD_END_DATE, EFF_END_DT)
    WITH
    s10_dedup AS (
SELECT a.indv_id,
        a.case_num,
        a.edg_num,
        a.addr_type_cd,
        NVL(TO_VARCHAR(a.addr_st_num), '') || ' ' || NVL(a.addr_st_num_frac, '') || ' '
               || NVL(a.addr_st_nm, '') || ' ' || NVL(a.addr_st_dir_cd, '') || ' ' || NVL(a.addr_st_type_cd, '')
               || ' ' || NVL(a.addr_dwelling_type_cd, '') || ' ' || NVL(a.addr_apt_num, '') || ' '
               || NVL(a.addr_line, '') || ' ' || NVL(a.addr_city, '') || ' ' || NVL(a.addr_state_cd, '') || ' '
               || NVL(TO_VARCHAR(a.addr_zip5), '') || ' ' || NVL(TO_VARCHAR(a.addr_zip4), '') AS addr_id,
        GREATEST(a.create_dt, NVL(a.update_dt, a.create_dt)) AS create_dt,
        a.eff_begin_dt,
        a.eff_end_dt,
        ROW_NUMBER() OVER (PARTITION BY a.indv_id, a.addr_type_cd, a.case_num, a.edg_num
                                  ORDER BY GREATEST(a.create_dt, NVL(a.update_dt, a.create_dt)) DESC,
                                           a.eff_begin_dt DESC) AS key_rn
          FROM STG_TRS_D_INDV_ADDR a
    )
    SELECT NULL AS PKEY_SRC_OBJECT,
           EFF_BEGIN_DT AS PERIOD_START_DATE,
           '1' AS VERSION_SEQ,
           IFF(EFF_END_DT IS NOT NULL, :P_RUN_TS, NULL) AS PERIOD_REFERENCE_TIME,
           'Member' AS HIERARCHY_CODE,
           'Member Addr' AS HM_REL_TP_CD,
           :P_RUN_TS AS LAST_UPDATE_DATE,
           NULL AS ROWID_OBJECT,
           NULL AS DELETED_IND,
           NULL AS DELETED_DATE,
           NULL AS DELETED_BY,
           NULL AS UPDATED_BY,
           NULL AS SRC_ROWID,
           NULL AS HUB_STATE_IND,
           '       ' AS PREF_LVL,
           NVL(TO_VARCHAR(TRUNC(CASE_NUM)), '') || ' ' || NVL(TO_VARCHAR(TRUNC(EDG_NUM)), '') AS LOC_IDN,
           NULL AS ADDR_TP,
           NULL AS PTY_RLE_FK,
           NULL AS USG_TP,
           NULL AS ADDR_LN_1,
           NULL AS ADDR_LN_2,
           NULL AS CITY,
           NULL AS PSTL_CD,
           NULL AS PSTL_CD_EXT,
           NULL AS CNTRY_CD,
           NULL AS CRDNT_SYS,
           NULL AS LATTD,
           NULL AS LNGTD,
           NULL AS PSTL_BRCD,
           NULL AS FLR_NUM,
           NULL AS BLDNG_NM,
           NULL AS COUNTY,
           NULL AS STATE,
           NULL AS LCTN_CRDNT_DESC,
           NULL AS VLDTN_MSG,
           NULL AS RGN_CD,
           NULL AS MLBLTY_SCR,
           NULL AS ADDR_TP_CD,
           NULL AS ORG_DESC,
           NULL AS ORG_NM,
           NULL AS GEOCD_STS_CD,
           NULL AS SUB_BLDG_NM,
           NULL AS BLDG_NMBR,
           NULL AS SUB_BLDG_DESC,
           NULL AS RSDNTL_DLVRY_IND,
           NULL AS SRC_ADDR_LN_1,
           NULL AS SRC_ADDR_LN_2,
           NULL AS SRC_CITY,
           NULL AS SRC_COUNTY,
           NULL AS SRC_STATE,
           NULL AS SRC_CNTRY,
           NULL AS SRC_PSTL_CD,
           NULL AS SRC_PSTL_CD_EXT,
           CREATE_DT AS SRC_LAST_UPD_DT,
           NULL AS CREATOR,
           NULL AS CREATE_DATE,
           EFF_BEGIN_DT AS EFF_STRT_DT,
           EFF_END_DT AS PERIOD_END_DATE,
           EFF_END_DT AS EFF_END_DT
      FROM s10_dedup;
    RETURN SQLROWCOUNT;
END;
$$;
