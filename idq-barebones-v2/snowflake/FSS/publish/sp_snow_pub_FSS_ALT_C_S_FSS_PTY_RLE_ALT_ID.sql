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
-- sp_snow_pub_FSS_ALT_C_S_FSS_PTY_RLE_ALT_ID  --  BARE-BONES STEP DRIVER (FSS)
--
-- Mapping: m_Tgt_C_S_FSS_Pty_Rle_Alt_Id, workflow wf_FSS_Stage_Load.
-- Publish branch STEP_NO 50, checkpoint STEP_NAME PUBLISH_C_S_FSS_PTY_RLE_ALT_ID.
-- Target: C_S_FSS_PTY_RLE_ALT_ID. Kind: SPINE. Valid alternate IDs.
-- Branch 1 of the original publish, in original order.
--
-- INPUTS
--   Reads ONLY WRK_FSS_ALT_S2_FILTERED (P_INPUT_TABLES default). The INSERT references the run timestamp directly, so P_RUN_TS is used in the body (substituted from :l_run_ts).
--
-- BUSINESS SQL
--   The INSERT below is the current branch INSERT verbatim: same
--   columns, values and WHERE guard (no WHERE guard (filtered rows only)). No business expression,
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
CREATE OR REPLACE PROCEDURE sp_snow_pub_FSS_ALT_C_S_FSS_PTY_RLE_ALT_ID (
    P_RUN_TS TIMESTAMP_NTZ
)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
INSERT INTO C_S_FSS_PTY_RLE_ALT_ID
           (PKEY_SRC_OBJECT, PTY_RLE_FK, ALT_ID_TP, ALT_ID_VAL, SRC_LAST_UPD_DT, HUB_STATE_IND, STS_CD, SRC_ROWID,
            LAST_UPDATE_DATE, VERSION_SEQ, ALT_ID_TP_FLTR, CREATE_DATE, PERIOD_START_DATE)
    SELECT x.pkey_src_object, x.pty_rle_fk, x.alt_id_tp, LPAD(TO_VARCHAR(x.ID_CLIENT), 10, '0'), :P_RUN_TS, 1,
           'Issued', NVL(TO_VARCHAR(x.ID_CLIENT), '') || '|' || x.alt_id_tp, :P_RUN_TS,
           1 /* TIMELINE: VERSION_SEQ */, x.alt_id_tp, x.DT_CREATED, x.DT_CREATED /* TIMELINE */
      FROM WRK_FSS_ALT_S2_FILTERED x;
    RETURN SQLROWCOUNT;
END;
$$;
