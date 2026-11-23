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
-- sp_snow_pub_FSS_PTY_C_S_FSS_PTY  --  BARE-BONES STEP DRIVER (FSS)
--
-- Mapping: m_Tgt_C_S_FSS_Pty, workflow wf_FSS_Stage_Load.
-- Publish branch STEP_NO 50, checkpoint STEP_NAME PUBLISH_C_S_FSS_PTY.
-- Target: C_S_FSS_PTY. Kind: SPINE. Valid parties.
-- Branch 1 of the original publish, in original order.
--
-- INPUTS
--   Reads ONLY WRK_FSS_PTY_S4_ROUTED (P_INPUT_TABLES default). The INSERT references neither original parameter nor the run timestamp directly, so P_RUN_TS is carried for a uniform driver call signature and is unused in the body (stated, not hidden).
--
-- BUSINESS SQL
--   The INSERT below is the current branch INSERT verbatim: same
--   columns, values and WHERE guard (uq_pty). No business expression,
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
CREATE OR REPLACE PROCEDURE sp_snow_pub_FSS_PTY_C_S_FSS_PTY ()
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
INSERT INTO C_S_FSS_PTY
           (PKEY_SRC_OBJECT, PERIOD_START_DATE, VERSION_SEQ, LAST_UPDATE_DATE, CREATE_DATE, SRC_ROWID,
            HUB_STATE_IND, PTY_BO_CLASS_CD, PRFX_NM, FRST_NM, MDL_NM, LST_NM, FULL_NM, GNDR_CD, BIRTH_DT,
            SRC_FULL_NM, ETHNCTY, SRC_ETHNCTY, RACE_CD, SRC_RACE_CD, SRC_LAST_UPD_DT, PRFRD_LANG_CD, SFX_NM)
    SELECT pkey_trim, DT_LAST_UPDATE, version_seq, run_ts, DT_LAST_UPDATE, pkey_trim, hub_state_ind,
           pty_bo_class_cd, std_prfx_name, std_first_name, std_mdl_name, std_lst_name, std_full_name,
           mdm_gender_code, DT_DOB, std_src_full_name, ethnicity_mstr, CD_HISPANIC, mdm_race_cd,
           src_race_ind_list, DT_LAST_UPDATE, language_mstr, std_suffix
      FROM WRK_FSS_PTY_S4_ROUTED
     WHERE uq_pty;
    RETURN SQLROWCOUNT;
END;
$$;
