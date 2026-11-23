-- ============================================================================
-- sp_snow_step_TRS_PHN_S20_SLOTS  --  BARE-BONES STEP (TRS)
--
-- Mapping: m_Tgt_C_S_TRS_Pty_Rle_Phn_And_EAddr, workflow wf_TRS_Stage_Load_1_Ongoing.
-- Step name: PHONE_SLOTS. Produces: WRK_TRS_PHN_S2_SLOTS.
-- Consumes (v2.1 declared inputs): WRK_TRS_PHN_S1_SRC.
-- Original params used: none; plus P_RUN_TS (run timestamp).
--
-- The CTAS below is the v2.1 step SELECT verbatim. The only removals
-- were the work-table existence check and the step completion call.
-- No exception block (errors propagate to the driver handler), no
-- transactions, no target writes. Returns the row count.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_step_TRS_PHN_S20_SLOTS (

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

    -- ---- Step 20: PHONE_SLOTS (verbatim from current main)
CREATE OR REPLACE TRANSIENT TABLE WRK_TRS_PHN_S2_SLOTS AS
    SELECT n.*
      FROM WRK_TRS_PHN_S1_SRC s,
           TABLE(fn_snow_helper01_m_Tgt_C_S_TRS_Pty_Rle_Phn_And_EAddr(
                 s.CREATE_DT, s.PTY_PK, 'TRS', TO_VARCHAR(s.CASE_NUM),
                 '001', 'Telephone', s.PH_NUM,
                 '002', 'Telephone', IFF(s.WORK_PH_NUM IS NULL, NULL,
                                         RTRIM(s.WORK_PH_NUM || ' ' || NVL(s.WORK_PH_NUM_EXT, ''))),
                 '003', 'Telephone', s.OTHER_PH_NUM)) n;
    SELECT COUNT(*) INTO :l_rows FROM WRK_TRS_PHN_S2_SLOTS;
    RETURN :l_rows;
END;$$;
