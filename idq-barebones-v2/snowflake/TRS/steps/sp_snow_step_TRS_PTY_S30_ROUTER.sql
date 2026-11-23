-- ============================================================================
-- sp_snow_step_TRS_PTY_S30_ROUTER  --  BARE-BONES STEP (TRS)
--
-- Mapping: m_Tgt_C_S_TRS_Pty_OnGoing, workflow wf_TRS_Stage_Load_1_Ongoing.
-- Step name: ROUTER_EXCEPTIONS. Produces: WRK_TRS_PTY_S3_ROUTER.
-- Consumes (v2.1 declared inputs): WRK_TRS_PTY_S2_DQ.
-- Original params used: none; plus P_RUN_TS (run timestamp).
--
-- The CTAS below is the v2.1 step SELECT verbatim. The only removals
-- were the work-table existence check and the step completion call.
-- No exception block (errors propagate to the driver handler), no
-- transactions, no target writes. Returns the row count.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_step_TRS_PTY_S30_ROUTER (

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

    -- ---- Step 30: ROUTER_EXCEPTIONS (verbatim from current main)
CREATE OR REPLACE TRANSIENT TABLE WRK_TRS_PTY_S3_ROUTER AS
    WITH
    lkp_exc AS (SELECT * FROM TABLE(fn_snow_helper40_common())),
    router AS (
        SELECT b.*,
               CASE WHEN fn_snow_helper03_common(b.std_first_name) THEN 'Missing_First_Name'
                    WHEN fn_snow_helper03_common(b.std_lst_name) THEN 'Missing_Last_Name' END  AS name_exception_code,
               CASE WHEN fn_snow_helper03_common(b.std_first_name) THEN 'First Name'
                    WHEN fn_snow_helper03_common(b.std_lst_name) THEN 'Last Name' END          AS name_attribute_name,
               CASE WHEN fn_snow_helper03_common(b.std_first_name) THEN b.std_first_name
                    WHEN fn_snow_helper03_common(b.std_lst_name) THEN b.std_lst_name END       AS name_attribute_value
          FROM WRK_TRS_PTY_S2_DQ b
    )
    SELECT r.*,
           xn.EXCEPTION_TYPE AS name_exception_type,
           xn.EXCEPTION_DESC AS name_exception_desc,
           ROW_NUMBER() OVER (PARTITION BY r.name_missing, r.pkey_src_object, xn.EXCEPTION_TYPE,
                                           r.name_exception_code ORDER BY r.CREATE_DT DESC) = 1   AS uq_exc_name,
           ROW_NUMBER() OVER (PARTITION BY r.gender_exception_description IS NOT NULL, r.pkey_src_object,
                                           r.gender_exception_type, r.gender_exception_code
                                  ORDER BY r.CREATE_DT DESC) = 1                                 AS uq_exc_gender,
           ROW_NUMBER() OVER (PARTITION BY r.death_exception_desc IS NOT NULL, r.pkey_src_object,
                                           r.death_exception_type, r.death_exception_lkp_code
                                  ORDER BY r.CREATE_DT DESC) = 1                                 AS uq_exc_death,
           ROW_NUMBER() OVER (PARTITION BY r.birth_exception_code IS NOT NULL, r.pkey_src_object,
                                           r.birth_exception_type, r.birth_exception_code
                                  ORDER BY r.CREATE_DT DESC) = 1                                 AS uq_exc_birth
      FROM router r
      LEFT JOIN lkp_exc xn ON xn.EXCEPTION_CODE = r.name_exception_code;
    SELECT COUNT(*) INTO :l_rows FROM WRK_TRS_PTY_S3_ROUTER;
    RETURN :l_rows;
END;$$;
