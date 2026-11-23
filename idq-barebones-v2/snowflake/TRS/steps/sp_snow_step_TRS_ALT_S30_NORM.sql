-- ============================================================================
-- sp_snow_step_TRS_ALT_S30_NORM  --  BARE-BONES STEP (TRS)
--
-- Mapping: m_Tgt_C_S_TRS_Pty_Rle_Alt_Id, workflow wf_TRS_Stage_Load_1_Ongoing.
-- Step name: NORMALIZED. Produces: WRK_TRS_ALT_S3_NORM.
-- Consumes (v2.1 declared inputs): WRK_TRS_ALT_S2_SSN.
-- Original params used: none; plus P_RUN_TS (run timestamp).
--
-- The CTAS below is the v2.1 step SELECT verbatim. The only removals
-- were the work-table existence check and the step completion call.
-- No exception block (errors propagate to the driver handler), no
-- transactions, no target writes. Returns the row count.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_step_TRS_ALT_S30_NORM (

    P_RUN_TS                 TIMESTAMP_NTZ DEFAULT NULL

)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    l_rows       NUMBER DEFAULT 0;
BEGIN

    -- ---- Step 30: NORMALIZED (verbatim from current main)
CREATE OR REPLACE TRANSIENT TABLE WRK_TRS_ALT_S3_NORM AS
    SELECT n.*
      FROM WRK_TRS_ALT_S2_SSN w,
           TABLE(fn_snow_helper01_m_Tgt_C_S_TRS_Pty_Rle_Alt_Id(w.PTY_PKEY, w.START_DT, 'TRS', w.MEMBER_ID,
                                                               w.valid_ssn, w.MEMBER_ID, NULL, w.CV_IND)) n;
    SELECT COUNT(*) INTO :l_rows FROM WRK_TRS_ALT_S3_NORM;
    RETURN :l_rows;
END;$$;
