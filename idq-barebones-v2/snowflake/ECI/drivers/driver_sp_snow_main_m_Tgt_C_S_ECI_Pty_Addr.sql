-- sp_snow_main_m_Tgt_C_S_ECI_Pty_Addr -- BARE-BONES variant (ECI)
-- Mapping: m_Tgt_C_S_ECI_Pty_Addr, workflow wf_ECI_Stage_Load.
-- Unconditional steps in order; step 5 drops prior work tables at the start;
-- work tables are left standing at the end. Publish runs in one transaction.
-- The driver returns one summary string built with fn_snow_helper36_common.
-- No gating, no checkpointing, no run-id tracking.
CREATE OR REPLACE PROCEDURE sp_snow_main_m_Tgt_C_S_ECI_Pty_Addr (
    P_MEMBER_HIERARCHY_CODE VARCHAR DEFAULT 'Member',
    P_MEMBER_HM_REL_TP_CD VARCHAR DEFAULT 'Member Addr'
)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    c_mapping    VARCHAR DEFAULT 'm_Tgt_C_S_ECI_Pty_Addr';
    l_run_ts     TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()::TIMESTAMP_NTZ;
    l_rows       NUMBER DEFAULT 0;
    l_summary    VARCHAR DEFAULT '';
BEGIN
    -- ---- Step 5: CLEANUP_PREVIOUS_RUN
    DROP TABLE IF EXISTS WRK_ECI_ADR_S10_SRC;
    DROP TABLE IF EXISTS WRK_ECI_ADR_S20_KEYED;
    DROP TABLE IF EXISTS WRK_ECI_ADR_S30_VALIDATED;
    DROP TABLE IF EXISTS WRK_ECI_ADR_S40_FLAT;
    DROP TABLE IF EXISTS WRK_ECI_ADR_S50_READY;

    -- ---- step 10 SRC_ADDRESSES
    l_rows := (CALL sp_snow_step_ECI_ADR_S10_SRC(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 10 SRC_ADDRESSES', :l_rows) || CHR(10);

    -- ---- step 20 KEYED_ACTIVE
    l_rows := (CALL sp_snow_step_ECI_ADR_S20_KEYED(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 20 KEYED_ACTIVE', :l_rows) || CHR(10);

    -- ---- step 30 ADDR_VALIDATION
    l_rows := (CALL sp_snow_step_ECI_ADR_S30_VALIDATED(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 30 ADDR_VALIDATION', :l_rows) || CHR(10);

    -- ---- step 40 FLAT_VALIDATION
    l_rows := (CALL sp_snow_step_ECI_ADR_S40_FLAT(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 40 FLAT_VALIDATION', :l_rows) || CHR(10);

    -- ---- step 50 SCORED_READY
    l_rows := (CALL sp_snow_step_ECI_ADR_S50_READY(:P_MEMBER_HIERARCHY_CODE, :P_MEMBER_HM_REL_TP_CD, :l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 50 SCORED_READY', :l_rows) || CHR(10);

    -- ---- Publish: one transaction, all branches in order
    BEGIN TRANSACTION;
    -- ---- step 60 PUBLISH_DQM_ADDRESS -> DQM_ADDRESS
    l_rows := (CALL sp_snow_pub_ECI_ADR_DQM_ADDRESS());
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 60 PUBLISH_DQM_ADDRESS', :l_rows) || CHR(10);
    -- ---- step 70 PUBLISH_C_S_ECI_PTY_RLE_ADDR -> C_S_ECI_PTY_RLE_ADDR
    l_rows := (CALL sp_snow_pub_ECI_ADR_C_S_ECI_PTY_RLE_ADDR());
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 70 PUBLISH_C_S_ECI_PTY_RLE_ADDR', :l_rows) || CHR(10);
    -- ---- step 80 PUBLISH_EXC_STG_BAD_REC_MEMB -> EXC_STG_BAD_REC_MEMB
    l_rows := (CALL sp_snow_pub_ECI_ADR_EXC_STG_BAD_REC_MEMB());
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 80 PUBLISH_EXC_STG_BAD_REC_MEMB', :l_rows) || CHR(10);
    COMMIT;

    RETURN l_summary;
EXCEPTION
    WHEN OTHER THEN
        ROLLBACK;
        RAISE;
END;
$$;
