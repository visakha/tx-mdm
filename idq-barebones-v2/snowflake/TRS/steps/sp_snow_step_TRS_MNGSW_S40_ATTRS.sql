-- ============================================================================
-- sp_snow_step_TRS_MNGSW_S40_ATTRS  --  BARE-BONES STEP (TRS)
--
-- Mapping: m_Tgt_C_S_TRS_Pty_Mng_Attr_Sw, workflow wf_TRS_Stage_Load_1_Ongoing.
-- Step name: FILTERED_ATTRS. Produces: WRK_TRS_MNGSW_S40_ATTRS.
-- Consumes (v2.1 declared inputs): WRK_TRS_MNGSW_S30_NORM.
-- Original params used: none; plus P_RUN_TS (run timestamp).
--
-- The CTAS below is the v2.1 step SELECT verbatim. The only removals
-- were the work-table existence check and the step completion call.
-- No exception block (errors propagate to the driver handler), no
-- transactions, no target writes. Returns the row count.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_step_TRS_MNGSW_S40_ATTRS (

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

    -- ---- Step 40: FILTERED_ATTRS (verbatim from current main)
CREATE OR REPLACE TRANSIENT TABLE WRK_TRS_MNGSW_S40_ATTRS AS
    SELECT DISTINCT NVL(a.PTY_PK, '') || '|' || a.ATTR_TYPE AS pkey_src_object, a.EFF_BEGIN_DT, a.PTY_PK,
           a.ATTR_TYPE, a.ATTR_VALUE, a.SRC_LAST_UPD_DT
      FROM WRK_TRS_MNGSW_S30_NORM a
     WHERE NOT fn_snow_helper03_common(a.ATTR_VALUE);
    SELECT COUNT(*) INTO :l_rows FROM WRK_TRS_MNGSW_S40_ATTRS;
    RETURN :l_rows;
END;$$;
