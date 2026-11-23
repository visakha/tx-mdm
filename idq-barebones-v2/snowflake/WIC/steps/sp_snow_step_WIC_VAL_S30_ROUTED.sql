-- ============================================================================
-- sp_snow_step_WIC_VAL_S30_ROUTED  --  BARE-BONES STEP DRIVER VARIANT (WIC)
--
-- Mapping: m_Tgt_C_S_WIC_Pty_Validation, workflow wf_WIC_Stage_Load.
-- Step 30: ROUTED.
-- Produces: WRK_WIC_VAL_S30_ROUTED -- Exception code, attribute name and value, new deactivation status from hub state, looked-up exception description and type, run constants, and the first-row-per-exception-key flag (uq_exc_name). Computed before publish, so routing sees the pre-run status.
-- Consumes: WRK_WIC_VAL_S20_NAMED
--
-- Bare-bones variant: stripped of config gating, job tracking and
-- input checks; the CTAS below is unchanged business SQL. The driver
-- passes the run timestamp; steps that do not use it still declare it
-- so every step call has the same shape.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_step_WIC_VAL_S30_ROUTED (
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
    CREATE OR REPLACE TRANSIENT TABLE WRK_WIC_VAL_S30_ROUTED AS
    WITH
    lkp_exc AS (SELECT * FROM TABLE(fn_snow_helper40_common())),
    routed AS (
        SELECT r.*,
               CASE WHEN fn_snow_helper03_common(r.std_first_name) THEN 'Missing_First_Name'
                    WHEN fn_snow_helper03_common(r.std_lst_name) THEN 'Missing_Last_Name' END  AS exc_code_name,
               CASE WHEN fn_snow_helper03_common(r.std_first_name) THEN 'First Name'
                    WHEN fn_snow_helper03_common(r.std_lst_name) THEN 'Last Name' END          AS exc_attribute_name,
               CASE WHEN fn_snow_helper03_common(r.std_first_name) THEN r.std_first_name
                    WHEN fn_snow_helper03_common(r.std_lst_name) THEN r.std_lst_name END       AS exc_attribute_value,
               fn_snow_helper02_common(r.hub_state_ind)                                        AS new_deactivation_sts
          FROM WRK_WIC_VAL_S20_NAMED r
    )
    SELECT r.*,
           ex.EXCEPTION_DESC     AS exc_desc_name,
           ex.EXCEPTION_TYPE     AS exc_type_name,
           'WIC'                 AS src_sys,
           :P_RUN_TS             AS run_ts,
           :c_mapping            AS mapping_name,
           'Deactivation'        AS action_deactivation,
           'Reactivation'        AS action_reactivation,
           /* BAD DATA: unique key of EXC_STG_BAD_REC_MEMB, first row per key in this run */
           ROW_NUMBER() OVER (PARTITION BY r.name_missing, r.PTY_SRC_KEY, ex.EXCEPTION_TYPE, r.exc_code_name
                                  ORDER BY r.DATEKEY DESC, r.ID) = 1 AS uq_exc_name
      FROM routed r
      LEFT JOIN lkp_exc ex ON ex.EXCEPTION_CODE = r.exc_code_name;;
    SELECT COUNT(*) INTO :l_rows FROM WRK_WIC_VAL_S30_ROUTED;
    RETURN :l_rows;
END;
$$;
