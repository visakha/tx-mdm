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
-- sp_snow_step_FSS_ALT_S10_SRC  --  BARE-BONES STEP DRIVER (FSS)
--
-- Mapping: m_Tgt_C_S_FSS_Pty_Rle_Alt_Id, workflow wf_FSS_Stage_Load, step 10.
-- Step name (checkpoint): SRC_KEYED.
--
-- WHAT THIS STEP PRODUCES
--   WRK_FSS_ALT_S1_SRC: Keyed source rows: role key, alternate-ID type (022 / 023) and key, last active registrations.
--
-- INPUTS / DEPENDENCY DECLARATION
--   P_INPUT_TABLES lists WORK-TABLE inputs only (default: '').
--   Snowflake cannot parameterise table names in static SQL, so
--   P_INPUT_TABLES is a dependency declaration + runtime check, NOT
--   dynamic SQL: the CTAS below still names its sources literally, as
--   in the current main procedure.
--
-- BUSINESS SQL
--   The CTAS below is the current step-10 SELECT verbatim. Only
--   substitution: :l_run_ts -> :P_RUN_TS (not used by this step),
--   :c_mapping -> the local constant below (used by the checkpoint).
--   No business expression, filter, guard or column list was changed.
--   Original parameters used by this step: none.
--
-- FRAMEWORK
--   No exception block (errors propagate to the driver handler), no
--   transactions, no target writes. This proc writes its own checkpoint
--   in the v2 10-argument form (TARGET_TABLE NULL, as in the current
--   main's step checkpoints; row count survives in the RETURN value
--   and the driver's helper36 summary line).
--   P_JOB_RUN_ID is present in every new proc in this refactor.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_step_FSS_ALT_S10_SRC (
    P_RUN_TS       TIMESTAMP_NTZ
)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    l_rows       NUMBER DEFAULT 0;
BEGIN

    -- ---- Step 10: SRC_KEYED (verbatim from current main)
CREATE OR REPLACE TRANSIENT TABLE WRK_FSS_ALT_S1_SRC AS
    SELECT v.SOURCE_TYPE, v.DT_CREATED, v.DT_LAST_UPDATE, v.PTY_SRC_KEY, v.ID_CLIENT,
           NVL(v.PTY_SRC_KEY, '') || '|Member'                                      AS pty_rle_fk,
           IFF(v.SOURCE_TYPE = 'CLIENT', '022', '023')                              AS alt_id_tp,
           NVL(v.PTY_SRC_KEY, '') || '|Member|' || IFF(v.SOURCE_TYPE = 'CLIENT', '022', '023') || '|'
           || NVL(LPAD(TO_VARCHAR(v.ID_CLIENT), 10, '0'), '')                        AS pkey_src_object
      FROM V_FSS_ETL_SRC v
     -- source filter (the commented-out testing filter is not applied)
     WHERE v.LAST_ACTIVE_CLIENT_REGISTRATION_YN = 'Y';
    SELECT COUNT(*) INTO :l_rows FROM WRK_FSS_ALT_S1_SRC;
    RETURN :l_rows;
END;
$$;
