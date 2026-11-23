-- ============================================================================
-- sp_snow_step_TRS_RELDEACT_S30_KEYED  --  BARE-BONES STEP (TRS)
--
-- Mapping: m_Tgt_C_S_TRS_Pty_Rle_Rel_DeActivation_1, workflow wf_TRS_Stage_Load_1_Ongoing.
-- Step name: KEYED_REL. Produces: WRK_TRS_RELDEACT_S30_KEYED.
-- Consumes (v2.1 declared inputs): WRK_TRS_RELDEACT_S20_SRC.
-- Original params used: none; plus P_RUN_TS (run timestamp).
--
-- The CTAS below is the v2.1 step SELECT verbatim. The only removals
-- were the work-table existence check and the step completion call.
-- No exception block (errors propagate to the driver handler), no
-- transactions, no target writes. Returns the row count.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_step_TRS_RELDEACT_S30_KEYED (

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

    -- ---- Step 30: KEYED_REL (verbatim from current main)
CREATE OR REPLACE TRANSIENT TABLE WRK_TRS_RELDEACT_S30_KEYED AS
    WITH
    lkp_cv AS (SELECT * FROM TABLE(fn_snow_helper41_common()))
    SELECT s.*,
           IFF(s.PTY_PKEY IS NULL, NULL, TRIM(s.PTY_PKEY) || '|Member')               AS pty_rle_fk_1,
           IFF(s.REF_PTY_PKEY IS NULL, NULL, TRIM(s.REF_PTY_PKEY) || '|Member')       AS pty_rle_fk_2,
           NVL(IFF(s.PTY_PKEY IS NULL, NULL, TRIM(s.PTY_PKEY) || '|Member'), '') || '|'
           || NVL(IFF(s.REF_PTY_PKEY IS NULL, NULL, TRIM(s.REF_PTY_PKEY) || '|Member'), '') || '|'
           || NVL(pt.MSTR_CODE_VALUE, '')                                             AS pkey_src_object
      FROM WRK_TRS_RELDEACT_S20_SRC s
      LEFT JOIN lkp_cv pt ON pt.CODE_TYPE = 'PTY_REL' AND pt.SRC_SYS = s.SRC_SYS
                         AND pt.SRC_CODE_VALUE = s.RELATIONSHIP_TYPE_CD;
    SELECT COUNT(*) INTO :l_rows FROM WRK_TRS_RELDEACT_S30_KEYED;
    RETURN :l_rows;
END;$$;
