-- sp_snow_main_m_Tgt_Stg_ECI_Pty_Reactivation_D_Family_Phn -- BARE-BONES variant (ECI)
-- Mapping: m_Tgt_Stg_ECI_Pty_Reactivation_D_Family_Phn, workflow wf_ECI_Stage_Load.
-- Unconditional steps in order; step 5 drops prior work tables at the start;
-- work tables are left standing at the end. Publish runs in one transaction.
-- The driver returns one summary string built with fn_snow_helper36_common.
-- No gating, no checkpointing, no run-id tracking.
CREATE OR REPLACE PROCEDURE sp_snow_main_m_Tgt_Stg_ECI_Pty_Reactivation_D_Family_Phn ()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    c_mapping        VARCHAR DEFAULT 'm_Tgt_Stg_ECI_Pty_Reactivation_D_Family_Phn';
    l_run_ts         TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP();
    l_rows           NUMBER DEFAULT 0;
    l_summary        VARCHAR DEFAULT '';
BEGIN
    -- ---- Step 5: CLEANUP_PREVIOUS_RUN
    DROP TABLE IF EXISTS WRK_ECI_RFP_S10_LATEST;
    DROP TABLE IF EXISTS WRK_ECI_RFP_S20_KEEPNEW;

    -- ---- step 10 LATEST_HISTORY_ROWS
    l_rows := (CALL sp_snow_step_ECI_RFP_S10_LATEST(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 10 LATEST_HISTORY_ROWS', :l_rows) || CHR(10);

    -- ---- step 20 KEEP_NEW_ONLY
    l_rows := (CALL sp_snow_step_ECI_RFP_S20_KEEPNEW(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 20 KEEP_NEW_ONLY', :l_rows) || CHR(10);

    -- ---- Publish: one transaction, all branches in order
    BEGIN TRANSACTION;
    -- ---- step 30 PUBLISH_STG_ECI_D_FAMILY_PHONE -> STG_ECI_D_FAMILY_PHONE
    l_rows := (CALL sp_snow_pub_ECI_RFP_STG_ECI_D_FAMILY_PHONE());
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 30 PUBLISH_STG_ECI_D_FAMILY_PHONE', :l_rows) || CHR(10);
    COMMIT;

    RETURN l_summary;
EXCEPTION
    WHEN OTHER THEN
        ROLLBACK;
        RAISE;
END;
$$;
