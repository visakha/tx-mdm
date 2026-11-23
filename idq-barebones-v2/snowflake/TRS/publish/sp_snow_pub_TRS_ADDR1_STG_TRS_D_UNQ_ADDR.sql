-- ============================================================================
-- sp_snow_pub_TRS_ADDR1_STG_TRS_D_UNQ_ADDR  --  BARE-BONES PUBLISH BRANCH (TRS)
--
-- Mapping: m_Tgt_C_S_TRS_Addr_1, workflow wf_TRS_Stage_Load_1_Ongoing.
-- Target: STG_TRS_D_UNQ_ADDR. Kind: STATUS (Validated unique addresses).
-- Consumes (v2.1 declared inputs): WRK_TRS_ADDR1_S40_READY.
-- Keeps P_RUN_TS: N. Original params used: none.
--
-- The INSERT below is the v2.1 branch INSERT verbatim. NO transaction
-- control and NO completion calls in this proc: the driver calls it
-- inside ONE publish transaction (all branches together, so a publish
-- either lands completely or not at all). Returns SQLROWCOUNT.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_pub_TRS_ADDR1_STG_TRS_D_UNQ_ADDR (
)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
INSERT INTO STG_TRS_D_UNQ_ADDR
           (ADDR_ID, ADDR_LN_1, ADDR_LN_2, BLDNG_NM, FLR_NUM, CITY, COUNTY, STATE, CNTRY_CD, PSTL_CD, PSTL_CD_EXT, LATTD,
            LNGTD, VLDTN_MSG, VLDTN_DESC, MLBLTY_SCR, ADDR_TP_CD, ORG_DESC, ORG_NM, BLDG_NMBR, SUB_BLDG_NM,
            SUB_BLDG_DESC, GEOCD_STS_CD, RSDNTL_DLVRY_IND, ADDRDR_RSLT_PCT, ERLY_WRNG_CD, CASS_ERR_CD, DLVRY_PNT_VLDN,
            SRC_ADDR_LN_1, SRC_ADDR_LN_2, SRC_CITY, SRC_COUNTY, SRC_STATE, SRC_CNTRY, SRC_PSTL_CD, SRC_PSTL_CD_EXT,
            ORG_DEPT)
    SELECT ADDR_ID, ADDR_LN_1, ADDR_LN_2, BLDNG_NM, FLR_NUM, CITY, COUNTY, STATE, CNTRY_CD, PSTL_CD, PSTL_CD_EXT, LATTD,
           LNGTD, VLDTN_MSG, VLDTN_DESC, MLBLTY_SCR, ADDR_TP_CD, ORG_DESC, ORG_NM, BLDG_NMBR, SUB_BLDG_NM,
           SUB_BLDG_DESC, GEOCD_STS_CD, RSDNTL_DLVRY_IND, ADDRDR_RSLT_PCT, ERLY_WRNG_CD, CASS_ERR_CD, DLVRY_PNT_VLDN,
           SRC_ADDR_LN_1, SRC_ADDR_LN_2, SRC_CITY, SRC_COUNTY, SRC_STATE, SRC_CNTRY, SRC_PSTL_CD, SRC_PSTL_CD_EXT,
           ORG_DEPT
      FROM WRK_TRS_ADDR1_S40_READY;
    RETURN SQLROWCOUNT;
END;
$$;
