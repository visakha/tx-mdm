-- ============================================================================
-- sp_snow_main_m_Tgt_C_S_WIC_Pty  --  BARE-BONES STEP DRIVER VARIANT (WIC)
--
-- IDQ mapping: m_Tgt_C_S_WIC_Pty, workflow wf_WIC_Stage_Load.
-- Install schema is WIC_ETL_WRK in database MDM_ETL_WIC; all table
-- names below are unqualified.
--
-- WHAT THIS MAPPING DOES, IN PLAIN WORDS
--   Loads the active WIC parties into the party and party-role tables and logs demographic exceptions. Every active party loads: an exception never rejects the party, it is loaded AND logged. Gender, ethnicity and race exceptions are logged only for SOURCE_TABLE = CLIENT; birth date and language exceptions are logged for every row.
--
-- BUSINESS FLOW (read this top to bottom -- it IS the business flow)
--     Step  5  CLEANUP_PREVIOUS_RUN  drop any work tables left by the previous run (drops only), then rebuild from step 10
--     Step 10   ACTIVE                   WRK_WIC_PTY_S10_ACTIVE
--     Step 20   DQ_STANDARDISE_VALIDATE  WRK_WIC_PTY_S20_DQ
--     Step 30   DQ2_EXCEPTION_DETAIL     WRK_WIC_PTY_S30_DQ2
--     Step 40   ROUTED                   WRK_WIC_PTY_S40_ROUTED
--     Step 50   PUBLISH_C_S_WIC_PTY      C_S_WIC_PTY (SPINE)
--     Step 60   PUBLISH_C_S_WIC_PTY_RLE  C_S_WIC_PTY_RLE (SPINE)
--     Step 70   PUBLISH_EXC_GENDER       EXC_STG_BAD_REC_MEMB (EXCEPTION)
--     Step 80   PUBLISH_EXC_BIRTH        EXC_STG_BAD_REC_MEMB (EXCEPTION)
--     Step 90   PUBLISH_EXC_ETHNICITY    EXC_STG_BAD_REC_MEMB (EXCEPTION)
--     Step 100  PUBLISH_EXC_RACE         EXC_STG_BAD_REC_MEMB (EXCEPTION)
--     Step 110  PUBLISH_EXC_LANGUAGE     EXC_STG_BAD_REC_MEMB (EXCEPTION)
--     End    work tables are NOT dropped: they stay in the database until the next run of this mapping cleans them up
--
-- BARE-BONES VARIANT
--   No config gating, no job tracking, no input checks, no seed data.
--   Every step and every publish branch runs, unconditionally, in order.
--   Steps run autocommitted; publish runs as ONE transaction covering all
--   branches. The driver RETURNs the combined summary string l_summary.
--   A restart is simply a new run: the mapping cleans up the previous
--   run's work tables at its start (step 5) and runs every step fresh.
--   Procedure-call return capture uses `l_rows := (CALL proc(...));`
--   (Snowflake Scripting scalar-call form).
--
-- WORK TABLES (all TRANSIENT)
--   WRK_WIC_PTY_S10_ACTIVE, WRK_WIC_PTY_S20_DQ, WRK_WIC_PTY_S30_DQ2, WRK_WIC_PTY_S40_ROUTED. They live in the same schema as the targets
--   (unqualified names, as in the original code) and are prefixed WRK_WIC_.
--   They survive a session crash (TRANSIENT, not TEMP), which is what
--   makes inspection after a run possible. No CURSOR was used: every step
--   here is set-based by design.
--
-- PARITY NOTES (kept deliberately, do not "fix" silently)
--   * Insert-only: IDQ truncates of C_S_WIC_PTY and C_S_WIC_PTY_RLE are not performed; keys already present are skipped by the uq_pty and uq_rle guards.
--   * Party birth date is the source DOB, while the language exception row writes the mapplet birth date (NULL for a future one).
--   * Birth weight in grams is BIRTH_WT_OZ * 28.35 (ounces only).
--   * VERSION_SEQ hard-coded to 1; PERIOD_START_DATE = DATEKEY; HUB_STATE_IND hard-coded to 1.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_main_m_Tgt_C_S_WIC_Pty (
    P_PTY_BO_CLASS_CD_MEMBER VARCHAR DEFAULT 'Indv',  -- $PTY_BO_CLASS_CD_Member
    P_RLE_BO_CLASS_CD_MEMBER VARCHAR DEFAULT 'Member'  -- $RLE_BO_CLASS_CD_Member
)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    c_mapping    VARCHAR DEFAULT 'm_Tgt_C_S_WIC_Pty';
    l_run_ts     TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()::TIMESTAMP_NTZ;
    l_rows       NUMBER DEFAULT 0;
    l_summary    VARCHAR DEFAULT '';
    -- Per-branch publish counts (one variable per branch)
