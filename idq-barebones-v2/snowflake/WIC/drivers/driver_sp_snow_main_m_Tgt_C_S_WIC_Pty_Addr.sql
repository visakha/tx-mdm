-- ============================================================================
-- sp_snow_main_m_Tgt_C_S_WIC_Pty_Addr  --  BARE-BONES STEP DRIVER VARIANT (WIC)
--
-- IDQ mapping: m_Tgt_C_S_WIC_Pty_Addr, workflow wf_WIC_Stage_Load.
-- Install schema is WIC_ETL_WRK in database MDM_ETL_WIC; all table
-- names below are unqualified.
--
-- WHAT THIS MAPPING DOES, IN PLAIN WORDS
--   Validates the WIC addresses and loads the good ones into the party-role address table. Every active address is written to the address-quality table first. A good address (score 100) loads; an exception address (score 40) is only logged, never loaded.
--
-- BUSINESS FLOW (read this top to bottom -- it IS the business flow)
--     Step  5  CLEANUP_PREVIOUS_RUN  drop any work tables left by the previous run (drops only), then rebuild from step 10
--     Step 10   ACTIVE                   WRK_WIC_ADDR_S10_ACTIVE
--     Step 20   VALIDATED                WRK_WIC_ADDR_S20_VALIDATED
--     Step 30   FLAT                     WRK_WIC_ADDR_S30_FLAT
--     Step 40   SCORED                   WRK_WIC_ADDR_S40_SCORED
--     Step 50   PUBLISH_DQM_ADDRESS      DQM_ADDRESS (VALIDATION)
--     Step 60   PUBLISH_C_S_WIC_PTY_RLE_ADDR C_S_WIC_PTY_RLE_ADDR (SPINE)
--     Step 70   PUBLISH_EXC_STG_BAD_REC_MEMB EXC_STG_BAD_REC_MEMB (EXCEPTION)
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
--   WRK_WIC_ADDR_S10_ACTIVE, WRK_WIC_ADDR_S20_VALIDATED, WRK_WIC_ADDR_S30_FLAT, WRK_WIC_ADDR_S40_SCORED. They live in the same schema as the targets
--   (unqualified names, as in the original code) and are prefixed WRK_WIC_.
--   They survive a session crash (TRANSIENT, not TEMP), which is what
--   makes inspection after a run possible. No CURSOR was used: every step
--   here is set-based by design.
--
-- PARITY NOTES (kept deliberately, do not "fix" silently)
--   * Insert-only: IDQ truncate of C_S_WIC_PTY_RLE_ADDR is not performed.
--   * Address type is the constant 002, so with the pass-through validator every address scores 100; exception addresses are logged only (Invalid Address per Address Doctor, Bad Value).
--   * Unfed ports are written as NULL, including SRC_STATE, even though TX goes to the validator.
--   * DQM_ADDRESS.PTY_SRC_KEY is LPAD(ID, 10, 0); the ECI-only F suffix never applies.
--   * VERSION_SEQ = 1; PERIOD_START_DATE and EFF_STRT_DT = DATE_ADDRESS_VALID_FROM; EFF_END_DT and PERIOD_REFERENCE_TIME are NULL.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_main_m_Tgt_C_S_WIC_Pty_Addr (
    P_MEMBER_HIERARCHY_CODE VARCHAR DEFAULT 'Member',  -- $Member_Hierarchy_Code
    P_MEMBER_HM_REL_TP_CD   VARCHAR DEFAULT 'Member Addr'  -- $Member_HM_REL_TP_CD
)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    c_mapping    VARCHAR DEFAULT 'm_Tgt_C_S_WIC_Pty_Addr';
    l_run_ts     TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()::TIMESTAMP_NTZ;
    l_rows       NUMBER DEFAULT 0;
    l_summary    VARCHAR DEFAULT '';
    -- Per-branch publish counts (one variable per branch)
BEGIN
    -- ---- Step 5: CLEANUP_PREVIOUS_RUN -- drop work tables left by a previous run
    DROP TABLE IF EXISTS WRK_WIC_ADDR_S10_ACTIVE;
    DROP TABLE IF EXISTS WRK_WIC_ADDR_S20_VALIDATED;
    DROP TABLE IF EXISTS WRK_WIC_ADDR_S30_FLAT;
    DROP TABLE IF EXISTS WRK_WIC_ADDR_S40_SCORED;

    -- ---- Step 10: ACTIVE
    l_rows := (CALL sp_snow_step_WIC_ADR_S10_ACTIVE(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 10 ACTIVE', :l_rows) || CHR(10);

    -- ---- Step 20: VALIDATED
    l_rows := (CALL sp_snow_step_WIC_ADR_S20_VALIDATED(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 20 VALIDATED', :l_rows) || CHR(10);

    -- ---- Step 30: FLAT
    l_rows := (CALL sp_snow_step_WIC_ADR_S30_FLAT(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 30 FLAT', :l_rows) || CHR(10);

    -- ---- Step 40: SCORED
    l_rows := (CALL sp_snow_step_WIC_ADR_S40_SCORED(:P_MEMBER_HIERARCHY_CODE, :P_MEMBER_HM_REL_TP_CD, :l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 40 SCORED', :l_rows) || CHR(10);

    -- ---- PUBLISH: ONE transaction, all branches, in order ----
    BEGIN TRANSACTION;
    l_rows := (CALL sp_snow_pub_WIC_ADR_DQM_ADDRESS());
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 50 PUBLISH_DQM_ADDRESS', :l_rows) || CHR(10);
    l_rows := (CALL sp_snow_pub_WIC_ADR_C_S_WIC_PTY_RLE_ADDR());
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 60 PUBLISH_C_S_WIC_PTY_RLE_ADDR', :l_rows) || CHR(10);
    l_rows := (CALL sp_snow_pub_WIC_ADR_EXC_STG_BAD_REC_MEMB());
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 70 PUBLISH_EXC_STG_BAD_REC_MEMB', :l_rows) || CHR(10);
    COMMIT;


    RETURN l_summary;
EXCEPTION
    WHEN OTHER THEN
        ROLLBACK;
        RAISE;
END;
$$;
