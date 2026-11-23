-- ============================================================================
-- sp_snow_step_TRS_AUTHREP_S20_SRC  --  BARE-BONES STEP (TRS)
--
-- Mapping: m_Tgt_C_S_TRS_Pty_Mng_Attr_Auth_Rep_Ongoing, workflow wf_TRS_Stage_Load_1_Ongoing.
-- Step name: VALID_SRC. Produces: WRK_TRS_MNGAR_S20_SRC.
-- Consumes (v2.1 declared inputs): WRK_TRS_MNGAR_S10_PAYEE.
-- Original params used: none; plus P_RUN_TS (run timestamp).
--
-- The CTAS below is the v2.1 step SELECT verbatim. The only removals
-- were the work-table existence check and the step completion call.
-- No exception block (errors propagate to the driver handler), no
-- transactions, no target writes. Returns the row count.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_step_TRS_AUTHREP_S20_SRC (

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

    -- ---- Step 20: VALID_SRC (verbatim from current main)
CREATE OR REPLACE TRANSIENT TABLE WRK_TRS_MNGAR_S20_SRC AS
    SELECT DISTINCT a.indv_id AS INDV_ID, a.AR_FLAG, a.eff_begin_dt AS EFF_BEGIN_DT, a.eff_end_dt AS EFF_END_DT,
           a.create_dt AS CREATE_DT
      FROM WRK_TRS_MNGAR_S10_PAYEE a
      JOIN STG_TRS_VALID_MEMBERS IM ON TO_VARCHAR(a.INDV_ID) = IM.PTY_PK;
    SELECT COUNT(*) INTO :l_rows FROM WRK_TRS_MNGAR_S20_SRC;
    RETURN :l_rows;
END;$$;
