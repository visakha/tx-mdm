-- ============================================================================
-- sp_snow_step_TRS_PHN_S40_PHONES  --  BARE-BONES STEP (TRS)
--
-- Mapping: m_Tgt_C_S_TRS_Pty_Rle_Phn_And_EAddr, workflow wf_TRS_Stage_Load_1_Ongoing.
-- Step name: PHONES. Produces: WRK_TRS_PHN_S4_PHONES.
-- Consumes (v2.1 declared inputs): WRK_TRS_PHN_S3_CHECKED.
-- Original params used: none; plus P_RUN_TS (run timestamp).
--
-- The CTAS below is the v2.1 step SELECT verbatim. The only removals
-- were the work-table existence check and the step completion call.
-- No exception block (errors propagate to the driver handler), no
-- transactions, no target writes. Returns the row count.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_step_TRS_PHN_S40_PHONES (

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

    -- ---- Step 40: PHONES (verbatim from current main)
CREATE OR REPLACE TRANSIENT TABLE WRK_TRS_PHN_S4_PHONES AS
    WITH
    lkp_exc AS (SELECT * FROM TABLE(fn_snow_helper40_common())),
    lkp_lcv AS (SELECT * FROM TABLE(fn_snow_helper45_common())),
    phones AS (
        SELECT p.PERIOD_START_DATE AS period_start_date, p.PTY_FK AS pty_fk, p.PREF_LVL AS pref_lvl,
               p.USG_TP AS usg_tp, p.PHN_TP AS phn_tp, p.phn_num, p.SRC_SYS AS src_sys_in,
               p.CASE_NUMBER AS case_number, p.dq_exception_code, xp.EXCEPTION_DESC AS dq_exception,
               NVL(p.PTY_FK, '') || '|Member'                                                 AS pty_rle_fk,
               NVL(p.PTY_FK, '') || '|Member|' || NVL(p.PHN_TP, '') || '|' || NVL(u.MSTR_REF_CODE, '') || '|'
               || p.phn_num                                                                   AS pkey_src_object
          FROM WRK_TRS_PHN_S3_CHECKED p
          LEFT JOIN lkp_lcv u ON u.CODE_TYPE = 'PHN_USG_TP' AND u.MSTR_REF_CODE = p.USG_TP AND u.SRC_SYS = p.SRC_SYS
          LEFT JOIN lkp_exc xp ON xp.EXCEPTION_CODE = p.dq_exception_code
         WHERE p.phn_num IS NOT NULL
    )
    SELECT ph.*,
           ROW_NUMBER() OVER (PARTITION BY ph.pty_fk, ph.case_number, ph.usg_tp, 'Bad Value', ph.dq_exception_code
                                  ORDER BY ph.period_start_date DESC) = 1                       AS uq_exc
      FROM phones ph;
    SELECT COUNT(*) INTO :l_rows FROM WRK_TRS_PHN_S4_PHONES;
    RETURN :l_rows;
END;$$;
