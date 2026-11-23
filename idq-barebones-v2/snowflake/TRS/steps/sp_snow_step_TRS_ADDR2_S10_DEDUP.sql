-- ============================================================================
-- sp_snow_step_TRS_ADDR2_S10_DEDUP  --  BARE-BONES STEP (TRS)
--
-- Mapping: m_Tgt_C_S_TRS_Addr_2, workflow wf_TRS_Stage_Load_1_Ongoing.
-- Step name: ADDR_DEDUP. Produces: WRK_TRS_ADDR2_S10_DEDUP.
-- Consumes (v2.1 declared inputs): (base tables only).
-- Original params used: none; plus P_RUN_TS (run timestamp).
--
-- The CTAS below is the v2.1 step SELECT verbatim. The only removals
-- were the work-table existence check and the step completion call.
-- No exception block (errors propagate to the driver handler), no
-- transactions, no target writes. Returns the row count.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_step_TRS_ADDR2_S10_DEDUP (

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

    -- ---- Step 10: ADDR_DEDUP (verbatim from current main)
CREATE OR REPLACE TRANSIENT TABLE WRK_TRS_ADDR2_S10_DEDUP AS
    SELECT a.indv_id, a.case_num, a.edg_num, a.addr_type_cd,
           NVL(TO_VARCHAR(a.addr_st_num), '') || '|' || NVL(a.addr_st_num_frac, '') || '|'
           || NVL(a.addr_st_nm, '') || '|' || NVL(a.addr_st_dir_cd, '') || '|' || NVL(a.addr_st_type_cd, '')
           || '|' || NVL(a.addr_dwelling_type_cd, '') || '|' || NVL(a.addr_apt_num, '') || '|'
           || NVL(a.addr_line, '') || '|' || NVL(a.addr_city, '') || '|' || NVL(a.addr_state_cd, '') || '|'
           || NVL(TO_VARCHAR(a.addr_zip5), '') || '|' || NVL(TO_VARCHAR(a.addr_zip4), '') AS addr_id,
           GREATEST(a.create_dt, NVL(a.update_dt, a.create_dt)) AS create_dt, a.eff_begin_dt, a.eff_end_dt,
           ROW_NUMBER() OVER (PARTITION BY a.indv_id, a.addr_type_cd, a.case_num, a.edg_num
                              ORDER BY GREATEST(a.create_dt, NVL(a.update_dt, a.create_dt)) DESC,
                                       a.eff_begin_dt DESC) AS key_rn
      FROM STG_TRS_D_INDV_ADDR a;
    SELECT COUNT(*) INTO :l_rows FROM WRK_TRS_ADDR2_S10_DEDUP;
    RETURN :l_rows;
END;$$;
