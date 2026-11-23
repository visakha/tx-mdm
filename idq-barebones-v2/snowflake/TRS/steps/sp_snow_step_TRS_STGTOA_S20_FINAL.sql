-- ============================================================================
-- sp_snow_step_TRS_STGTOA_S20_FINAL  --  BARE-BONES STEP (TRS)
--
-- Mapping: m_Tgt_C_S_TRS_Stg_TOA, workflow wf_TRS_Stage_Load_TOA.
-- Step name: SURVIVOR_PER_KEY. Produces: WRK_TRS_LUTOA_S20_FINAL.
-- Consumes (v2.1 declared inputs): WRK_TRS_LUTOA_S10_KEYED.
-- Original params used: none; plus P_RUN_TS (run timestamp).
--
-- The CTAS below is the v2.1 step SELECT verbatim. The only removals
-- were the work-table existence check and the step completion call.
-- No exception block (errors propagate to the driver handler), no
-- transactions, no target writes. Returns the row count.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_step_TRS_STGTOA_S20_FINAL (

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

    -- ---- Step 20: SURVIVOR_PER_KEY (verbatim from current main)
CREATE OR REPLACE TRANSIENT TABLE WRK_TRS_LUTOA_S20_FINAL AS
    SELECT * EXCLUDE (rn)
      FROM (
        SELECT k.*,
               ROW_NUMBER() OVER (PARTITION BY k.pkey_src_object
                                      ORDER BY k.UPDATE_DT DESC NULLS LAST, k.UNIQUE_TRANS_ID DESC NULLS LAST) AS rn
          FROM WRK_TRS_LUTOA_S10_KEYED k
          LEFT JOIN (SELECT DISTINCT PKEY_SRC_OBJECT FROM C_S_LU_TOA WHERE VERSION_SEQ = 1) xa
                 ON xa.PKEY_SRC_OBJECT = k.pkey_src_object
         WHERE k.pkey_src_object IS NOT NULL
           AND xa.PKEY_SRC_OBJECT IS NULL
      )
     WHERE rn = 1;
    SELECT COUNT(*) INTO :l_rows FROM WRK_TRS_LUTOA_S20_FINAL;
    RETURN :l_rows;
END;$$;
