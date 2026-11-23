-- sp_snow_main_m_Tgt_C_S_ECI_Pty_Validation -- BARE-BONES variant (ECI)
-- Mapping: m_Tgt_C_S_ECI_Pty_Validation, workflow wf_ECI_Stage_Load.
-- Unconditional steps in order; step 5 drops prior work tables at the start;
-- work tables are left standing at the end. Publish runs in one transaction.
-- The driver returns one summary string built with fn_snow_helper36_common.
-- No gating, no checkpointing, no run-id tracking.
CREATE OR REPLACE PROCEDURE sp_snow_main_m_Tgt_C_S_ECI_Pty_Validation ()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    c_mapping    VARCHAR DEFAULT 'm_Tgt_C_S_ECI_Pty_Validation';
    l_run_ts     TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()::TIMESTAMP_NTZ;
    l_rows       NUMBER DEFAULT 0;
    l_summary    VARCHAR DEFAULT '';
BEGIN
    -- ---- Step 5: CLEANUP_PREVIOUS_RUN
    DROP TABLE IF EXISTS WRK_ECI_VAL_S10_SRC;
    DROP TABLE IF EXISTS WRK_ECI_VAL_S20_ENRICHED;
    DROP TABLE IF EXISTS WRK_ECI_VAL_S30_ROUTED;

    -- ---- step 10 SRC_DELTA_PARTIES
    l_rows := (CALL sp_snow_step_ECI_VAL_S10_SRC(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 10 SRC_DELTA_PARTIES', :l_rows) || CHR(10);

    -- ---- step 20 ENRICHED_STD_NAMES
    l_rows := (CALL sp_snow_step_ECI_VAL_S20_ENRICHED(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 20 ENRICHED_STD_NAMES', :l_rows) || CHR(10);

    -- ---- step 30 ROUTED_GROUPS
    l_rows := (CALL sp_snow_step_ECI_VAL_S30_ROUTED(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 30 ROUTED_GROUPS', :l_rows) || CHR(10);

    -- ---- Publish: one transaction, all branches in order
    BEGIN TRANSACTION;
    -- ---- step 40 PUBLISH_EXC_STG_BAD_REC_MEMB -> EXC_STG_BAD_REC_MEMB
    l_rows := (CALL sp_snow_pub_ECI_VAL_EXC_STG_BAD_REC_MEMB());
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 40 PUBLISH_EXC_STG_BAD_REC_MEMB', :l_rows) || CHR(10);
    -- ---- step 50 PUBLISH_STG_ECI_PTY_INACTIVE_LOG_DEACTIVATION -> STG_ECI_PTY_INACTIVE_LOG
    l_rows := (CALL sp_snow_pub_ECI_VAL_STG_ECI_PTY_INACTIVE_LOG_DEACTIVATION());
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 50 PUBLISH_STG_ECI_PTY_INACTIVE_LOG_DEACTIVATION', :l_rows) || CHR(10);
    -- ---- step 60 PUBLISH_STG_ECI_PTY_INACTIVE_STS -> STG_ECI_PTY_INACTIVE_STS
    l_rows := (CALL sp_snow_pub_ECI_VAL_STG_ECI_PTY_INACTIVE_STS());
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 60 PUBLISH_STG_ECI_PTY_INACTIVE_STS', :l_rows) || CHR(10);
    -- ---- step 70 PUBLISH_STG_ECI_PTY_INACTIVE_LOG_REACTIVATION -> STG_ECI_PTY_INACTIVE_LOG
    l_rows := (CALL sp_snow_pub_ECI_VAL_STG_ECI_PTY_INACTIVE_LOG_REACTIVATION());
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 70 PUBLISH_STG_ECI_PTY_INACTIVE_LOG_REACTIVATION', :l_rows) || CHR(10);
    COMMIT;

    RETURN l_summary;
EXCEPTION
    WHEN OTHER THEN
        ROLLBACK;
        RAISE;
END;
$$;
