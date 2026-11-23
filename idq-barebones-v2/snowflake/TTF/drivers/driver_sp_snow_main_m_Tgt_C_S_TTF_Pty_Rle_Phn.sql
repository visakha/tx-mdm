-- ============================================================================
-- sp_snow_main_m_Tgt_C_S_TTF_Pty_Rle_Phn -- BARE-BONES variant (TTF)
--
-- Mapping: m_Tgt_C_S_TTF_Pty_Rle_Phn, workflow wf_TTF_Stage_Load.
-- No config table, no checkpointing, no job-run id. Every step runs
-- unconditionally, in order; publish is one transaction; the driver
-- returns one summary string built with fn_snow_helper36_common.
-- Step 5 drops the previous run's work tables (bare drops, as before);
-- work tables are left standing at the end of a run.
-- Business SQL is unchanged from the v2.1 step-driver code.
-- ============================================================================

CREATE OR REPLACE PROCEDURE sp_snow_main_m_Tgt_C_S_TTF_Pty_Rle_Phn (
)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    c_mapping    VARCHAR DEFAULT 'm_Tgt_C_S_TTF_Pty_Rle_Phn';
    l_run_ts     TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()::TIMESTAMP_NTZ;
    l_rows       NUMBER DEFAULT 0;
    l_summary    VARCHAR DEFAULT '';
BEGIN
    -- ---- Step 5: CLEANUP_PREVIOUS_RUN -- drop work tables left by a previous run
    DROP TABLE IF EXISTS WRK_TTF_PHN_S1_SRC;
    DROP TABLE IF EXISTS WRK_TTF_PHN_S2_CHECKED;
    DROP TABLE IF EXISTS WRK_TTF_PHN_S3_ROUTED;

    -- ---- Step 10: SRC
    l_rows := (CALL sp_snow_step_TTF_PHN_S10_SRC(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 10 SRC', :l_rows) || CHR(10);

    -- ---- Step 20: CHECKED
    l_rows := (CALL sp_snow_step_TTF_PHN_S20_CHECKED(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 20 CHECKED', :l_rows) || CHR(10);

    -- ---- Step 30: ROUTED
    l_rows := (CALL sp_snow_step_TTF_PHN_S30_ROUTED(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 30 ROUTED', :l_rows) || CHR(10);

    -- ---- PUBLISH: ONE transaction, all branches, in order ----
    BEGIN TRANSACTION;
    l_rows := (CALL sp_snow_pub_TTF_PHN_C_S_TTF_PTY_RLE_PHN());
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 40 PUBLISH_C_S_TTF_PTY_RLE_PHN', :l_rows) || CHR(10);
    l_rows := (CALL sp_snow_pub_TTF_PHN_EXC_STG_BAD_REC_MEMB());
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 50 PUBLISH_EXC_STG_BAD_REC_MEMB', :l_rows) || CHR(10);
    COMMIT;

    RETURN l_summary;
EXCEPTION
    WHEN OTHER THEN
        ROLLBACK;
        RAISE;
END;
$$;
