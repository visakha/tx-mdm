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
-- sp_snow_step_FSS_ADR_S40_SCORED  --  BARE-BONES STEP DRIVER (FSS)
--
-- Mapping: m_Tgt_C_S_FSS_Pty_Addr, workflow wf_FSS_Stage_Load, step 40.
-- Step name (checkpoint): SCORED.
--
-- WHAT THIS STEP PRODUCES
--   WRK_FSS_ADDR_S4_SCORED: Good / exception score, held address lines, exception details, insert-only guards.
--
-- INPUTS / DEPENDENCY DECLARATION
--   P_INPUT_TABLES lists WORK-TABLE inputs only (default: 'WRK_FSS_ADDR_S3_FLAT').
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
--   Original parameters used by this step: P_MEMBER_HIERARCHY_CODE, P_MEMBER_HM_REL_TP_CD.
--
-- FRAMEWORK
--   No exception block (errors propagate to the driver handler), no
--   transactions, no target writes. This proc writes its own checkpoint
--   in the v2 10-argument form (TARGET_TABLE NULL, as in the current
--   main's step checkpoints; row count survives in the RETURN value
--   and the driver's helper36 summary line).
--   P_JOB_RUN_ID is present in every new proc in this refactor.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_step_FSS_ADR_S40_SCORED (
    P_MEMBER_HIERARCHY_CODE VARCHAR DEFAULT 'Member',
    P_MEMBER_HM_REL_TP_CD VARCHAR DEFAULT 'Member Addr',
    P_RUN_TS       TIMESTAMP_NTZ DEFAULT NULL
)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    c_mapping    VARCHAR DEFAULT 'm_Tgt_C_S_FSS_Pty_Addr';
    l_rows       NUMBER DEFAULT 0;
BEGIN

    -- ---- Step 40: SCORED (verbatim from current main)
CREATE OR REPLACE TRANSIENT TABLE WRK_FSS_ADDR_S4_SCORED AS
    WITH
    scored AS (
        SELECT f.*,
               /* VALIDATION */ fn_snow_helper05_common('002', f.a_mailability_score, f.a_match_code) AS score,
               fn_snow_helper06_common('002', f.a_mailability_score, f.a_match_code)   AS addr_issue_desc,
               fn_snow_helper07_common(f.a_line1, f.a_line2)                          AS hold_line1,
               fn_snow_helper08_common(f.a_line1, f.a_line2)                          AS hold_line2
          FROM WRK_FSS_ADDR_S3_FLAT f
    )
    SELECT s.*,
           '002'                                                         AS addr_tp,
           'US'                                                          AS src_cntry,
           'FSS'                                                         AS src_sys,
           :P_RUN_TS                                                     AS run_ts,
           :c_mapping                                                    AS mapping_name,
           1 /* TIMELINE: VERSION_SEQ */                                 AS version_seq,
           1                                                             AS hub_state_ind,
           NVL(s.PTY_SRC_KEY, '') || '|Member'                           AS pty_rle_fk,
           'Primary'                                                     AS pref_lvl,
           NVL(TO_VARCHAR(s.ID_CLIENT), '') || '|' || NVL(TO_VARCHAR(s.ID_REGISTRATION_CLIENT), '') AS loc_idn,
           :P_MEMBER_HIERARCHY_CODE                                      AS hierarchy_code,
           :P_MEMBER_HM_REL_TP_CD                                        AS hm_rel_tp_cd,
           IFF(s.addr_issue_desc IS NOT NULL, 'Address', NULL)           AS exc_attribute_name,
           IFF(s.addr_issue_desc IS NOT NULL,
               NVL(s.ADDR_LINE1, '') || ' ' || NVL(s.ADDR_LINE2, '') || ' ' || NVL(s.ADDR_CITY, '') || ' '
               || NVL(s.ADDR_STATE, '') || ' ' || NVL(s.ADDR_ZIP, '') || '  US', NULL) AS exc_attribute_value,
           'Invalid_Address'                                             AS exc_code,
           'Invalid Address per Address Doctor'                          AS exc_desc,
           'Bad Value'                                                   AS exc_type,
           /* BAD DATA: unique keys Snowflake does not enforce */
           (ROW_NUMBER() OVER (PARTITION BY s.score, s.pkey_src_object
                                   ORDER BY s.DT_LAST_UPDATE DESC, s.ID_REGISTRATION_CLIENT) = 1
            AND xa.PKEY_SRC_OBJECT IS NULL)                              AS uq_addr,
           ROW_NUMBER() OVER (PARTITION BY s.score, s.ID_CLIENT, s.ID_REGISTRATION_CLIENT, s.SOURCE_TYPE
                                  ORDER BY s.DT_LAST_UPDATE DESC) = 1    AS uq_addr_exc
      FROM scored s
      LEFT JOIN (SELECT DISTINCT PKEY_SRC_OBJECT FROM C_S_FSS_PTY_RLE_ADDR WHERE VERSION_SEQ = 1) xa
             ON xa.PKEY_SRC_OBJECT = s.pkey_src_object;
    SELECT COUNT(*) INTO :l_rows FROM WRK_FSS_ADDR_S4_SCORED;
    RETURN :l_rows;
END;
$$;
