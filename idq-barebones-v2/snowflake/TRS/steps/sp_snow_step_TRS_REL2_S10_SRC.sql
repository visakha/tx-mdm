-- ============================================================================
-- sp_snow_step_TRS_REL2_S10_SRC  --  BARE-BONES STEP (TRS)
--
-- Mapping: m_Tgt_C_S_TRS_Pty_Rle_Rel_2_Mem_To_PCP, workflow wf_TRS_Stage_Load_1_Ongoing.
-- Step name: SRC_MANAGED_CARE. Produces: WRK_TRS_REL2_S1_SRC.
-- Consumes (v2.1 declared inputs): (base tables only).
-- Original params used: none; plus P_RUN_TS (run timestamp).
--
-- The CTAS below is the v2.1 step SELECT verbatim. The only removals
-- were the work-table existence check and the step completion call.
-- No exception block (errors propagate to the driver handler), no
-- transactions, no target writes. Returns the row count.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_step_TRS_REL2_S10_SRC (

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

    -- ---- Step 10: SRC_MANAGED_CARE (verbatim from current main)
CREATE OR REPLACE TRANSIENT TABLE WRK_TRS_REL2_S1_SRC AS
    WITH
    min_pk AS (
        SELECT indv_id, MIN(pty_pk) pty_pk FROM STG_TRS_VALID_MEMBERS GROUP BY indv_id
    )
    SELECT mc.indv_id AS INDV_ID, mc.history_seq AS HISTORY_SEQ, mc.mc_prog_code AS MC_PROG_CODE,
           mc.begin_dt AS BEGIN_DT, mc.create_dt AS CREATE_DT, mc.provider_num AS PROVIDER_NUM,
           mc.end_dt AS END_DT, vm.pty_pk AS PTY_PK
      FROM STG_TRS_D_IN_MANAGED_CARE mc
      JOIN min_pk vm ON mc.indv_id = vm.indv_id
     WHERE mc.provider_num IS NOT NULL
       AND fn_snow_helper01_common(mc.provider_num) = 1;
    SELECT COUNT(*) INTO :l_rows FROM WRK_TRS_REL2_S1_SRC;
    RETURN :l_rows;
END;$$;
