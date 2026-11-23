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
-- sp_snow_step_FSS_REL_S40_FINAL  --  BARE-BONES STEP DRIVER (FSS)
--
-- Mapping: m_Tgt_C_S_FSS_Pty_Rle_Rel, workflow wf_FSS_Stage_Load, step 40.
-- Step name (checkpoint): FINAL.
--
-- WHAT THIS STEP PRODUCES
--   WRK_FSS_REL_S4_FINAL: Relationship key, constants, exception details, insert-only guards.
--
-- INPUTS / DEPENDENCY DECLARATION
--   P_INPUT_TABLES lists WORK-TABLE inputs only (default: 'WRK_FSS_REL_S3_TYPED').
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
CREATE OR REPLACE PROCEDURE sp_snow_step_FSS_REL_S40_FINAL (
    P_RUN_TS       TIMESTAMP_NTZ
)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    c_mapping    VARCHAR DEFAULT 'm_Tgt_C_S_FSS_Pty_Rle_Rel';
    l_rows       NUMBER DEFAULT 0;
BEGIN

    -- ---- Step 40: FINAL (verbatim from current main)
CREATE OR REPLACE TRANSIENT TABLE WRK_FSS_REL_S4_FINAL AS
    WITH
    lkp_exc AS (SELECT * FROM TABLE(fn_snow_helper40_common()))
    SELECT t.*,
           t.rel_fk_1 || '|' || t.rel_fk_2 || '|' || NVL(t.mstr_ref_code, '')  AS rel_pkey,
           1 /* TIMELINE: VERSION_SEQ */                                       AS version_seq,
           1                                                                    AS hub_state_ind,
           'Member Relationship'                                                AS rel_type_code,
           'Member'                                                             AS hierarchy_code,
           'batchload'                                                          AS batch_user,
           'FSS'                                                                AS src_sys,
           :P_RUN_TS                                                            AS run_ts,
           :c_mapping                                                           AS mapping_name,
           'Relationship|Sex'                                                   AS attr_relationship,
           ex.EXCEPTION_CODE                                                    AS exc_code,
           ex.EXCEPTION_DESC                                                    AS exc_desc,
           ex.EXCEPTION_TYPE                                                    AS exc_type,
           /* BAD DATA: unique keys Snowflake does not enforce */
           (ROW_NUMBER() OVER (PARTITION BY t.mstr_ref_code IS NULL,
                                        t.rel_fk_1 || '|' || t.rel_fk_2 || '|' || NVL(t.mstr_ref_code, '')
                               ORDER BY t.RELN_DT_LAST_UPDATE DESC, t.ID_REGISTRATION) = 1
            AND xr.PKEY_SRC_OBJECT IS NULL)                                     AS uq_rel,
           ROW_NUMBER() OVER (PARTITION BY t.mstr_ref_code IS NULL, t.RELN_ID_CLIENT, t.ID_CLIENT,
                                       t.ID_REGISTRATION ORDER BY t.RELN_DT_LAST_UPDATE DESC) = 1 AS uq_rel_exc
      FROM WRK_FSS_REL_S3_TYPED t
      LEFT JOIN lkp_exc ex ON ex.EXCEPTION_CODE = 'Invalid_Relationship'
      LEFT JOIN (SELECT DISTINCT PKEY_SRC_OBJECT FROM C_S_FSS_PTY_RLE_REL WHERE VERSION_SEQ = 1) xr
             ON xr.PKEY_SRC_OBJECT = t.rel_fk_1 || '|' || t.rel_fk_2 || '|' || NVL(t.mstr_ref_code, '');
    SELECT COUNT(*) INTO :l_rows FROM WRK_FSS_REL_S4_FINAL;
    RETURN :l_rows;
END;
$$;
