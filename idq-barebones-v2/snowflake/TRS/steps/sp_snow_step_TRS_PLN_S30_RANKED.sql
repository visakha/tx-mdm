-- ============================================================================
-- sp_snow_step_TRS_PLN_S30_RANKED  --  BARE-BONES STEP (TRS)
--
-- Mapping: m_Tgt_C_S_TRS_Pty_Rle_Pln, workflow wf_TRS_Stage_Load_1_Ongoing.
-- Step name: RANKED. Produces: WRK_TRS_PLN_S30_RANKED.
-- Consumes (v2.1 declared inputs): WRK_TRS_PLN_S20_PLANNED.
-- Original params used: none; plus P_RUN_TS (run timestamp).
--
-- The CTAS below is the v2.1 step SELECT verbatim. The only removals
-- were the work-table existence check and the step completion call.
-- No exception block (errors propagate to the driver handler), no
-- transactions, no target writes. Returns the row count.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_step_TRS_PLN_S30_RANKED (

    P_RUN_TS                 TIMESTAMP_NTZ DEFAULT NULL

)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    c_mapping    VARCHAR DEFAULT 'm_Tgt_C_S_TRS_Pty_Rle_Pln';
    l_rows       NUMBER DEFAULT 0;
BEGIN

    -- ---- Step 30: RANKED (verbatim from current main)
CREATE OR REPLACE TRANSIENT TABLE WRK_TRS_PLN_S30_RANKED AS
    WITH lkp_exc AS (SELECT * FROM TABLE(fn_snow_helper40_common()))
    SELECT p.*,
           ROW_NUMBER() OVER (PARTITION BY p.pkey_prty_rl_plan
                              ORDER BY p.BEGIN_DT DESC NULLS FIRST, p.END_DT DESC NULLS FIRST,
                                       p.pty_rle_fk DESC NULLS FIRST, p.CREATE_DT DESC NULLS FIRST) AS rn_key,
           ROW_NUMBER() OVER (PARTITION BY p.INDV_ID, p.pln_mstr_cd IS NULL
                              ORDER BY p.MC_PLAN, p.BEGIN_DT, p.END_DT) AS rn_invalid,
           xp.PKEY_SRC_OBJECT IS NULL AS uq_pln,
           1 AS version_seq,
           'TRS' AS src_sys,
           :P_RUN_TS AS run_ts,
           :c_mapping AS mapping_name,
           'Plan' AS attr_plan,
           'Invalid_Plan' AS exc_code,
           ex.EXCEPTION_DESC AS exc_desc,
           ex.EXCEPTION_TYPE AS exc_type,
           TO_VARCHAR(p.BEGIN_DT, 'YYYY-MM-DD') AS begin_dt_text
      FROM WRK_TRS_PLN_S20_PLANNED p
      LEFT JOIN lkp_exc ex ON ex.EXCEPTION_CODE = 'Invalid_Plan'
      LEFT JOIN (SELECT DISTINCT PKEY_SRC_OBJECT FROM C_S_TRS_PTY_RLE_PLN WHERE VERSION_SEQ = 1) xp
             ON xp.PKEY_SRC_OBJECT = p.pkey_prty_rl_plan;
    SELECT COUNT(*) INTO :l_rows FROM WRK_TRS_PLN_S30_RANKED;
    RETURN :l_rows;
END;$$;
