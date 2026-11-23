-- ============================================================================
-- sp_snow_step_TRS_REL1_S40_CONSOL  --  BARE-BONES STEP (TRS)
--
-- Mapping: m_Tgt_C_S_TRS_Pty_Rle_Rel_1_Mem_To_Mem, workflow wf_TRS_Stage_Load_1_Ongoing.
-- Step name: CONSOLIDATED. Produces: WRK_TRS_REL1_S4_CONSOL.
-- Consumes (v2.1 declared inputs): WRK_TRS_REL1_S2_KEYED.
-- Original params used: none; plus P_RUN_TS (run timestamp).
--
-- The CTAS below is the v2.1 step SELECT verbatim. The only removals
-- were the work-table existence check and the step completion call.
-- No exception block (errors propagate to the driver handler), no
-- transactions, no target writes. Returns the row count.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_step_TRS_REL1_S40_CONSOL (

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

    -- ---- Step 40: CONSOLIDATED (verbatim from current main)
CREATE OR REPLACE TRANSIENT TABLE WRK_TRS_REL1_S4_CONSOL AS
    SELECT r.*
      FROM WRK_TRS_REL1_S2_KEYED r
     WHERE r.pty_rle_fk_1 IS NOT NULL AND r.pty_rle_fk_2 IS NOT NULL AND r.rel_type_code IS NOT NULL
       AND NOT r.dates_reversed
    QUALIFY ROW_NUMBER() OVER (PARTITION BY r.pkey_src_object, r.EFF_END_DT, r.EFF_BEGIN_DT
                                  ORDER BY r.CREATE_DT DESC NULLS FIRST, r.UPDATE_DT DESC NULLS FIRST) = 1;
    SELECT COUNT(*) INTO :l_rows FROM WRK_TRS_REL1_S4_CONSOL;
    RETURN :l_rows;
END;$$;
