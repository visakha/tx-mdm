-- ============================================================================
-- sp_snow_step_TRS_RELDEACT_S10_MINPK  --  BARE-BONES STEP (TRS)
--
-- Mapping: m_Tgt_C_S_TRS_Pty_Rle_Rel_DeActivation_1, workflow wf_TRS_Stage_Load_1_Ongoing.
-- Step name: MIN_PK. Produces: WRK_TRS_RELDEACT_S10_MINPK.
-- Consumes (v2.1 declared inputs): (base tables only).
-- Original params used: none; plus P_RUN_TS (run timestamp).
--
-- The CTAS below is the v2.1 step SELECT verbatim. The only removals
-- were the work-table existence check and the step completion call.
-- No exception block (errors propagate to the driver handler), no
-- transactions, no target writes. Returns the row count.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_step_TRS_RELDEACT_S10_MINPK (

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

    -- ---- Step 10: MIN_PK (verbatim from current main)
CREATE OR REPLACE TRANSIENT TABLE WRK_TRS_RELDEACT_S10_MINPK AS
    SELECT indv_id, MIN(pty_pk) pty_pk FROM STG_TRS_VALID_MEMBERS GROUP BY indv_id;
    SELECT COUNT(*) INTO :l_rows FROM WRK_TRS_RELDEACT_S10_MINPK;
    RETURN :l_rows;
END;$$;
