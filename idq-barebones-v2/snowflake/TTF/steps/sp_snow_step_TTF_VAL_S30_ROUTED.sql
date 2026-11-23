-- ============================================================================
-- sp_snow_step_TTF_VAL_S30_ROUTED -- BARE-BONES variant (TTF)
--
-- Mapping: m_Tgt_C_S_TTF_Pty_Validation. No config table, no checkpointing, no job-run id,
-- no input-existence check: the CTAS below is verbatim from v2.1 and
-- names its source work table literally. Returns the row count.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_step_TTF_VAL_S30_ROUTED (
    P_RUN_TS TIMESTAMP_NTZ
)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    c_mapping    VARCHAR DEFAULT 'm_Tgt_C_S_TTF_Pty_Validation';
    l_rows       NUMBER DEFAULT 0;
BEGIN
    -- ---- Step 30: ROUTED (verbatim from current main)
CREATE OR REPLACE TRANSIENT TABLE WRK_TTF_VAL_S3_ROUTED AS
    WITH
    lkp_exc  AS (SELECT * FROM TABLE(fn_snow_helper40_common())),
    -- Rtr_Valid_Party + Exp_Invalid_PTY_NM
    routed AS (
        SELECT r.*,
               (r.name_missing OR r.name_declined OR r.name_undisclosed)                      AS grp_invalid_party_name,
               (r.name_missing OR r.name_declined OR NVL(r.CLIENT_EXISTS_FLAG = 'N', FALSE))  AS grp_deactivation,
               NVL(r.deactivation_sts IS NOT NULL AND NOT r.name_missing
                   AND NOT (UPPER(r.std_lst_name) = 'DECLINED') AND NOT (UPPER(r.std_first_name) = 'DECLINED')
                   AND r.CLIENT_EXISTS_FLAG = 'Y', FALSE)                                      AS grp_reactivation,
               CASE WHEN fn_snow_helper03_common(r.std_first_name) THEN 'Missing_First_Name'
                    WHEN UPPER(TRIM(r.std_first_name)) IN ('DECLINED', 'DO_NOT_DISCLOSE') THEN 'Invalid_First_Name'
                    WHEN fn_snow_helper03_common(r.std_lst_name) THEN 'Missing_Last_Name'
                    WHEN UPPER(TRIM(r.std_lst_name)) IN ('DECLINED', 'DO_NOT_DISCLOSE') THEN 'Invalid_Last_Name'
                    ELSE 'Valid' END                                                           AS exc_code_name,
               fn_snow_helper02_common(r.hub_state_ind)                                        AS new_deactivation_sts
          FROM WRK_TTF_VAL_S2_NAMED r
    )
    SELECT r.*,
           ex.EXCEPTION_DESC     AS exc_desc_name,
           ex.EXCEPTION_TYPE     AS exc_type_name,
           'TTF'                 AS src_sys,
           :P_RUN_TS             AS run_ts,
           :c_mapping            AS mapping_name,
           'Deactivation'        AS action_deactivation,
           'Reactivation'        AS action_reactivation,
           /* BAD DATA: unique key of EXC_STG_BAD_REC_MEMB, first row per key in this run */
           ROW_NUMBER() OVER (PARTITION BY r.grp_invalid_party_name, r.pkey_src_object, ex.EXCEPTION_TYPE,
                                           r.exc_code_name ORDER BY r.SUBMITDATE DESC, r.CLIENTS_ID) = 1 AS uq_exc_name
      FROM routed r
      LEFT JOIN lkp_exc ex ON ex.EXCEPTION_CODE = r.exc_code_name;
    SELECT COUNT(*) INTO :l_rows FROM WRK_TTF_VAL_S3_ROUTED;
    RETURN :l_rows;
END;
$$;
