-- sp_snow_main_m_Tgt_C_S_ECI_Pty -- BARE-BONES variant (ECI)
-- Mapping: m_Tgt_C_S_ECI_Pty, workflow wf_ECI_Stage_Load.
-- Unconditional steps in order; step 5 drops prior work tables at the start;
-- work tables are left standing at the end. Publish runs in one transaction.
-- The driver returns one summary string built with fn_snow_helper36_common.
-- No gating, no checkpointing, no run-id tracking.
CREATE OR REPLACE PROCEDURE sp_snow_main_m_Tgt_C_S_ECI_Pty (
    P_PTY_BO_CLASS_CD_MEMBER VARCHAR DEFAULT 'Indv',
    P_RLE_BO_CLASS_CD_MEMBER VARCHAR DEFAULT 'Member'
)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    c_mapping    VARCHAR DEFAULT 'm_Tgt_C_S_ECI_Pty';
    l_run_ts     TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()::TIMESTAMP_NTZ;
    l_rows       NUMBER DEFAULT 0;
    l_summary    VARCHAR DEFAULT '';
BEGIN
    -- ---- Step 5: CLEANUP_PREVIOUS_RUN
    DROP TABLE IF EXISTS WRK_ECI_PTY_S10_SRC;
    DROP TABLE IF EXISTS WRK_ECI_PTY_S20_ACTIVE;
    DROP TABLE IF EXISTS WRK_ECI_PTY_S30_DQ;
    DROP TABLE IF EXISTS WRK_ECI_PTY_S40_DQ2;
    DROP TABLE IF EXISTS WRK_ECI_PTY_S50_READY;

    -- ---- step 10 SRC_DELTA_PARTIES
    l_rows := (CALL sp_snow_step_ECI_PTY_S10_SRC(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 10 SRC_DELTA_PARTIES', :l_rows) || CHR(10);

    -- ---- step 20 ACTIVE_PARTIES
    l_rows := (CALL sp_snow_step_ECI_PTY_S20_ACTIVE(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 20 ACTIVE_PARTIES', :l_rows) || CHR(10);

    -- ---- step 30 DQ_RULES
    l_rows := (CALL sp_snow_step_ECI_PTY_S30_DQ(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 30 DQ_RULES', :l_rows) || CHR(10);

    -- ---- step 40 DQ_EXCEPTIONS_RESOLVED
    l_rows := (CALL sp_snow_step_ECI_PTY_S40_DQ2(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 40 DQ_EXCEPTIONS_RESOLVED', :l_rows) || CHR(10);

    -- ---- step 50 ROUTED_READY
    l_rows := (CALL sp_snow_step_ECI_PTY_S50_READY(:P_PTY_BO_CLASS_CD_MEMBER, :P_RLE_BO_CLASS_CD_MEMBER, :l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 50 ROUTED_READY', :l_rows) || CHR(10);

    -- ---- Publish: one transaction, all branches in order
    BEGIN TRANSACTION;
    -- ---- step 60 PUBLISH_C_S_ECI_PTY -> C_S_ECI_PTY
    l_rows := (CALL sp_snow_pub_ECI_PTY_C_S_ECI_PTY());
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 60 PUBLISH_C_S_ECI_PTY', :l_rows) || CHR(10);
    -- ---- step 70 PUBLISH_C_S_ECI_PTY_RLE -> C_S_ECI_PTY_RLE
    l_rows := (CALL sp_snow_pub_ECI_PTY_C_S_ECI_PTY_RLE());
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 70 PUBLISH_C_S_ECI_PTY_RLE', :l_rows) || CHR(10);
    -- ---- step 80 PUBLISH_EXC_GENDER -> EXC_STG_BAD_REC_MEMB
    l_rows := (CALL sp_snow_pub_ECI_PTY_EXC_STG_BAD_REC_MEMB_GENDER());
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 80 PUBLISH_EXC_GENDER', :l_rows) || CHR(10);
    -- ---- step 90 PUBLISH_EXC_BIRTH -> EXC_STG_BAD_REC_MEMB
    l_rows := (CALL sp_snow_pub_ECI_PTY_EXC_STG_BAD_REC_MEMB_BIRTH());
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 90 PUBLISH_EXC_BIRTH', :l_rows) || CHR(10);
    -- ---- step 100 PUBLISH_EXC_ETHNICITY -> EXC_STG_BAD_REC_MEMB
    l_rows := (CALL sp_snow_pub_ECI_PTY_EXC_STG_BAD_REC_MEMB_ETHNICITY());
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 100 PUBLISH_EXC_ETHNICITY', :l_rows) || CHR(10);
    -- ---- step 110 PUBLISH_EXC_RACE -> EXC_STG_BAD_REC_MEMB
    l_rows := (CALL sp_snow_pub_ECI_PTY_EXC_STG_BAD_REC_MEMB_RACE());
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 110 PUBLISH_EXC_RACE', :l_rows) || CHR(10);
    -- ---- step 120 PUBLISH_EXC_LANGUAGE -> EXC_STG_BAD_REC_MEMB
    l_rows := (CALL sp_snow_pub_ECI_PTY_EXC_STG_BAD_REC_MEMB_LANGUAGE());
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 120 PUBLISH_EXC_LANGUAGE', :l_rows) || CHR(10);
    COMMIT;

    RETURN l_summary;
EXCEPTION
    WHEN OTHER THEN
        ROLLBACK;
        RAISE;
END;
$$;
