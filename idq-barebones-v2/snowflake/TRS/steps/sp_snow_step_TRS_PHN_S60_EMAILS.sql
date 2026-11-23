-- ============================================================================
-- sp_snow_step_TRS_PHN_S60_EMAILS  --  BARE-BONES STEP (TRS)
--
-- Mapping: m_Tgt_C_S_TRS_Pty_Rle_Phn_And_EAddr, workflow wf_TRS_Stage_Load_1_Ongoing.
-- Step name: EMAILS_CHECKED. Produces: WRK_TRS_PHN_S6_EMAILS.
-- Consumes (v2.1 declared inputs): WRK_TRS_PHN_S1_SRC.
-- Original params used: none; plus P_RUN_TS (run timestamp).
--
-- The CTAS below is the v2.1 step SELECT verbatim. The only removals
-- were the work-table existence check and the step completion call.
-- No exception block (errors propagate to the driver handler), no
-- transactions, no target writes. Returns the row count.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_step_TRS_PHN_S60_EMAILS (

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

    -- ---- Step 60: EMAILS_CHECKED (verbatim from current main)
CREATE OR REPLACE TRANSIENT TABLE WRK_TRS_PHN_S6_EMAILS AS
    WITH
    lkp_exc AS (SELECT * FROM TABLE(fn_snow_helper40_common())),
    emails AS (
        SELECT s.*,
               fn_snow_helper22_common(s.EMAIL)                                AS em
          FROM WRK_TRS_PHN_S1_SRC s
         WHERE TRIM(s.EMAIL) IS NOT NULL
    ),
    emails_checked AS (
        SELECT e.*,
               e.em:email_address::VARCHAR                                     AS std_email,
               xe.EXCEPTION_CODE AS em_exc_code, xe.EXCEPTION_DESC AS em_exc_desc, xe.EXCEPTION_TYPE AS em_exc_type
          FROM emails e
          LEFT JOIN lkp_exc xe ON xe.EXCEPTION_CODE = e.em:exception_code::VARCHAR
    )
    SELECT ec.*,
           -- usg_tp is NULL for every e-mail row, so it does not change the grouping and is omitted here
           ROW_NUMBER() OVER (PARTITION BY TO_VARCHAR(ec.INDV_ID), TO_VARCHAR(ec.CASE_NUM), ec.em_exc_type, ec.em_exc_code
                                  ORDER BY ec.CREATE_DT DESC) = 1                       AS uq_exc
      FROM emails_checked ec;
    SELECT COUNT(*) INTO :l_rows FROM WRK_TRS_PHN_S6_EMAILS;
    RETURN :l_rows;
END;$$;
