-- ============================================================================
-- sp_snow_step_TRS_REL1_S50_PREP  --  BARE-BONES STEP (TRS)
--
-- Mapping: m_Tgt_C_S_TRS_Pty_Rle_Rel_1_Mem_To_Mem, workflow wf_TRS_Stage_Load_1_Ongoing.
-- Step name: PREPARED. Produces: WRK_TRS_REL1_S5_PREP.
-- Consumes (v2.1 declared inputs): WRK_TRS_REL1_S4_CONSOL.
-- Original params used: none; plus P_RUN_TS (run timestamp).
--
-- The CTAS below is the v2.1 step SELECT verbatim. The only removals
-- were the work-table existence check and the step completion call.
-- No exception block (errors propagate to the driver handler), no
-- transactions, no target writes. Returns the row count.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_step_TRS_REL1_S50_PREP (

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

    -- ---- Step 50: PREPARED (verbatim from current main)
CREATE OR REPLACE TRANSIENT TABLE WRK_TRS_REL1_S5_PREP AS
    WITH
    lkp_dst AS (SELECT * FROM TABLE(fn_snow_helper47_common()))
    SELECT c.*,
           IFF(c.CREATE_DT IS NOT NULL AND c.UPDATE_DT IS NOT NULL, GREATEST(c.CREATE_DT, c.UPDATE_DT),
               NVL(c.CREATE_DT, c.UPDATE_DT))                                      AS src_last_upd_dt,
           /* TIMELINE */ fn_snow_helper35_common(c.EFF_BEGIN_DT, c.EFF_END_DT, d.DST IS NOT NULL) AS dst_end_date
      FROM WRK_TRS_REL1_S4_CONSOL c
      LEFT JOIN lkp_dst d ON d.DST = DATEADD(hour, 2, c.EFF_END_DT);
    SELECT COUNT(*) INTO :l_rows FROM WRK_TRS_REL1_S5_PREP;
    RETURN :l_rows;
END;$$;
