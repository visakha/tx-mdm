-- ============================================================================
-- sp_snow_step_TRS_STGTOA_S10_KEYED  --  BARE-BONES STEP (TRS)
--
-- Mapping: m_Tgt_C_S_TRS_Stg_TOA, workflow wf_TRS_Stage_Load_TOA.
-- Step name: CATALOGUE_KEYED. Produces: WRK_TRS_LUTOA_S10_KEYED.
-- Consumes (v2.1 declared inputs): (base tables only).
-- Original params used: none; plus P_RUN_TS (run timestamp).
--
-- The CTAS below is the v2.1 step SELECT verbatim. The only removals
-- were the work-table existence check and the step completion call.
-- No exception block (errors propagate to the driver handler), no
-- transactions, no target writes. Returns the row count.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_step_TRS_STGTOA_S10_KEYED (

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

    -- ---- Step 10: CATALOGUE_KEYED (verbatim from current main)
CREATE OR REPLACE TRANSIENT TABLE WRK_TRS_LUTOA_S10_KEYED AS
    WITH
    lkp_toa AS (
        SELECT l.MSTR_REF_LABEL, l.MSTR_REF_CODE FROM LOOKUP_CODE_VALUE l
         WHERE l.CODE_TYPE = 'TOA'
        QUALIFY ROW_NUMBER() OVER (PARTITION BY l.MSTR_REF_LABEL ORDER BY l.MSTR_REF_CODE) = 1
    ),
    lkp_pgm AS (
        SELECT l.MSTR_REF_LABEL, l.MSTR_REF_CODE FROM LOOKUP_CODE_VALUE l
         WHERE l.CODE_TYPE = 'MEMBER_PRG'
        QUALIFY ROW_NUMBER() OVER (PARTITION BY l.MSTR_REF_LABEL ORDER BY l.MSTR_REF_CODE) = 1
    )
    SELECT s.*,
           SUBSTR(lt.MSTR_REF_CODE, 1, 10) AS pkey_src_object,
           lt.MSTR_REF_LABEL AS toa_lbl,
           SUBSTR(lp.MSTR_REF_CODE, 1, 9) AS mbr_prg_cd
      FROM STG_TRS_D_LU_TOA s
      LEFT JOIN lkp_toa lt ON lt.MSTR_REF_LABEL = s.TOA_CODE
      LEFT JOIN lkp_pgm lp ON lp.MSTR_REF_LABEL = s.PROGRAM_CODE;
    SELECT COUNT(*) INTO :l_rows FROM WRK_TRS_LUTOA_S10_KEYED;
    RETURN :l_rows;
END;$$;
