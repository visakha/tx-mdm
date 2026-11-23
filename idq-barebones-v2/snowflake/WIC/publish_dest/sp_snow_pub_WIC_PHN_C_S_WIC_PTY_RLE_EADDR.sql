-- ============================================================================
-- sp_snow_pub_WIC_PHN_C_S_WIC_PTY_RLE_EADDR.sql -- PUBLISH_DEST S10-only twin (C_S_* spine, first step only)
--
-- Twin of publish/sp_snow_pub_WIC_PHN_C_S_WIC_PTY_RLE_EADDR.sql. Same procedure, same target, same column list
-- -- but ONLY the first (source) step is inlined as a CTE (s10_src);
-- every later step (ACTIVE / DQ / ROUTED / READY / ranked / router)
-- and the WHERE gate are dropped. Each target column is aliased
-- from a first-step column, a literal, or a parameter (see map).
-- A column the first step does not carry is NULL (see map).
-- WHERE gate dropped: WHERE grp_email_good AND uq_eaddr
-- P_RUN_TS: YES
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_pub_WIC_PHN_C_S_WIC_PTY_RLE_EADDR (
    P_RUN_TS TIMESTAMP_NTZ
)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
    INSERT INTO C_S_WIC_PTY_RLE_EADDR
           (PKEY_SRC_OBJECT, PERIOD_START_DATE, VERSION_SEQ, LAST_UPDATE_DATE, CREATE_DATE, SRC_ROWID,
            HUB_STATE_IND, PTY_RLE_FK, ELEC_ADDR, USG_TP, STS_CD, IS_VLD, SRC_LAST_UPD_DT, ADDR_TP)
    WITH
    s10_src AS (
SELECT v.PTY_SRC_KEY, v.DATEKEY, v.FID, v.EMAIL,
               NVL(v.PTY_SRC_KEY, '') || '|Member'                                            AS pty_rle_fk,
               NVL(v.PTY_SRC_KEY, '') || '|Member|001|' || NVL(TO_VARCHAR(v.FID), '') || '|' || NVL(v.EMAIL, '')
                                                                                              AS eaddr_pkey,
               IFF(v.EMAIL IS NOT NULL, fn_snow_helper22_common(v.EMAIL), NULL)               AS em
          FROM V_WIC_ETL_SRC v
         WHERE NOT EXISTS (SELECT 1 FROM STG_WIC_PTY_INACTIVE_STS i
                            WHERE i.SRC_KEY = v.PTY_SRC_KEY AND i.ROWID_SYSTEM = 'WIC'
                              AND i.DEACTIVATION_STS IS NOT NULL)
    )
    SELECT EADDR_PKEY AS PKEY_SRC_OBJECT,
           DATEKEY AS PERIOD_START_DATE,
           '1' AS VERSION_SEQ,
           :P_RUN_TS AS LAST_UPDATE_DATE,
           :P_RUN_TS AS CREATE_DATE,
           EADDR_PKEY AS SRC_ROWID,
           1 AS HUB_STATE_IND,
           PTY_RLE_FK AS PTY_RLE_FK,
           NULL AS ELEC_ADDR,
           NULL AS USG_TP,
           'Active' AS STS_CD,
           'Y' AS IS_VLD,
           DATEKEY AS SRC_LAST_UPD_DT,
           '001' AS ADDR_TP
      FROM s10_src;
    RETURN SQLROWCOUNT;
END;
$$;
