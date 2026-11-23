-- ============================================================================
-- sp_snow_step_TRS_ADDR2_S40_SCORED  --  BARE-BONES STEP (TRS)
--
-- Mapping: m_Tgt_C_S_TRS_Addr_2, workflow wf_TRS_Stage_Load_1_Ongoing.
-- Step name: SCORED_VERSIONED. Produces: WRK_TRS_ADDR2_S40_SCORED.
-- Consumes (v2.1 declared inputs): WRK_TRS_ADDR2_S30_KEYED.
-- Original params used: none; plus P_RUN_TS (run timestamp).
--
-- The CTAS below is the v2.1 step SELECT verbatim. The only removals
-- were the work-table existence check and the step completion call.
-- No exception block (errors propagate to the driver handler), no
-- transactions, no target writes. Returns the row count.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_step_TRS_ADDR2_S40_SCORED (

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

    -- ---- Step 40: SCORED_VERSIONED (verbatim from current main)
CREATE OR REPLACE TRANSIENT TABLE WRK_TRS_ADDR2_S40_SCORED AS
    SELECT k.*,
           fn_snow_helper05_common(k.mstr_addr_tp, k.MLBLTY_SCR, k.VLDTN_MSG)     AS score,
           fn_snow_helper06_common(k.mstr_addr_tp, k.MLBLTY_SCR, k.VLDTN_MSG)     AS addr_issue_desc,
           ROW_NUMBER() OVER (PARTITION BY k.pkey_pty_rle_addr
                              ORDER BY k.CREATE_DT DESC NULLS FIRST, k.EFF_END_DT DESC NULLS FIRST,
                                       k.EFF_BEGIN_DT DESC NULLS FIRST)          AS version_seq
      FROM WRK_TRS_ADDR2_S30_KEYED k;
    SELECT COUNT(*) INTO :l_rows FROM WRK_TRS_ADDR2_S40_SCORED;
    RETURN :l_rows;
END;$$;
