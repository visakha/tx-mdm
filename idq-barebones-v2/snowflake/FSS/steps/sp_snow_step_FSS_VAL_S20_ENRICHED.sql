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
-- sp_snow_step_FSS_VAL_S20_ENRICHED  --  BARE-BONES STEP DRIVER (FSS)
--
-- Mapping: m_Tgt_C_S_FSS_Pty_Validation, workflow wf_FSS_Stage_Load, step 20.
-- Step name (checkpoint): ENRICHED.
--
-- WHAT THIS STEP PRODUCES
--   WRK_FSS_VAL_S2_ENRICHED: Standardised names + blank-name flag, current deactivation status, cross-reference state.
--
-- INPUTS / DEPENDENCY DECLARATION
--   P_INPUT_TABLES lists WORK-TABLE inputs only (default: 'WRK_FSS_VAL_S1_SRC').
--   Snowflake cannot parameterise table names in static SQL, so
--   P_INPUT_TABLES is a dependency declaration + runtime check, NOT
--   dynamic SQL: the CTAS below still names its sources literally, as
--   in the current main procedure.
--
-- BUSINESS SQL
--   The CTAS below is the current step-20 SELECT verbatim. Only
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
CREATE OR REPLACE PROCEDURE sp_snow_step_FSS_VAL_S20_ENRICHED (
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

    -- ---- Step 20: ENRICHED (verbatim from current main)
CREATE OR REPLACE TRANSIENT TABLE WRK_FSS_VAL_S2_ENRICHED AS
    WITH
    lkp_junk AS (SELECT * FROM TABLE(fn_snow_helper43_common())),
    sts AS (    -- Lookup_STG_FSS_PTY_INACTIVE_STS (any row)
        SELECT i.SRC_KEY, i.DEACTIVATION_STS
          FROM STG_FSS_PTY_INACTIVE_STS i
         WHERE i.ROWID_SYSTEM = 'FSS'
       QUALIFY ROW_NUMBER() OVER (PARTITION BY i.SRC_KEY ORDER BY i.DEACTIVATION_DT DESC NULLS LAST) = 1
    ),
    xref AS (   -- Lookup_C_B_PTY_XREF (lookup filter ROWID_SYSTEM = 'FSS'; blank-padded MDM column trimmed)
        SELECT x.PKEY_SRC_OBJECT, x.HUB_STATE_IND
          FROM C_B_PTY_XREF x
         WHERE TRIM(x.ROWID_SYSTEM) = 'FSS'
       QUALIFY ROW_NUMBER() OVER (PARTITION BY x.PKEY_SRC_OBJECT ORDER BY x.HUB_STATE_IND DESC NULLS LAST) = 1
    ),
    enriched AS (
        SELECT s.*,
               sts.DEACTIVATION_STS AS deactivation_sts,
               xref.HUB_STATE_IND   AS hub_state_ind,
               fn_snow_helper15_common(s.NM_FIRST, s.NM_MIDDLE, s.NM_LAST,
                   TRIM(NVL(s.NM_FIRST, '') || IFF(s.NM_MIDDLE IS NOT NULL, ' ' || TRIM(s.NM_MIDDLE), '')
                        || ' ' || NVL(LTRIM(s.NM_LAST), '')),
                   NULL, NULL, NULL, NULL, jf.NAME IS NOT NULL, jl.NAME IS NOT NULL) AS nm
          FROM WRK_FSS_VAL_S1_SRC s
          LEFT JOIN sts  ON sts.SRC_KEY = s.PTY_SRC_KEY
          LEFT JOIN xref ON xref.PKEY_SRC_OBJECT = s.PTY_SRC_KEY
          LEFT JOIN lkp_junk jf ON jf.NAME = UPPER(TRIM(s.NM_FIRST)) AND jf.IS_FIRST_JUNK
          LEFT JOIN lkp_junk jl ON jl.NAME = UPPER(TRIM(s.NM_LAST)) AND jl.IS_LAST_JUNK
    )
    SELECT n.*,
           n.nm:first_name::VARCHAR    AS std_first_name,
           n.nm:middle_name::VARCHAR   AS std_mdl_name,
           n.nm:last_name::VARCHAR     AS std_lst_name,
           n.nm:src_full_name::VARCHAR AS std_src_full_name,
           /* VALIDATION */ (fn_snow_helper03_common(n.nm:first_name::VARCHAR)
                             OR fn_snow_helper03_common(n.nm:last_name::VARCHAR)) AS name_missing
      FROM enriched n;
    SELECT COUNT(*) INTO :l_rows FROM WRK_FSS_VAL_S2_ENRICHED;
    RETURN :l_rows;
END;
$$;
