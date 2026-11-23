-- ============================================================================
-- sp_snow_step_TRS_NM_S40_DEDUP  --  BARE-BONES STEP (TRS)
--
-- Mapping: m_Tgt_C_S_TRS_Pty_Nm, workflow wf_TRS_Stage_Load_1_Ongoing.
-- Step name: DEDUP_KEYED. Produces: WRK_TRS_NM_S40_DEDUP.
-- Consumes (v2.1 declared inputs): WRK_TRS_NM_S30_STD.
-- Original params used: P_MEMBER_NAME_TYPE_CODE; plus P_RUN_TS (run timestamp).
--
-- The CTAS below is the v2.1 step SELECT verbatim. The only removals
-- were the work-table existence check and the step completion call.
-- No exception block (errors propagate to the driver handler), no
-- transactions, no target writes. Returns the row count.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_step_TRS_NM_S40_DEDUP (

    P_MEMBER_NAME_TYPE_CODE VARCHAR DEFAULT '002',
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

    -- ---- Step 40: DEDUP_KEYED (verbatim from current main)
CREATE OR REPLACE TRANSIENT TABLE WRK_TRS_NM_S40_DEDUP AS
    SELECT DISTINCT s.PKEY_PTY, s.CREATE_DT, s.nm:sfx_name::VARCHAR AS sfx_nm,
           s.nm:first_name::VARCHAR AS frst_nm, s.nm:prfx_name::VARCHAR AS prfx_nm,
           s.nm:last_name::VARCHAR AS lst_nm, s.nm:middle_name::VARCHAR AS mdl_nm,
           s.nm:full_name::VARCHAR AS full_nm, s.src_full_name, s.SEQUENCE_NUM,
           NVL(s.PKEY_PTY, '') || '|' || :P_MEMBER_NAME_TYPE_CODE || '|' || NVL(TO_VARCHAR(s.SEQUENCE_NUM), '')
                                                                                        AS pkey_src_object
      FROM WRK_TRS_NM_S30_STD s;
    SELECT COUNT(*) INTO :l_rows FROM WRK_TRS_NM_S40_DEDUP;
    RETURN :l_rows;
END;$$;
