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
-- sp_snow_pub_FSS_PHN_EXC_STG_BAD_REC_MEMB_PHONE  --  BARE-BONES STEP DRIVER (FSS)
--
-- Mapping: m_Tgt_C_S_FSS_Pty_Rle_Phn_And_EAddr, workflow wf_FSS_Stage_Load.
-- Publish branch STEP_NO 80, checkpoint STEP_NAME PUBLISH_EXC_PHONE.
-- Target: EXC_STG_BAD_REC_MEMB. Kind: EXCEPTION. Bad phones.
-- Branch 4 of the original publish, in original order.
--
-- INPUTS
--   Reads ONLY WRK_FSS_PHN_S4_ROUTED (P_INPUT_TABLES default). The INSERT references neither original parameter nor the run timestamp directly, so P_RUN_TS is carried for a uniform driver call signature and is unused in the body (stated, not hidden).
--
-- BUSINESS SQL
--   The INSERT below is the current branch INSERT verbatim: same
--   columns, values and WHERE guard (grp_phone_bad AND uq_phone_exc). No business expression,
--   filter, guard or column list was changed.
--
-- FRAMEWORK RULE
--   NO transaction control and NO checkpoint calls in this proc. The
--   driver calls it inside ONE publish transaction (all branches
--   together, so a publish either lands completely or not at all),
--   COMMITs, and only then checkpoints this branch with the returned
--   row count. Never call a checkpoint between BEGIN TRANSACTION and
--   COMMIT.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_pub_FSS_PHN_EXC_STG_BAD_REC_MEMB_PHONE ()
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
INSERT INTO EXC_STG_BAD_REC_MEMB
           (SRC_SYS, EXCEPTION_CODE, EXCEPTION_DESC, RUN_DATE, PRIMARY_PHONE, WORK_PHONE, SECONDARY_PHONE,
            MAPPING_NAME, SRC_SYS_ID_1, EXCEPTION_TYPE, PERIOD_START_DATE, ATTRIBUTE_VALUE, ATTRIBUTE_NAME,
            SRC_SYS_ID_2)
    SELECT src_sys, phone_exception_code, phone_exception_desc, run_ts, NBR_PHONE, NULL, NULL,
           mapping_name, PTY_SRC_KEY, exc_type_rejected, DT_LAST_UPDATE, NBR_PHONE, attr_phone,
           ID_REGISTRATION_CLIENT
      FROM WRK_FSS_PHN_S4_ROUTED
     WHERE grp_phone_bad AND uq_phone_exc;
    RETURN SQLROWCOUNT;
END;
$$;
