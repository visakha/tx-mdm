-- ============================================================================
-- sp_snow_main_m_Tgt_C_S_TTF_Pty -- BARE-BONES variant (TTF)
--
-- Mapping: m_Tgt_C_S_TTF_Pty, workflow wf_TTF_Stage_Load.
-- No config table, no checkpointing, no job-run id. Every step runs
-- unconditionally, in order; publish is one transaction; the driver
-- returns one summary string built with fn_snow_helper36_common.
-- Step 5 drops the previous run's work tables (bare drops, as before);
-- work tables are left standing at the end of a run.
-- Business SQL is unchanged from the v2.1 step-driver code.
-- ============================================================================

CREATE OR REPLACE PROCEDURE sp_snow_main_m_Tgt_C_S_TTF_Pty (
    P_PTY_BO_CLASS_CD_MEMBER VARCHAR DEFAULT 'Indv',
    P_RLE_BO_CLASS_CD_MEMBER VARCHAR DEFAULT 'Member'
)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    c_mapping    VARCHAR DEFAULT 'm_Tgt_C_S_TTF_Pty';
    l_run_ts     TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()::TIMESTAMP_NTZ;
    l_rows       NUMBER DEFAULT 0;
    l_summary    VARCHAR DEFAULT '';
BEGIN
    -- ---- Step 5: CLEANUP_PREVIOUS_RUN -- drop work tables left by a previous run
    DROP TABLE IF EXISTS WRK_TTF_PTY_S1_ACTIVE;
    DROP TABLE IF EXISTS WRK_TTF_PTY_S2_DQ;
    DROP TABLE IF EXISTS WRK_TTF_PTY_S3_DQ2;
    DROP TABLE IF EXISTS WRK_TTF_PTY_S4_ROUTED;

    -- ---- Step 10: ACTIVE
    l_rows := (CALL sp_snow_step_TTF_PTY_S10_ACTIVE(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 10 ACTIVE', :l_rows) || CHR(10);

    -- ---- Step 20: DQ
    l_rows := (CALL sp_snow_step_TTF_PTY_S20_DQ(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 20 DQ', :l_rows) || CHR(10);

    -- ---- Step 30: DQ2
    l_rows := (CALL sp_snow_step_TTF_PTY_S30_DQ2(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 30 DQ2', :l_rows) || CHR(10);

    -- ---- Step 40: ROUTED
    l_rows := (CALL sp_snow_step_TTF_PTY_S40_ROUTED(:P_PTY_BO_CLASS_CD_MEMBER, :P_RLE_BO_CLASS_CD_MEMBER, :l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 40 ROUTED', :l_rows) || CHR(10);

    -- ---- PUBLISH: ONE transaction, all branches, in order ----
    BEGIN TRANSACTION;
    l_rows := (CALL sp_snow_pub_TTF_PTY_C_S_TTF_PTY());
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 50 PUBLISH_C_S_TTF_PTY', :l_rows) || CHR(10);
    l_rows := (CALL sp_snow_pub_TTF_PTY_C_S_TTF_PTY_RLE());
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 60 PUBLISH_C_S_TTF_PTY_RLE', :l_rows) || CHR(10);
    l_rows := (CALL sp_snow_pub_TTF_PTY_EXC_STG_BAD_REC_MEMB_GENDER());
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 70 PUBLISH_EXC_GENDER', :l_rows) || CHR(10);
    l_rows := (CALL sp_snow_pub_TTF_PTY_EXC_STG_BAD_REC_MEMB_BIRTH());
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 80 PUBLISH_EXC_BIRTH', :l_rows) || CHR(10);
    l_rows := (CALL sp_snow_pub_TTF_PTY_EXC_STG_BAD_REC_MEMB_ETHNICITY());
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 90 PUBLISH_EXC_ETHNICITY', :l_rows) || CHR(10);
    l_rows := (CALL sp_snow_pub_TTF_PTY_EXC_STG_BAD_REC_MEMB_RACE());
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 100 PUBLISH_EXC_RACE', :l_rows) || CHR(10);
    COMMIT;

    RETURN l_summary;
EXCEPTION
    WHEN OTHER THEN
        ROLLBACK;
        RAISE;
END;
$$;
