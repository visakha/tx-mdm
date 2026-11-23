-- ============================================================================
-- sp_snow_step_TRS_PHN_S30_CHECKED  --  BARE-BONES STEP (TRS)
--
-- Mapping: m_Tgt_C_S_TRS_Pty_Rle_Phn_And_EAddr, workflow wf_TRS_Stage_Load_1_Ongoing.
-- Step name: PHONES_CHECKED. Produces: WRK_TRS_PHN_S3_CHECKED.
-- Consumes (v2.1 declared inputs): WRK_TRS_PHN_S2_SLOTS.
-- Original params used: none; plus P_RUN_TS (run timestamp).
--
-- The CTAS below is the v2.1 step SELECT verbatim. The only removals
-- were the work-table existence check and the step completion call.
-- No exception block (errors propagate to the driver handler), no
-- transactions, no target writes. Returns the row count.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_step_TRS_PHN_S30_CHECKED (

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

    -- ---- Step 30: PHONES_CHECKED (verbatim from current main)
CREATE OR REPLACE TRANSIENT TABLE WRK_TRS_PHN_S3_CHECKED AS
    WITH
    lkp_area AS (SELECT * FROM TABLE(fn_snow_helper44_common()))
    SELECT sl.*,
           fn_snow_helper23_common(sl.PHN_NUM_IN)                                          AS phn_num,
           /* VALIDATION */ fn_snow_helper24_common(fn_snow_helper23_common(sl.PHN_NUM_IN), NULL, NULL,
                                                    ar.NPA_ID, ar.SERVICE)                 AS dq_exception_code
      FROM WRK_TRS_PHN_S2_SLOTS sl
      LEFT JOIN lkp_area ar ON ar.NPA_ID = SUBSTR(fn_snow_helper23_common(sl.PHN_NUM_IN), 1, 3);
    SELECT COUNT(*) INTO :l_rows FROM WRK_TRS_PHN_S3_CHECKED;
    RETURN :l_rows;
END;$$;
