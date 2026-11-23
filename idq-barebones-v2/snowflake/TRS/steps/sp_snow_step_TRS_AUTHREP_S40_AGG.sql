-- ============================================================================
-- sp_snow_step_TRS_AUTHREP_S40_AGG  --  BARE-BONES STEP (TRS)
--
-- Mapping: m_Tgt_C_S_TRS_Pty_Mng_Attr_Auth_Rep_Ongoing, workflow wf_TRS_Stage_Load_1_Ongoing.
-- Step name: AGG_DEDUP. Produces: WRK_TRS_MNGAR_S40_AGG.
-- Consumes (v2.1 declared inputs): WRK_TRS_MNGAR_S30_KEYED.
-- Original params used: none; plus P_RUN_TS (run timestamp).
--
-- The CTAS below is the v2.1 step SELECT verbatim. The only removals
-- were the work-table existence check and the step completion call.
-- No exception block (errors propagate to the driver handler), no
-- transactions, no target writes. Returns the row count.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_step_TRS_AUTHREP_S40_AGG (

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

    -- ---- Step 40: AGG_DEDUP (verbatim from current main)
CREATE OR REPLACE TRANSIENT TABLE WRK_TRS_MNGAR_S40_AGG AS
    SELECT k.*,
           MAX(k.EFF_END_DT) OVER (PARTITION BY k.pkey_src_object) AS max_eff_end_dt,
           ROW_NUMBER() OVER (PARTITION BY k.pkey_src_object
                              ORDER BY k.EFF_BEGIN_DT DESC NULLS FIRST, k.EFF_END_DT DESC NULLS FIRST,
                                       k.CREATE_DT DESC NULLS FIRST) AS rn
      FROM WRK_TRS_MNGAR_S30_KEYED k;
    SELECT COUNT(*) INTO :l_rows FROM WRK_TRS_MNGAR_S40_AGG;
    RETURN :l_rows;
END;$$;
