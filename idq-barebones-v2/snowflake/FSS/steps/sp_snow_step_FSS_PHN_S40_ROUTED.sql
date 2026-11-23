-- ============================================================================
-- BARE-BONES STRIP of the v2.1 config-driven step driver (FSS).
-- Removed: the COMMON.ETL_RUN_CONFIG_TBL GATHER block, all flags /
-- consumed strings / driver-row gate, all sp_etl_checkpoint /
-- sp_etl_job_begin / sp_etl_job_finish / sp_etl_job_fail calls,
-- P_JOB_RUN_ID, P_INPUT_TABLES, l_job_run_id, l_flag_*, l_in_*, l_pub_*,
-- step existence-check / probe blocks, and the seed file (not copied).
-- Kept verbatim: step-5 DROP TABLE IF EXISTS cleanup, step call order,
-- the single publish transaction with branches in order, every step CTAS
-- and every publish INSERT, and the fn_snow_helper36_common summary lines
-- (publish lines now appended inside the transaction, in the same order,
-- reusing l_rows instead of the removed l_pub_* variables, so the
-- returned summary string is unchanged in content and order).
-- NOTE: the v2.1 header below is retained for its business-flow and
-- parity notes; its CONFIG-DRIVEN NOTES / TRANSACTION EDGES / SIGNATURE /
-- FRAMEWORK paragraphs describe the v2.1 code and no longer apply.
-- ============================================================================
-- ============================================================================
-- sp_snow_step_FSS_PHN_S40_ROUTED  --  BARE-BONES STEP DRIVER (FSS)
--
-- Mapping: m_Tgt_C_S_FSS_Pty_Rle_Phn_And_EAddr, workflow wf_FSS_Stage_Load, step 40.
-- Step name (checkpoint): ROUTED.
--
-- WHAT THIS STEP PRODUCES
--   WRK_FSS_PHN_S4_ROUTED: Exception details, good / bad groups for e-mail, phone and extension, insert-only guards.
--
-- INPUTS / DEPENDENCY DECLARATION
--   P_INPUT_TABLES lists WORK-TABLE inputs only (default: 'WRK_FSS_PHN_S3_CHECKED').
--   Snowflake cannot parameterise table names in static SQL, so
--   P_INPUT_TABLES is a dependency declaration + runtime check, NOT
--   dynamic SQL: the CTAS below still names its sources literally, as
--   in the current main procedure.
--
-- BUSINESS SQL
--   The CTAS below is the current step-40 SELECT verbatim. Only
--   substitution: :l_run_ts -> :P_RUN_TS,
--   :c_mapping -> the local constant below (used by the checkpoint).
--   No business expression, filter, guard or column list was changed.
--   Original parameters used by this step: none; this step uses :P_RUN_TS (substituted from :l_run_ts).
--
-- FRAMEWORK
--   No exception block (errors propagate to the driver handler), no
--   transactions, no target writes. This proc writes its own checkpoint
--   in the v2 10-argument form (TARGET_TABLE NULL, as in the current
--   main's step checkpoints; row count survives in the RETURN value
--   and the driver's helper36 summary line).
--   P_JOB_RUN_ID is present in every new proc in this refactor.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_step_FSS_PHN_S40_ROUTED (
    P_RUN_TS       TIMESTAMP_NTZ
)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    c_mapping    VARCHAR DEFAULT 'm_Tgt_C_S_FSS_Pty_Rle_Phn_And_EAddr';
    l_rows       NUMBER DEFAULT 0;
BEGIN

    -- ---- Step 40: ROUTED (verbatim from current main)
CREATE OR REPLACE TRANSIENT TABLE WRK_FSS_PHN_S4_ROUTED AS
    WITH
    lkp_exc AS (SELECT * FROM TABLE(fn_snow_helper40_common())),
    routed AS (
        SELECT c.*,
               xe.EXCEPTION_CODE  AS email_exception_code,
               xe.EXCEPTION_DESC  AS email_exception_desc,
               xe.EXCEPTION_TYPE  AS email_exception_type,
               xp.EXCEPTION_DESC  AS phone_exception_desc,
               xx.EXCEPTION_DESC  AS ext_exception_desc,
               (c.ADDR_EMAIL IS NOT NULL AND xe.EXCEPTION_CODE IS NULL)          AS grp_email_good,
               (c.ADDR_EMAIL IS NOT NULL AND xe.EXCEPTION_CODE IS NOT NULL)      AS grp_email_bad,
               (c.NBR_PHONE IS NOT NULL AND c.phone_exception_code IS NULL)      AS grp_phone_good,
               (c.NBR_PHONE IS NOT NULL AND c.phone_exception_code IS NOT NULL)  AS grp_phone_bad,
               (c.NBR_PHONE IS NOT NULL AND c.ext_exception_code IS NOT NULL)    AS grp_ext_bad
          FROM WRK_FSS_PHN_S3_CHECKED c
          LEFT JOIN lkp_exc xe ON xe.EXCEPTION_CODE = c.em:exception_code::VARCHAR
          LEFT JOIN lkp_exc xp ON xp.EXCEPTION_CODE = c.phone_exception_code
          LEFT JOIN lkp_exc xx ON xx.EXCEPTION_CODE = c.ext_exception_code
    )
    SELECT r.*,
           '1' /* TIMELINE: VERSION_SEQ */                          AS version_seq,
           1                                                         AS hub_state_ind,
           'FSS'                                                     AS src_sys,
           :P_RUN_TS                                                 AS run_ts,
           :c_mapping                                                AS mapping_name,
           '001'                                                     AS eaddr_addr_tp,
           'Active'                                                  AS eaddr_sts_cd,
           'Y'                                                       AS eaddr_is_vld,
           'Telephone'                                               AS phn_tp,
           '001'                                                     AS usg_tp,
           'Primary'                                                 AS pref_lvl,
           /* BAD DATA: an invalid extension is blanked on the loaded phone */
           IFF(r.ext_exception_code IS NULL, r.std_ext, NULL)        AS phn_num_ext,
           'Email'                                                   AS attr_email,
           'Main Phone'                                              AS attr_phone,
           'Main Phone Ext'                                          AS attr_phone_ext,
           'Rejected Record'                                         AS exc_type_rejected,
           'Bad Value'                                               AS exc_type_bad_value,
           /* BAD DATA: unique keys Snowflake does not enforce */
           (ROW_NUMBER() OVER (PARTITION BY r.grp_email_good, r.eaddr_pkey
                                   ORDER BY r.DT_LAST_UPDATE DESC, r.ID_REGISTRATION_CLIENT) = 1
            AND xea.PKEY_SRC_OBJECT IS NULL)                         AS uq_eaddr,
           (ROW_NUMBER() OVER (PARTITION BY r.grp_phone_good, r.phn_pkey
                                   ORDER BY r.DT_LAST_UPDATE DESC, r.ID_REGISTRATION_CLIENT) = 1
            AND xph.PKEY_SRC_OBJECT IS NULL)                         AS uq_phn,
           ROW_NUMBER() OVER (PARTITION BY r.grp_email_bad, r.PTY_SRC_KEY, r.ID_REGISTRATION_CLIENT,
                                           r.email_exception_type, r.email_exception_code
                                  ORDER BY r.DT_LAST_UPDATE DESC) = 1 AS uq_email_exc,
           ROW_NUMBER() OVER (PARTITION BY r.grp_phone_bad, r.PTY_SRC_KEY, r.ID_REGISTRATION_CLIENT,
                                           r.phone_exception_code ORDER BY r.DT_LAST_UPDATE DESC) = 1 AS uq_phone_exc,
           ROW_NUMBER() OVER (PARTITION BY r.grp_ext_bad, r.PTY_SRC_KEY, r.ID_REGISTRATION_CLIENT,
                                           r.ext_exception_code ORDER BY r.DT_LAST_UPDATE DESC) = 1   AS uq_ext_exc
      FROM routed r
      LEFT JOIN (SELECT DISTINCT PKEY_SRC_OBJECT FROM C_S_FSS_PTY_RLE_EADDR WHERE VERSION_SEQ = 1) xea
             ON xea.PKEY_SRC_OBJECT = r.eaddr_pkey
      LEFT JOIN (SELECT DISTINCT PKEY_SRC_OBJECT FROM C_S_FSS_PTY_RLE_PHN WHERE VERSION_SEQ = 1) xph
             ON xph.PKEY_SRC_OBJECT = r.phn_pkey;
    SELECT COUNT(*) INTO :l_rows FROM WRK_FSS_PHN_S4_ROUTED;
    RETURN :l_rows;
END;
$$;
