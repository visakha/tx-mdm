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
-- sp_snow_pub_FSS_PHN_C_S_FSS_PTY_RLE_PHN  --  BARE-BONES STEP DRIVER (FSS)
--
-- Mapping: m_Tgt_C_S_FSS_Pty_Rle_Phn_And_EAddr, workflow wf_FSS_Stage_Load.
-- Publish branch STEP_NO 70, checkpoint STEP_NAME PUBLISH_C_S_FSS_PTY_RLE_PHN.
-- Target: C_S_FSS_PTY_RLE_PHN. Kind: SPINE. Valid phones.
-- Branch 3 of the original publish, in original order.
--
-- INPUTS
--   Reads ONLY WRK_FSS_PHN_S4_ROUTED (P_INPUT_TABLES default). The INSERT references neither original parameter nor the run timestamp directly, so P_RUN_TS is carried for a uniform driver call signature and is unused in the body (stated, not hidden).
--
-- BUSINESS SQL
--   The INSERT below is the current branch INSERT verbatim: same
--   columns, values and WHERE guard (grp_phone_good AND uq_phn). No business expression,
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
CREATE OR REPLACE PROCEDURE sp_snow_pub_FSS_PHN_C_S_FSS_PTY_RLE_PHN ()
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
INSERT INTO C_S_FSS_PTY_RLE_PHN
           (PKEY_SRC_OBJECT, PERIOD_START_DATE, VERSION_SEQ, LAST_UPDATE_DATE, SRC_ROWID, HUB_STATE_IND,
            PTY_RLE_FK, PHN_TP, USG_TP, PHN_NUM, PREF_LVL, SRC_LAST_UPD_DT, PHN_NUM_EXT)
    SELECT phn_pkey, DT_LAST_UPDATE, version_seq, run_ts, phn_pkey, hub_state_ind, pty_rle_fk, phn_tp,
           usg_tp, std_phone, pref_lvl, DT_LAST_UPDATE, phn_num_ext
      FROM WRK_FSS_PHN_S4_ROUTED
     WHERE grp_phone_good AND uq_phn;
    RETURN SQLROWCOUNT;
END;
$$;
