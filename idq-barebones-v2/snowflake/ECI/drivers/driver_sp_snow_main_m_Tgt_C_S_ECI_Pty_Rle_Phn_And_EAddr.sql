-- sp_snow_main_m_Tgt_C_S_ECI_Pty_Rle_Phn_And_EAddr -- BARE-BONES variant (ECI)
-- Mapping: m_Tgt_C_S_ECI_Pty_Rle_Phn_And_EAddr, workflow wf_ECI_Stage_Load.
-- Unconditional steps in order; step 5 drops prior work tables at the start;
-- work tables are left standing at the end. Publish runs in one transaction.
-- The driver returns one summary string built with fn_snow_helper36_common.
-- No gating, no checkpointing, no run-id tracking.
CREATE OR REPLACE PROCEDURE sp_snow_main_m_Tgt_C_S_ECI_Pty_Rle_Phn_And_EAddr ()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    c_mapping    VARCHAR DEFAULT 'm_Tgt_C_S_ECI_Pty_Rle_Phn_And_EAddr';
    l_run_ts     TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()::TIMESTAMP_NTZ;
    l_rows       NUMBER DEFAULT 0;
    l_summary    VARCHAR DEFAULT '';
BEGIN
    -- ---- Step 5: CLEANUP_PREVIOUS_RUN
    DROP TABLE IF EXISTS WRK_ECI_PHN_S10_SRC;
    DROP TABLE IF EXISTS WRK_ECI_PHN_S20_ACTIVE;
    DROP TABLE IF EXISTS WRK_ECI_PHN_S30_DQ;
    DROP TABLE IF EXISTS WRK_ECI_PHN_S40_ROUTED;
    DROP TABLE IF EXISTS WRK_ECI_PHN_S50_READY;

    -- ---- step 10 SRC_PHN_EADDR
    l_rows := (CALL sp_snow_step_ECI_PHN_S10_SRC(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 10 SRC_PHN_EADDR', :l_rows) || CHR(10);

    -- ---- step 20 ACTIVE_PHN_EADDR
    l_rows := (CALL sp_snow_step_ECI_PHN_S20_ACTIVE(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 20 ACTIVE_PHN_EADDR', :l_rows) || CHR(10);

    -- ---- step 30 DQ_CLEAN_VALIDATE
    l_rows := (CALL sp_snow_step_ECI_PHN_S30_DQ(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 30 DQ_CLEAN_VALIDATE', :l_rows) || CHR(10);

    -- ---- step 40 ROUTED_GROUPS
    l_rows := (CALL sp_snow_step_ECI_PHN_S40_ROUTED(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 40 ROUTED_GROUPS', :l_rows) || CHR(10);

    -- ---- step 50 READY_TO_PUBLISH
    l_rows := (CALL sp_snow_step_ECI_PHN_S50_READY(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 50 READY_TO_PUBLISH', :l_rows) || CHR(10);

    -- ---- Publish: one transaction, all branches in order
    BEGIN TRANSACTION;
    -- ---- step 60 PUBLISH_C_S_ECI_PTY_RLE_PHN -> C_S_ECI_PTY_RLE_PHN
    l_rows := (CALL sp_snow_pub_ECI_PHN_C_S_ECI_PTY_RLE_PHN());
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 60 PUBLISH_C_S_ECI_PTY_RLE_PHN', :l_rows) || CHR(10);
    -- ---- step 70 PUBLISH_EXC_STG_BAD_REC_MEMB_PHONE -> EXC_STG_BAD_REC_MEMB
    l_rows := (CALL sp_snow_pub_ECI_PHN_EXC_STG_BAD_REC_MEMB_PHONE());
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 70 PUBLISH_EXC_STG_BAD_REC_MEMB_PHONE', :l_rows) || CHR(10);
    -- ---- step 80 PUBLISH_C_S_ECI_PTY_RLE_EADDR -> C_S_ECI_PTY_RLE_EADDR
    l_rows := (CALL sp_snow_pub_ECI_PHN_C_S_ECI_PTY_RLE_EADDR());
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 80 PUBLISH_C_S_ECI_PTY_RLE_EADDR', :l_rows) || CHR(10);
    -- ---- step 90 PUBLISH_EXC_STG_BAD_REC_MEMB_EMAIL -> EXC_STG_BAD_REC_MEMB
    l_rows := (CALL sp_snow_pub_ECI_PHN_EXC_STG_BAD_REC_MEMB_EMAIL());
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 90 PUBLISH_EXC_STG_BAD_REC_MEMB_EMAIL', :l_rows) || CHR(10);
    COMMIT;

    RETURN l_summary;
EXCEPTION
    WHEN OTHER THEN
        ROLLBACK;
        RAISE;
END;
$$;
