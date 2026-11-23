-- ============================================================================
-- sp_snow_main_m_Tgt_C_S_TRS_Pty_OnGoing  --  BARE-BONES STEP DRIVER (TRS)
--
-- IDQ mapping: m_Tgt_C_S_TRS_Pty_OnGoing, workflow wf_TRS_Stage_Load_1_Ongoing.
-- Bare-bones variant: no run-config table, no job-control calls, no
-- flags. Every step runs unconditionally, in order, and every step
-- and branch appends one line to the summary string via
-- fn_snow_helper36_common. Step 5 drops the mapping work tables
-- (bare drops); work tables are NOT dropped at the end of a run and
-- stay in the database until the next run of this mapping cleans
-- them up. Publish is ONE transaction: all branch calls, then COMMIT.
-- On error: ROLLBACK + RAISE. The driver RETURNs l_summary.
--
-- BUSINESS FLOW (read this top to bottom -- it IS the business flow)
--     Step  10  SRC_VALID_LIST                                WRK_TRS_PTY_S1_SRC
--     Step  20  DQ_STANDARDISE_VALIDATE                       WRK_TRS_PTY_S2_DQ
--     Step  30  ROUTER_EXCEPTIONS                             WRK_TRS_PTY_S3_ROUTER
--     Step  40  DEDUP_VALID                                   WRK_TRS_PTY_S4_DEDUP
--     Step  50  PUBLISH_EXC_NAME                              EXC_STG_BAD_REC_MEMB (publish)
--     Step  60  PUBLISH_EXC_GENDER                            EXC_STG_BAD_REC_MEMB (publish)
--     Step  70  PUBLISH_EXC_DEATH                             EXC_STG_BAD_REC_MEMB (publish)
--     Step  80  PUBLISH_EXC_BIRTH                             EXC_STG_BAD_REC_MEMB (publish)
--     Step  90  PUBLISH_C_S_TRS_PTY                           C_S_TRS_PTY (publish)
--     Step 100  PUBLISH_C_S_TRS_PTY_RLE                       C_S_TRS_PTY_RLE (publish)
--     Step 110  PUBLISH_STG_TRS_VALID_MEMBERS                 STG_TRS_VALID_MEMBERS (publish)
--     Step 120  PUBLISH_EXC_RACE                              EXC_STG_BAD_REC_MEMB (publish)
--     Step 130  PUBLISH_EXC_ETHNICITY                         EXC_STG_BAD_REC_MEMB (publish)
--
-- PARITY NOTES (kept deliberately, do not "fix" silently; condensed
-- from the current main header -- see the manifest for the full text)
----   (kept deliberately, do not "fix" silently)
--     * Insert-only, as in the original Snowflake code: no TRUNCATE, no
--       DELETE of targets.  IDQ truncates C_S_TRS_PTY / C_S_TRS_PTY_RLE;
--       the Snowflake version instead skips keys already present
--       (uq_pty / uq_rle / uq_exc_* guards).  A re-run therefore inserts
--       nothing twice, but it also does not remove rows that IDQ would
--       have truncated away -- see the User Guide, "Parity gaps".
--     * The stored source filter INDV_ID = 504937068 is NOT applied here,
--       exactly as in the original Snowflake code (it was not part of the
--       custom query).  Confirm in the live IDQ mapping whether it should
--       be (BR notes, Verify item 1).
--     * VERSION_SEQ is hard-coded to 1 (TIMELINE: the MD5 / version
--       comparison is commented out in IDQ); PERIOD_END_DATE,
--       PERIOD_REFERENCE_TIME and TIMELINE_ACTION are NULL (unfed ports).
--
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_main_m_Tgt_C_S_TRS_Pty_OnGoing (

    P_PTY_BO_CLASS_CD_MEMBER VARCHAR DEFAULT 'Indv',
    P_RLE_BO_CLASS_CD_MEMBER VARCHAR DEFAULT 'Member',
    P_DC_INDV_TBL_SRC        VARCHAR DEFAULT 'DC_INDV',
    P_MCI_TBL_SRC            VARCHAR DEFAULT 'MCI'

)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    c_mapping    VARCHAR DEFAULT 'm_Tgt_C_S_TRS_Pty_OnGoing';
    l_run_ts     TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()::TIMESTAMP_NTZ;
    l_rows       NUMBER DEFAULT 0;
    l_summary    VARCHAR DEFAULT '';
