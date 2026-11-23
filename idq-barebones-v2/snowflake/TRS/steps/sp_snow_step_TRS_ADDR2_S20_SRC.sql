-- ============================================================================
-- sp_snow_step_TRS_ADDR2_S20_SRC  --  BARE-BONES STEP (TRS)
--
-- Mapping: m_Tgt_C_S_TRS_Addr_2, workflow wf_TRS_Stage_Load_1_Ongoing.
-- Step name: SRC_VALIDATED_JOIN. Produces: WRK_TRS_ADDR2_S20_SRC.
-- Consumes (v2.1 declared inputs): WRK_TRS_ADDR2_S10_DEDUP.
-- Original params used: none; plus P_RUN_TS (run timestamp).
--
-- The CTAS below is the v2.1 step SELECT verbatim. The only removals
-- were the work-table existence check and the step completion call.
-- No exception block (errors propagate to the driver handler), no
-- transactions, no target writes. Returns the row count.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_step_TRS_ADDR2_S20_SRC (

    P_RUN_TS                 TIMESTAMP_NTZ DEFAULT NULL

)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    l_rows       NUMBER DEFAULT 0;
BEGIN

    -- ---- Step 20: SRC_VALIDATED_JOIN (verbatim from current main)
CREATE OR REPLACE TRANSIENT TABLE WRK_TRS_ADDR2_S20_SRC AS
    SELECT a.indv_id AS INDV_ID, a.case_num AS CASE_NUM, a.edg_num AS EDG_NUM, vm.pty_pk AS PTY_PK,
           a.addr_type_cd AS ADDR_TYPE_CD, a.create_dt AS CREATE_DT, a.eff_begin_dt AS EFF_BEGIN_DT,
           a.eff_end_dt AS EFF_END_DT, u.addr_id AS ADDR_ID, u.addr_ln_1 AS ADDR_LN_1, u.addr_ln_2 AS ADDR_LN_2,
           u.bldng_nm AS BLDNG_NM, u.flr_num AS FLR_NUM, u.city AS CITY, u.county AS COUNTY, u.state AS STATE,
           u.cntry_cd AS CNTRY_CD, u.pstl_cd AS PSTL_CD, u.pstl_cd_ext AS PSTL_CD_EXT, u.lattd AS LATTD,
           u.lngtd AS LNGTD, u.vldtn_msg AS VLDTN_MSG, u.vldtn_desc AS VLDTN_DESC, u.mlblty_scr AS MLBLTY_SCR,
           u.addr_tp_cd AS ADDR_TP_CD, u.org_desc AS ORG_DESC, u.org_dept AS ORG_DEPT, u.org_nm AS ORG_NM,
           u.bldg_nmbr AS BLDG_NMBR, u.sub_bldg_nm AS SUB_BLDG_NM, u.sub_bldg_desc AS SUB_BLDG_DESC,
           u.geocd_sts_cd AS GEOCD_STS_CD, u.rsdntl_dlvry_ind AS RSDNTL_DLVRY_IND,
           u.addrdr_rslt_pct AS ADDRDR_RSLT_PCT, u.erly_wrng_cd AS ERLY_WRNG_CD, u.cass_err_cd AS CASS_ERR_CD,
           u.dlvry_pnt_vldn AS DLVRY_PNT_VLDN, u.src_addr_ln_1 AS SRC_ADDR_LN_1,
           u.src_addr_ln_2 AS SRC_ADDR_LN_2, u.src_city AS SRC_CITY, u.src_county AS SRC_COUNTY,
           u.src_state AS SRC_STATE, u.src_cntry AS SRC_CNTRY, u.src_pstl_cd AS SRC_PSTL_CD,
           u.src_pstl_cd_ext AS SRC_PSTL_CD_EXT
      FROM WRK_TRS_ADDR2_S10_DEDUP a
      JOIN STG_TRS_D_UNQ_ADDR u ON a.addr_id = u.addr_id
      JOIN STG_TRS_VALID_MEMBERS vm ON a.indv_id = vm.indv_id
     WHERE a.key_rn = 1;
    SELECT COUNT(*) INTO :l_rows FROM WRK_TRS_ADDR2_S20_SRC;
    RETURN :l_rows;
END;$$;
