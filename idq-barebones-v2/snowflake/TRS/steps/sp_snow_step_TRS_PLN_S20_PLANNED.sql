-- ============================================================================
-- sp_snow_step_TRS_PLN_S20_PLANNED  --  BARE-BONES STEP (TRS)
--
-- Mapping: m_Tgt_C_S_TRS_Pty_Rle_Pln, workflow wf_TRS_Stage_Load_1_Ongoing.
-- Step name: PLAN_TRANSLATED. Produces: WRK_TRS_PLN_S20_PLANNED.
-- Consumes (v2.1 declared inputs): WRK_TRS_PLN_S10_SRC.
-- Original params used: none; plus P_RUN_TS (run timestamp).
--
-- The CTAS below is the v2.1 step SELECT verbatim. The only removals
-- were the work-table existence check and the step completion call.
-- No exception block (errors propagate to the driver handler), no
-- transactions, no target writes. Returns the row count.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_step_TRS_PLN_S20_PLANNED (

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

    -- ---- Step 20: PLAN_TRANSLATED (verbatim from current main)
CREATE OR REPLACE TRANSIENT TABLE WRK_TRS_PLN_S20_PLANNED AS
    WITH lkp_cv AS (SELECT * FROM TABLE(fn_snow_helper41_common()))
    SELECT s.*,
           lk.MSTR_CODE_VALUE AS pln_mstr_cd,
           TO_VARCHAR(s.INDV_ID) || '|Member' AS pty_rle_fk,
           TO_VARCHAR(s.INDV_ID) || '|Member|' || NVL(lk.MSTR_CODE_VALUE, '') AS pkey_prty_rl_plan
      FROM WRK_TRS_PLN_S10_SRC s
      LEFT JOIN lkp_cv lk ON lk.CODE_TYPE = 'PLAN_CD' AND lk.SRC_SYS = 'MAX' AND lk.SRC_CODE_VALUE = s.MC_PLAN;
    SELECT COUNT(*) INTO :l_rows FROM WRK_TRS_PLN_S20_PLANNED;
    RETURN :l_rows;
END;$$;
