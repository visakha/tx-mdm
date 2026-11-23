-- ============================================================================
-- sp_snow_step_TRS_NM_S30_STD  --  BARE-BONES STEP (TRS)
--
-- Mapping: m_Tgt_C_S_TRS_Pty_Nm, workflow wf_TRS_Stage_Load_1_Ongoing.
-- Step name: STANDARDISED. Produces: WRK_TRS_NM_S30_STD.
-- Consumes (v2.1 declared inputs): WRK_TRS_NM_S20_NAMED.
-- Original params used: none; plus P_RUN_TS (run timestamp).
--
-- The CTAS below is the v2.1 step SELECT verbatim. The only removals
-- were the work-table existence check and the step completion call.
-- No exception block (errors propagate to the driver handler), no
-- transactions, no target writes. Returns the row count.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_step_TRS_NM_S30_STD (

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

    -- ---- Step 30: STANDARDISED (verbatim from current main)
CREATE OR REPLACE TRANSIENT TABLE WRK_TRS_NM_S30_STD AS
    WITH lkp_junk AS (SELECT * FROM TABLE(fn_snow_helper43_common()))
    SELECT n.*,
           fn_snow_helper15_common(n.tn:first_name::VARCHAR, n.tn:middle_name::VARCHAR, n.tn:last_name::VARCHAR,
                                   n.src_full_name, n.PREFIX_NAME, n.SUFX_NAME, NULL, NULL,
                                   jf.NAME IS NOT NULL, jl.NAME IS NOT NULL) AS nm
      FROM WRK_TRS_NM_S20_NAMED n
      LEFT JOIN lkp_junk jf ON jf.NAME = UPPER(TRIM(n.tn:first_name::VARCHAR)) AND jf.IS_FIRST_JUNK
      LEFT JOIN lkp_junk jl ON jl.NAME = UPPER(TRIM(n.tn:last_name::VARCHAR)) AND jl.IS_LAST_JUNK;
    SELECT COUNT(*) INTO :l_rows FROM WRK_TRS_NM_S30_STD;
    RETURN :l_rows;
END;$$;
