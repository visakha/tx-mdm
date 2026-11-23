-- sp_snow_step_ECI_VAL_S30_ROUTED -- BARE-BONES variant (ECI)
-- Mapping: m_Tgt_C_S_ECI_Pty_Validation, workflow wf_ECI_Stage_Load, step 30 (ROUTED_GROUPS).
-- Produces: WRK_ECI_VAL_S30_ROUTED.
-- Runs unconditionally from the driver; no gating, no checkpointing.
-- Business SQL below is verbatim from the v2.1 step procedure.
CREATE OR REPLACE PROCEDURE sp_snow_step_ECI_VAL_S30_ROUTED (
    P_RUN_TS TIMESTAMP_NTZ
)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    c_mapping    VARCHAR DEFAULT 'm_Tgt_C_S_ECI_Pty_Validation';
    l_rows       NUMBER DEFAULT 0;
BEGIN
    -- ---- Step 30: ROUTING -- exception / deactivation / reactivation (verbatim from current main)
    CREATE OR REPLACE TRANSIENT TABLE WRK_ECI_VAL_S30_ROUTED AS
    WITH
    lkp_exc AS (SELECT * FROM TABLE(fn_snow_helper40_common())),
    named AS (
        SELECT n.*,
               n.nm:first_name::VARCHAR  AS std_first_name,
               n.nm:middle_name::VARCHAR AS std_mdl_name,
               n.nm:last_name::VARCHAR   AS std_lst_name,
               (fn_snow_helper03_common(n.nm:first_name::VARCHAR)
                OR fn_snow_helper03_common(n.nm:last_name::VARCHAR)) AS name_missing
          FROM WRK_ECI_VAL_S20_ENRICHED n
    ),
    routed AS (
        SELECT r.*,
               (r.name_missing AND r.fam_inactive_yn = 'N')                                  AS grp_invalid_party_name,
               (r.name_missing OR r.omit_id IS NOT NULL OR r.fam_inactive_yn = 'Y')          AS grp_deactivation,
               (r.deactivation_sts IS NOT NULL AND NOT r.name_missing AND r.omit_id IS NULL
                AND r.fam_inactive_yn = 'N')                                                 AS grp_reactivation,
               CASE WHEN fn_snow_helper03_common(r.std_first_name) THEN 'Missing_First_Name'
                    WHEN fn_snow_helper03_common(r.std_lst_name) THEN 'Missing_Last_Name' END AS exc_code_name,
               CASE WHEN fn_snow_helper03_common(r.std_first_name) THEN 'First Name'
                    WHEN fn_snow_helper03_common(r.std_lst_name) THEN 'Last Name' END        AS exc_attribute_name,
               CASE WHEN fn_snow_helper03_common(r.std_first_name) THEN r.std_first_name
                    WHEN fn_snow_helper03_common(r.std_lst_name) THEN r.std_lst_name END     AS exc_attribute_value,
               fn_snow_helper02_common(r.hub_state_ind)                                      AS new_deactivation_sts
          FROM named r
    )
    SELECT r.*,
           ex.EXCEPTION_DESC     AS exc_desc_name,
           ex.EXCEPTION_TYPE     AS exc_type_name,
           :P_RUN_TS             AS run_ts,
           :c_mapping            AS mapping_name,
           'Deactivation'        AS action_deactivation,
           'Reactivation'        AS action_reactivation,
           ROW_NUMBER() OVER (PARTITION BY r.grp_invalid_party_name, r.src_system, r.pkey_src_object,
                                           ex.EXCEPTION_TYPE, r.exc_code_name
                                  ORDER BY r.ID) = 1 AS uq_exc_name
      FROM routed r
      LEFT JOIN lkp_exc ex ON ex.EXCEPTION_CODE = r.exc_code_name;
    SELECT COUNT(*) INTO :l_rows FROM WRK_ECI_VAL_S30_ROUTED;
    RETURN :l_rows;
END;
$$;
