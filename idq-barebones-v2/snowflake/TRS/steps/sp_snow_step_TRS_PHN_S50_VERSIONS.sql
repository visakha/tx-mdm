-- ============================================================================
-- sp_snow_step_TRS_PHN_S50_VERSIONS  --  BARE-BONES STEP (TRS)
--
-- Mapping: m_Tgt_C_S_TRS_Pty_Rle_Phn_And_EAddr, workflow wf_TRS_Stage_Load_1_Ongoing.
-- Step name: PHN_VERSIONS. Produces: WRK_TRS_PHN_S5_VERSIONS.
-- Consumes (v2.1 declared inputs): WRK_TRS_PHN_S4_PHONES.
-- Original params used: none; plus P_RUN_TS (run timestamp).
--
-- The CTAS below is the v2.1 step SELECT verbatim. The only removals
-- were the work-table existence check and the step completion call.
-- No exception block (errors propagate to the driver handler), no
-- transactions, no target writes. Returns the row count.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_step_TRS_PHN_S50_VERSIONS (

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

    -- ---- Step 50: PHN_VERSIONS (verbatim from current main)
CREATE OR REPLACE TRANSIENT TABLE WRK_TRS_PHN_S5_VERSIONS AS
    SELECT v.*,
           xph.PKEY_SRC_OBJECT IS NULL                                                      AS uq_tgt
      FROM (SELECT d.*,
                   /* TIMELINE */ COUNT(*) OVER (PARTITION BY d.pkey_src_object)                    AS version_seq,
                   ROW_NUMBER() OVER (PARTITION BY d.pkey_src_object
                                      ORDER BY d.period_start_date DESC NULLS FIRST, d.pty_rle_fk DESC, d.usg_tp DESC,
                                               d.phn_tp DESC, d.phn_num DESC, d.pref_lvl DESC)      AS rn
              FROM (SELECT DISTINCT p.period_start_date, p.pkey_src_object, p.pty_rle_fk, p.usg_tp, p.phn_tp,
                           p.phn_num, p.pref_lvl
                      FROM WRK_TRS_PHN_S4_PHONES p
                     WHERE p.dq_exception_code IS NULL) d) v
      LEFT JOIN (SELECT DISTINCT PKEY_SRC_OBJECT, VERSION_SEQ FROM C_S_TRS_PTY_RLE_PHN) xph
             ON xph.PKEY_SRC_OBJECT = v.pkey_src_object AND xph.VERSION_SEQ = v.version_seq;
    SELECT COUNT(*) INTO :l_rows FROM WRK_TRS_PHN_S5_VERSIONS;
    RETURN :l_rows;
END;$$;
