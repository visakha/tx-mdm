-- ============================================================================
-- sp_snow_step_TRS_ADDR2_S30_KEYED  --  BARE-BONES STEP (TRS)
--
-- Mapping: m_Tgt_C_S_TRS_Addr_2, workflow wf_TRS_Stage_Load_1_Ongoing.
-- Step name: KEYED_ADDR. Produces: WRK_TRS_ADDR2_S30_KEYED.
-- Consumes (v2.1 declared inputs): WRK_TRS_ADDR2_S20_SRC.
-- Original params used: P_MEMBER_ROLE_TYPE; plus P_RUN_TS (run timestamp).
--
-- The CTAS below is the v2.1 step SELECT verbatim. The only removals
-- were the work-table existence check and the step completion call.
-- No exception block (errors propagate to the driver handler), no
-- transactions, no target writes. Returns the row count.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_step_TRS_ADDR2_S30_KEYED (

    P_MEMBER_ROLE_TYPE VARCHAR DEFAULT 'Member',
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

    -- ---- Step 30: KEYED_ADDR (verbatim from current main)
CREATE OR REPLACE TRANSIENT TABLE WRK_TRS_ADDR2_S30_KEYED AS
    WITH
    lkp_cv AS (SELECT * FROM TABLE(fn_snow_helper41_common()))
    SELECT s.*,
           at.MSTR_CODE_VALUE                                                                    AS mstr_addr_tp,
           NVL(s.PSTL_CD, '') || IFF(s.PSTL_CD_EXT IS NOT NULL, '-' || s.PSTL_CD_EXT, '')         AS rslt_pstl_cd,
           NVL(s.PTY_PK, '') || '|' || :P_MEMBER_ROLE_TYPE || '|' || NVL(at.MSTR_CODE_VALUE, '') || '|'
           || NVL(TO_VARCHAR(s.CASE_NUM), '') || '|' || NVL(TO_VARCHAR(s.EDG_NUM), '') || '|'
           || NVL(TO_VARCHAR(s.EFF_BEGIN_DT, 'YYYYMMDD'), '')                                    AS pkey_pty_rle_addr,
           fn_snow_helper21_common(s.EFF_END_DT, :P_RUN_TS)                                       AS end_date_50y
      FROM WRK_TRS_ADDR2_S20_SRC s
      LEFT JOIN lkp_cv at ON at.CODE_TYPE = 'ADDR_TP' AND at.SRC_SYS = 'TRS' AND at.SRC_CODE_VALUE = s.ADDR_TYPE_CD;
    SELECT COUNT(*) INTO :l_rows FROM WRK_TRS_ADDR2_S30_KEYED;
    RETURN :l_rows;
END;$$;
