-- ============================================================================
-- sp_snow_step_TRS_AUTHREP_S30_KEYED  --  BARE-BONES STEP (TRS)
--
-- Mapping: m_Tgt_C_S_TRS_Pty_Mng_Attr_Auth_Rep_Ongoing, workflow wf_TRS_Stage_Load_1_Ongoing.
-- Step name: KEYED. Produces: WRK_TRS_MNGAR_S30_KEYED.
-- Consumes (v2.1 declared inputs): WRK_TRS_MNGAR_S20_SRC.
-- Original params used: P_ATTR_TP_AUTH_REP; plus P_RUN_TS (run timestamp).
--
-- The CTAS below is the v2.1 step SELECT verbatim. The only removals
-- were the work-table existence check and the step completion call.
-- No exception block (errors propagate to the driver handler), no
-- transactions, no target writes. Returns the row count.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_step_TRS_AUTHREP_S30_KEYED (

    P_ATTR_TP_AUTH_REP VARCHAR DEFAULT 'Auth_Rep_Flag',
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

    -- ---- Step 30: KEYED (verbatim from current main)
CREATE OR REPLACE TRANSIENT TABLE WRK_TRS_MNGAR_S30_KEYED AS
    SELECT DISTINCT s.INDV_ID, s.AR_FLAG, s.EFF_BEGIN_DT, s.EFF_END_DT, s.CREATE_DT,
           TO_VARCHAR(s.INDV_ID) || '|' || :P_ATTR_TP_AUTH_REP AS pkey_src_object,
           TO_VARCHAR(s.INDV_ID) AS pty_pk
      FROM WRK_TRS_MNGAR_S20_SRC s;
    SELECT COUNT(*) INTO :l_rows FROM WRK_TRS_MNGAR_S30_KEYED;
    RETURN :l_rows;
END;$$;