BEGIN
    -- ---- Step 5: CLEANUP_PREVIOUS_RUN -- drop work tables left by a previous run
    DROP TABLE IF EXISTS WRK_WIC_PTY_S10_ACTIVE;
    DROP TABLE IF EXISTS WRK_WIC_PTY_S20_DQ;
    DROP TABLE IF EXISTS WRK_WIC_PTY_S30_DQ2;
    DROP TABLE IF EXISTS WRK_WIC_PTY_S40_ROUTED;

    -- ---- Step 10: ACTIVE
    l_rows := (CALL sp_snow_step_WIC_PTY_S10_ACTIVE(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 10 ACTIVE', :l_rows) || CHR(10);

    -- ---- Step 20: DQ_STANDARDISE_VALIDATE
    l_rows := (CALL sp_snow_step_WIC_PTY_S20_DQ(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 20 DQ_STANDARDISE_VALIDATE', :l_rows) || CHR(10);

    -- ---- Step 30: DQ2_EXCEPTION_DETAIL
    l_rows := (CALL sp_snow_step_WIC_PTY_S30_DQ2(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 30 DQ2_EXCEPTION_DETAIL', :l_rows) || CHR(10);

    -- ---- Step 40: ROUTED
    l_rows := (CALL sp_snow_step_WIC_PTY_S40_ROUTED(:P_PTY_BO_CLASS_CD_MEMBER, :P_RLE_BO_CLASS_CD_MEMBER, :l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 40 ROUTED', :l_rows) || CHR(10);

    -- ---- PUBLISH: ONE transaction, all branches, in order ----
    BEGIN TRANSACTION;
    l_rows := (CALL sp_snow_pub_WIC_PTY_C_S_WIC_PTY());
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 50 PUBLISH_C_S_WIC_PTY', :l_rows) || CHR(10);
    l_rows := (CALL sp_snow_pub_WIC_PTY_C_S_WIC_PTY_RLE());
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 60 PUBLISH_C_S_WIC_PTY_RLE', :l_rows) || CHR(10);
    l_rows := (CALL sp_snow_pub_WIC_PTY_EXC_STG_BAD_REC_MEMB_GENDER());
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 70 PUBLISH_EXC_GENDER', :l_rows) || CHR(10);
    l_rows := (CALL sp_snow_pub_WIC_PTY_EXC_STG_BAD_REC_MEMB_BIRTH());
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 80 PUBLISH_EXC_BIRTH', :l_rows) || CHR(10);
    l_rows := (CALL sp_snow_pub_WIC_PTY_EXC_STG_BAD_REC_MEMB_ETHNICITY());
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 90 PUBLISH_EXC_ETHNICITY', :l_rows) || CHR(10);
    l_rows := (CALL sp_snow_pub_WIC_PTY_EXC_STG_BAD_REC_MEMB_RACE());
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 100 PUBLISH_EXC_RACE', :l_rows) || CHR(10);
    l_rows := (CALL sp_snow_pub_WIC_PTY_EXC_STG_BAD_REC_MEMB_LANGUAGE());
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 110 PUBLISH_EXC_LANGUAGE', :l_rows) || CHR(10);
    COMMIT;


    RETURN l_summary;
EXCEPTION
    WHEN OTHER THEN
        ROLLBACK;
        RAISE;
END;
$$;
