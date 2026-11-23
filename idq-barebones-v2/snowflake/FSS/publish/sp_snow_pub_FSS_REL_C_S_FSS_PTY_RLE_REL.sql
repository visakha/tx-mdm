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
-- sp_snow_pub_FSS_REL_C_S_FSS_PTY_RLE_REL  --  BARE-BONES STEP DRIVER (FSS)
--
-- Mapping: m_Tgt_C_S_FSS_Pty_Rle_Rel, workflow wf_FSS_Stage_Load.
-- Publish branch STEP_NO 50, checkpoint STEP_NAME PUBLISH_C_S_FSS_PTY_RLE_REL.
-- Target: C_S_FSS_PTY_RLE_REL. Kind: SPINE. Valid relationships.
-- Branch 1 of the original publish, in original order.
--
-- INPUTS
--   Reads ONLY WRK_FSS_REL_S4_FINAL (P_INPUT_TABLES default). The INSERT references neither original parameter nor the run timestamp directly, so P_RUN_TS is carried for a uniform driver call signature and is unused in the body (stated, not hidden).
--
-- BUSINESS SQL
--   The INSERT below is the current branch INSERT verbatim: same
--   columns, values and WHERE guard (mstr_ref_code IS NOT NULL AND uq_rel). No business expression,
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
CREATE OR REPLACE PROCEDURE sp_snow_pub_FSS_REL_C_S_FSS_PTY_RLE_REL ()
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
INSERT INTO C_S_FSS_PTY_RLE_REL
           (REL_TP, VERSION_SEQ, HUB_STATE_IND, REL_TYPE_CODE, HIERARCHY_CODE, UPDATED_BY, LAST_UPDATE_DATE,
            PERIOD_START_DATE, PKEY_SRC_OBJECT, PTY_RLE_FK_1, PTY_RLE_FK_2, SRC_LAST_UPD_DT, CREATOR, SRC_ROWID,
            CREATE_DATE)
    SELECT mstr_ref_code, version_seq, hub_state_ind, rel_type_code, hierarchy_code, batch_user, run_ts,
           RELN_DT_CREATED, rel_pkey, rel_fk_1, rel_fk_2, RELN_DT_LAST_UPDATE, batch_user, rel_pkey,
           RELN_DT_LAST_UPDATE
      FROM WRK_FSS_REL_S4_FINAL
     WHERE mstr_ref_code IS NOT NULL AND uq_rel;
    RETURN SQLROWCOUNT;
END;
$$;
