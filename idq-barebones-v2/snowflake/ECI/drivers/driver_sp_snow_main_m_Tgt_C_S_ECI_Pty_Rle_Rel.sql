-- sp_snow_main_m_Tgt_C_S_ECI_Pty_Rle_Rel -- BARE-BONES variant (ECI)
-- Mapping: m_Tgt_C_S_ECI_Pty_Rle_Rel, workflow wf_ECI_Stage_Load.
-- Unconditional steps in order; step 5 drops prior work tables at the start;
-- work tables are left standing at the end. Publish runs in one transaction.
-- The driver returns one summary string built with fn_snow_helper36_common.
-- No gating, no checkpointing, no run-id tracking.
CREATE OR REPLACE PROCEDURE sp_snow_main_m_Tgt_C_S_ECI_Pty_Rle_Rel ()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    c_mapping    VARCHAR DEFAULT 'm_Tgt_C_S_ECI_Pty_Rle_Rel';
    l_run_ts     TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()::TIMESTAMP_NTZ;
    l_rows       NUMBER DEFAULT 0;
    l_summary    VARCHAR DEFAULT '';
BEGIN
    -- ---- Step 5: CLEANUP_PREVIOUS_RUN
    DROP TABLE IF EXISTS WRK_ECI_REL_S10_SRC;
    DROP TABLE IF EXISTS WRK_ECI_REL_S20_KEYED;
    DROP TABLE IF EXISTS WRK_ECI_REL_S30_TYPED;
    DROP TABLE IF EXISTS WRK_ECI_REL_S40_READY;

    -- ---- step 10 SRC_BOTH_DIRECTIONS
    l_rows := (CALL sp_snow_step_ECI_REL_S10_SRC(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 10 SRC_BOTH_DIRECTIONS', :l_rows) || CHR(10);

    -- ---- step 20 KEYED_BOTH_ACTIVE
    l_rows := (CALL sp_snow_step_ECI_REL_S20_KEYED(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 20 KEYED_BOTH_ACTIVE', :l_rows) || CHR(10);

    -- ---- step 30 CODED_TRANSLATED
    l_rows := (CALL sp_snow_step_ECI_REL_S30_TYPED(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 30 CODED_TRANSLATED', :l_rows) || CHR(10);

    -- ---- step 40 READY_TO_PUBLISH
    l_rows := (CALL sp_snow_step_ECI_REL_S40_READY(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 40 READY_TO_PUBLISH', :l_rows) || CHR(10);

    -- ---- Publish: one transaction, all branches in order
    BEGIN TRANSACTION;
    -- ---- step 50 PUBLISH_C_S_ECI_PTY_RLE_REL -> C_S_ECI_PTY_RLE_REL
    l_rows := (CALL sp_snow_pub_ECI_REL_C_S_ECI_PTY_RLE_REL());
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 50 PUBLISH_C_S_ECI_PTY_RLE_REL', :l_rows) || CHR(10);
    -- ---- step 60 PUBLISH_EXC_STG_BAD_REC_MEMB -> EXC_STG_BAD_REC_MEMB
    l_rows := (CALL sp_snow_pub_ECI_REL_EXC_STG_BAD_REC_MEMB());
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 60 PUBLISH_EXC_STG_BAD_REC_MEMB', :l_rows) || CHR(10);
    COMMIT;

    RETURN l_summary;
EXCEPTION
    WHEN OTHER THEN
        ROLLBACK;
        RAISE;
END;
$$;
