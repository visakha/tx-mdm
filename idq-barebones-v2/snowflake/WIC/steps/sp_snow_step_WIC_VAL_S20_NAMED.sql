-- ============================================================================
-- sp_snow_step_WIC_VAL_S20_NAMED  --  BARE-BONES STEP DRIVER VARIANT (WIC)
--
-- Mapping: m_Tgt_C_S_WIC_Pty_Validation, workflow wf_WIC_Stage_Load.
-- Step 20: NAMED_BLANK_TEST.
-- Produces: WRK_WIC_VAL_S20_NAMED -- Standardised first, middle and last names pulled out; the blank-name test applied (name_missing).
-- Consumes: WRK_WIC_VAL_S10_ENRICHED
--
-- Bare-bones variant: stripped of config gating, job tracking and
-- input checks; the CTAS below is unchanged business SQL. The driver
-- passes the run timestamp; steps that do not use it still declare it
-- so every step call has the same shape.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_step_WIC_VAL_S20_NAMED (
    P_RUN_TS                 TIMESTAMP_NTZ
)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    l_rows NUMBER DEFAULT 0;
BEGIN
    CREATE OR REPLACE TRANSIENT TABLE WRK_WIC_VAL_S20_NAMED AS
    SELECT n.*,
           n.nm:first_name::VARCHAR  AS std_first_name,
           n.nm:middle_name::VARCHAR AS std_mdl_name,
           n.nm:last_name::VARCHAR   AS std_lst_name,
           /* VALIDATION */ (fn_snow_helper03_common(n.nm:first_name::VARCHAR)
                             OR fn_snow_helper03_common(n.nm:last_name::VARCHAR)) AS name_missing
      FROM WRK_WIC_VAL_S10_ENRICHED n;;
    SELECT COUNT(*) INTO :l_rows FROM WRK_WIC_VAL_S20_NAMED;
    RETURN :l_rows;
END;
$$;
