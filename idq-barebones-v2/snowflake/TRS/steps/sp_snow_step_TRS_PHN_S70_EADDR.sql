-- ============================================================================
-- sp_snow_step_TRS_PHN_S70_EADDR  --  BARE-BONES STEP (TRS)
--
-- Mapping: m_Tgt_C_S_TRS_Pty_Rle_Phn_And_EAddr, workflow wf_TRS_Stage_Load_1_Ongoing.
-- Step name: EADDR_VERSIONS. Produces: WRK_TRS_PHN_S7_VERSIONS.
-- Consumes (v2.1 declared inputs): WRK_TRS_PHN_S6_EMAILS.
-- Original params used: none; plus P_RUN_TS (run timestamp).
--
-- The CTAS below is the v2.1 step SELECT verbatim. The only removals
-- were the work-table existence check and the step completion call.
-- No exception block (errors propagate to the driver handler), no
-- transactions, no target writes. Returns the row count.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_step_TRS_PHN_S70_EADDR (

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

    -- ---- Step 70: EADDR_VERSIONS (verbatim from current main)
CREATE OR REPLACE TRANSIENT TABLE WRK_TRS_PHN_S7_VERSIONS AS
    SELECT v.*,
           xea.PKEY_SRC_OBJECT IS NULL                                                      AS uq_tgt
      FROM (SELECT d.*,
                   /* TIMELINE */ COUNT(*) OVER (PARTITION BY d.pkey_src_object)                    AS version_seq,
                   ROW_NUMBER() OVER (PARTITION BY d.pkey_src_object
                                      ORDER BY d.period_start_date DESC NULLS FIRST, d.pty_rle_fk DESC,
                                               d.elec_addr DESC)                                    AS rn
              FROM (SELECT DISTINCT e.CREATE_DT AS period_start_date,
                           TO_VARCHAR(e.INDV_ID) || '|Member|001|' || NVL(e.EMAIL, '') AS pkey_src_object,
                           e.PTY_PK || '|Member' AS pty_rle_fk, e.std_email AS elec_addr
                      FROM WRK_TRS_PHN_S6_EMAILS e
                     WHERE e.em_exc_code IS NULL
                       AND e.std_email IS NOT NULL) d) v
      LEFT JOIN (SELECT DISTINCT PKEY_SRC_OBJECT, VERSION_SEQ FROM C_S_TRS_PTY_RLE_EADDR) xea
             ON xea.PKEY_SRC_OBJECT = v.pkey_src_object AND xea.VERSION_SEQ = v.version_seq;
    SELECT COUNT(*) INTO :l_rows FROM WRK_TRS_PHN_S7_VERSIONS;
    RETURN :l_rows;
END;$$;
