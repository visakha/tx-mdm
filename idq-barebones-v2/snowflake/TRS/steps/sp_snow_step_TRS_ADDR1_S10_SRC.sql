-- ============================================================================
-- sp_snow_step_TRS_ADDR1_S10_SRC  --  BARE-BONES STEP (TRS)
--
-- Mapping: m_Tgt_C_S_TRS_Addr_1, workflow wf_TRS_Stage_Load_1_Ongoing.
-- Step name: SRC_DISTINCT_ADDR. Produces: WRK_TRS_ADDR1_S10_SRC.
-- Consumes (v2.1 declared inputs): (base tables only).
-- Original params used: none; plus P_RUN_TS (run timestamp).
--
-- The CTAS below is the v2.1 step SELECT verbatim. The only removals
-- were the work-table existence check and the step completion call.
-- No exception block (errors propagate to the driver handler), no
-- transactions, no target writes. Returns the row count.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_step_TRS_ADDR1_S10_SRC (

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

    -- ---- Step 10: SRC_DISTINCT_ADDR (verbatim from current main)
CREATE OR REPLACE TRANSIENT TABLE WRK_TRS_ADDR1_S10_SRC AS
    SELECT DISTINCT
           NVL(TO_VARCHAR(a.addr_st_num), '') || '|' || NVL(a.addr_st_num_frac, '') || '|' || NVL(a.addr_st_nm, '')
           || '|' || NVL(a.addr_st_dir_cd, '') || '|' || NVL(a.addr_st_type_cd, '') || '|'
           || NVL(a.addr_dwelling_type_cd, '') || '|' || NVL(a.addr_apt_num, '') || '|' || NVL(a.addr_line, '')
           || '|' || NVL(a.addr_city, '') || '|' || NVL(a.addr_state_cd, '') || '|' || NVL(TO_VARCHAR(a.addr_zip5), '')
           || '|' || NVL(TO_VARCHAR(a.addr_zip4), '')                                   AS ADDR_ID,
           a.addr_st_num AS ADDR_ST_NUM, a.addr_st_num_frac AS ADDR_ST_NUM_FRAC, a.addr_st_nm AS ADDR_ST_NM,
           a.addr_apt_num AS ADDR_APT_NUM, a.addr_line AS ADDR_LINE, a.addr_city AS ADDR_CITY,
           a.addr_state_cd AS ADDR_STATE_CD, a.addr_zip5 AS ADDR_ZIP5, a.addr_zip4 AS ADDR_ZIP4,
           a.addr_dwelling_type_cd AS ADDR_DWELLING_TYPE_CD, a.addr_st_type_cd AS ADDR_ST_TYPE_CD,
           a.addr_st_dir_cd AS ADDR_ST_DIR_CD
      FROM STG_TRS_D_INDV_ADDR a;
    SELECT COUNT(*) INTO :l_rows FROM WRK_TRS_ADDR1_S10_SRC;
    RETURN :l_rows;
END;$$;
