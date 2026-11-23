-- ============================================================================
-- sp_snow_step_TRS_ADDR1_S20_DERIVED  --  BARE-BONES STEP (TRS)
--
-- Mapping: m_Tgt_C_S_TRS_Addr_1, workflow wf_TRS_Stage_Load_1_Ongoing.
-- Step name: DERIVED_ADDR_LINES. Produces: WRK_TRS_ADDR1_S20_DERIVED.
-- Consumes (v2.1 declared inputs): WRK_TRS_ADDR1_S10_SRC.
-- Original params used: none; plus P_RUN_TS (run timestamp).
--
-- The CTAS below is the v2.1 step SELECT verbatim. The only removals
-- were the work-table existence check and the step completion call.
-- No exception block (errors propagate to the driver handler), no
-- transactions, no target writes. Returns the row count.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_step_TRS_ADDR1_S20_DERIVED (

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

    -- ---- Step 20: DERIVED_ADDR_LINES (verbatim from current main)
CREATE OR REPLACE TRANSIENT TABLE WRK_TRS_ADDR1_S20_DERIVED AS
    SELECT s.*,
           TRIM(NVL(TO_VARCHAR(s.ADDR_ST_NUM), '') || ' ' || NVL(s.ADDR_ST_NUM_FRAC, '') || ' '
                || NVL(IFF(UPPER(s.ADDR_ST_DIR_CD) IN ('EA', 'NO', 'SO', 'WE'), SUBSTR(s.ADDR_ST_DIR_CD, 1, 1),
                           s.ADDR_ST_DIR_CD), '')
                || ' ' || NVL(s.ADDR_ST_NM, '') || ' ' || NVL(st.DESCRIPTION, ''))                AS addr_line_1,
           TRIM(NVL(s.ADDR_DWELLING_TYPE_CD, '') || ' ' || NVL(s.ADDR_APT_NUM, '') || ' '
                || NVL(s.ADDR_LINE, ''))                                                         AS addr_line_2
      FROM WRK_TRS_ADDR1_S10_SRC s
      LEFT JOIN (SELECT r.CODE, r.DESCRIPTION FROM STG_TRS_CD_REF r
                 QUALIFY ROW_NUMBER() OVER (PARTITION BY r.CODE ORDER BY r.DESCRIPTION) = 1) st
             ON st.CODE = s.ADDR_ST_TYPE_CD;
    SELECT COUNT(*) INTO :l_rows FROM WRK_TRS_ADDR1_S20_DERIVED;
    RETURN :l_rows;
END;$$;