BEGIN
    -- ---- Step 5: CLEANUP_PREVIOUS_RUN -- drop work tables left by a previous run
    DROP TABLE IF EXISTS WRK_TRS_PTY_S1_SRC;
    DROP TABLE IF EXISTS WRK_TRS_PTY_S2_DQ;
    DROP TABLE IF EXISTS WRK_TRS_PTY_S3_ROUTER;
    DROP TABLE IF EXISTS WRK_TRS_PTY_S4_DEDUP;

    -- ---- Step 10: SRC_VALID_LIST
    l_rows := (CALL sp_snow_step_TRS_PTY_S10_SRC(:P_DC_INDV_TBL_SRC, :P_MCI_TBL_SRC, :l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 10 SRC_VALID_LIST', :l_rows) || CHR(10);

    -- ---- Step 20: DQ_STANDARDISE_VALIDATE
    l_rows := (CALL sp_snow_step_TRS_PTY_S20_DQ(:P_DC_INDV_TBL_SRC, :l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 20 DQ_STANDARDISE_VALIDATE', :l_rows) || CHR(10);

    -- ---- Step 30: ROUTER_EXCEPTIONS
    l_rows := (CALL sp_snow_step_TRS_PTY_S30_ROUTER(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 30 ROUTER_EXCEPTIONS', :l_rows) || CHR(10);

    -- ---- Step 40: DEDUP_VALID
    l_rows := (CALL sp_snow_step_TRS_PTY_S40_DEDUP(:P_RLE_BO_CLASS_CD_MEMBER, :l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 40 DEDUP_VALID', :l_rows) || CHR(10);

    -- ---- PUBLISH: ONE transaction, all branches, in order ----
    BEGIN TRANSACTION;
    l_rows := (CALL sp_snow_pub_TRS_PTY_EXC_STG_BAD_REC_MEMB_NAME(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 50 PUBLISH_EXC_NAME', :l_rows) || CHR(10);
    l_rows := (CALL sp_snow_pub_TRS_PTY_EXC_STG_BAD_REC_MEMB_GENDER(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 60 PUBLISH_EXC_GENDER', :l_rows) || CHR(10);
    l_rows := (CALL sp_snow_pub_TRS_PTY_EXC_STG_BAD_REC_MEMB_DEATH(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 70 PUBLISH_EXC_DEATH', :l_rows) || CHR(10);
    l_rows := (CALL sp_snow_pub_TRS_PTY_EXC_STG_BAD_REC_MEMB_BIRTH(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 80 PUBLISH_EXC_BIRTH', :l_rows) || CHR(10);
    l_rows := (CALL sp_snow_pub_TRS_PTY_C_S_TRS_PTY(:P_PTY_BO_CLASS_CD_MEMBER, :l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 90 PUBLISH_C_S_TRS_PTY', :l_rows) || CHR(10);
    l_rows := (CALL sp_snow_pub_TRS_PTY_C_S_TRS_PTY_RLE(:P_RLE_BO_CLASS_CD_MEMBER, :l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 100 PUBLISH_C_S_TRS_PTY_RLE', :l_rows) || CHR(10);
    l_rows := (CALL sp_snow_pub_TRS_PTY_STG_TRS_VALID_MEMBERS(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 110 PUBLISH_STG_TRS_VALID_MEMBERS', :l_rows) || CHR(10);
    l_rows := (CALL sp_snow_pub_TRS_PTY_EXC_STG_BAD_REC_MEMB_RACE(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 120 PUBLISH_EXC_RACE', :l_rows) || CHR(10);
    l_rows := (CALL sp_snow_pub_TRS_PTY_EXC_STG_BAD_REC_MEMB_ETHNICITY(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 130 PUBLISH_EXC_ETHNICITY', :l_rows) || CHR(10);
    COMMIT;

    RETURN l_summary;
EXCEPTION
    WHEN OTHER THEN
        ROLLBACK;
        RAISE;
END;
$$;
