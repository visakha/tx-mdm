-- ============================================================================
-- sp_snow_main_m_Tgt_C_S_TTF_Pty_Rle_Alt_Id -- BARE-BONES variant (TTF)
--
-- Mapping: m_Tgt_C_S_TTF_Pty_Rle_Alt_Id, workflow wf_TTF_Stage_Load.
-- No config table, no checkpointing, no job-run id. Every step runs
-- unconditionally, in order; publish is one transaction; the driver
-- returns one summary string built with fn_snow_helper36_common.
-- Step 5 drops the previous run's work tables (bare drops, as before);
-- work tables are left standing at the end of a run.
-- Business SQL is unchanged from the v2.1 step-driver code.
-- ============================================================================

CREATE OR REPLACE PROCEDURE sp_snow_main_m_Tgt_C_S_TTF_Pty_Rle_Alt_Id (
)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    c_mapping    VARCHAR DEFAULT 'm_Tgt_C_S_TTF_Pty_Rle_Alt_Id';
    l_run_ts     TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()::TIMESTAMP_NTZ;
    l_rows       NUMBER DEFAULT 0;
    l_summary    VARCHAR DEFAULT '';
BEGIN
    -- ---- Step 5: CLEANUP_PREVIOUS_RUN -- drop work tables left by a previous run
    DROP TABLE IF EXISTS WRK_TTF_ALT_S1_KEYS;
    DROP TABLE IF EXISTS WRK_TTF_ALT_S2_DEDUP;

    -- ---- Step 10: KEYS
    l_rows := (CALL sp_snow_step_TTF_ALT_S10_KEYS(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 10 KEYS', :l_rows) || CHR(10);

    -- ---- Step 20: DEDUP
    l_rows := (CALL sp_snow_step_TTF_ALT_S20_DEDUP(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 20 DEDUP', :l_rows) || CHR(10);

    -- ---- PUBLISH: ONE transaction, all branches, in order ----
    BEGIN TRANSACTION;
    l_rows := (CALL sp_snow_pub_TTF_ALT_C_S_TTF_PTY_RLE_ALT_ID(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 30 PUBLISH_C_S_TTF_PTY_RLE_ALT_ID', :l_rows) || CHR(10);
    COMMIT;

    RETURN l_summary;
EXCEPTION
    WHEN OTHER THEN
        ROLLBACK;
        RAISE;
END;
$$;
