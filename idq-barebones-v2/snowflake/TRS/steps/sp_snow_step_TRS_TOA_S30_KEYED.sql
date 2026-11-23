-- ============================================================================
-- sp_snow_step_TRS_TOA_S30_KEYED  --  BARE-BONES STEP (TRS)
--
-- Mapping: m_Tgt_C_S_TRS_Pty_Rle_TOA, workflow wf_TRS_Stage_Load_1_Ongoing.
-- Step name: TOA_KEYED. Produces: WRK_TRS_TOA_S30_KEYED.
-- Consumes (v2.1 declared inputs): WRK_TRS_TOA_S20_SRC.
-- Original params used: none; plus P_RUN_TS (run timestamp).
--
-- The CTAS below is the v2.1 step SELECT verbatim. The only removals
-- were the work-table existence check and the step completion call.
-- No exception block (errors propagate to the driver handler), no
-- transactions, no target writes. Returns the row count.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_step_TRS_TOA_S30_KEYED (

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

    -- ---- Step 30: TOA_KEYED (verbatim from current main)
CREATE OR REPLACE TRANSIENT TABLE WRK_TRS_TOA_S30_KEYED AS
    SELECT s.*,
           lk.MSTR_REF_CODE AS toa_cd,
           DECODE(s.SRC_TBL, 'LTSS_ELIG_PER', 'DADS', 'MCI_EDG_INDV', 'TIERS') AS toa_source,
           NVL(TO_VARCHAR(s.EDG_NUM), '') || '|' || NVL(TO_VARCHAR(s.PROGRAM_CD), '') || '|'
           || NVL(TO_VARCHAR(s.MCI_CREATE_SEQ), '') AS sgmnt_key,
           s.INDV_ID || '|Member' AS pty_rle_fk,
           s.INDV_ID || '|Member|' || NVL(lk.MSTR_REF_CODE, '') || '|'
           || NVL(DECODE(s.SRC_TBL, 'LTSS_ELIG_PER', 'DADS', 'MCI_EDG_INDV', 'TIERS'), '') || '|'
           || NVL(TO_VARCHAR(s.EDG_NUM), '') || '|' || NVL(TO_VARCHAR(s.PROGRAM_CD), '') || '|'
           || NVL(TO_VARCHAR(s.MCI_CREATE_SEQ), '') AS pkey_src_object,
           lk.MSTR_REF_CODE IS NULL AS grp_bad_value,
           NVL(s.BEGIN_DT > s.END_DT, FALSE) AS grp_dates
      FROM WRK_TRS_TOA_S20_SRC s
      LEFT JOIN (SELECT l.SRC_CODE_VALUE, l.MSTR_REF_CODE FROM LOOKUP_CODE_VALUE l
                  WHERE l.CODE_TYPE = 'TOA' AND l.SRC_SYS = 'TRS'
                QUALIFY ROW_NUMBER() OVER (PARTITION BY l.SRC_CODE_VALUE ORDER BY l.MSTR_REF_CODE) = 1) lk
             ON lk.SRC_CODE_VALUE = s.TYPE_OF_ASSISTANCE_CD;
    SELECT COUNT(*) INTO :l_rows FROM WRK_TRS_TOA_S30_KEYED;
    RETURN :l_rows;
END;$$;
