-- ============================================================================
-- sp_snow_step_TRS_NM_S10_SRC  --  BARE-BONES STEP (TRS)
--
-- Mapping: m_Tgt_C_S_TRS_Pty_Nm, workflow wf_TRS_Stage_Load_1_Ongoing.
-- Step name: ALIAS_SRC. Produces: WRK_TRS_NM_S10_SRC.
-- Consumes (v2.1 declared inputs): (base tables only).
-- Original params used: none; plus P_RUN_TS (run timestamp).
--
-- The CTAS below is the v2.1 step SELECT verbatim. The only removals
-- were the work-table existence check and the step completion call.
-- No exception block (errors propagate to the driver handler), no
-- transactions, no target writes. Returns the row count.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_step_TRS_NM_S10_SRC (

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

    -- ---- Step 10: ALIAS_SRC (verbatim from current main)
CREATE OR REPLACE TRANSIENT TABLE WRK_TRS_NM_S10_SRC AS
    SELECT DISTINCT DC_ALIAS.INDV_ID AS INDV_ID, DC_ALIAS.PKEY_PTY AS PKEY_PTY,
           RTRIM(LTRIM(DC_ALIAS.FIRST_NAME)) AS FIRST_NAME, RTRIM(LTRIM(DC_ALIAS.MID_NAME)) AS MID_NAME,
           RTRIM(LTRIM(DC_ALIAS.LAST_NAME)) AS LAST_NAME, RTRIM(DC_ALIAS.SUFX_NAME) AS SUFX_NAME,
           RTRIM(DC_ALIAS.PREFIX_NAME) AS PREFIX_NAME, DC_ALIAS.CREATE_DT AS CREATE_DT,
           DC_ALIAS.SEQUENCE_NUM AS SEQUENCE_NUM
      FROM (SELECT INDV_ID, TO_VARCHAR(INDV_ID) AS PKEY_PTY, FIRST_NAME, MID_NAME, LAST_NAME, SUFX_NAME,
                   PREFIX_NAME, CREATE_DT, SEQUENCE_NUM
              FROM STG_TRS_D_CV_DC_MCI_ALIAS MCI_ALIAS
            UNION ALL
            SELECT INDV_ID, TO_VARCHAR(INDV_ID) || '|DC_INDV' AS PKEY_PTY, FIRST_NAME, MID_NAME, LAST_NAME,
                   SUFX_NAME, PREFIX_NAME, CREATE_DT, SEQ_NUM
              FROM STG_TRS_D_DC_ALIAS DC_ALIAS) DC_ALIAS
      JOIN STG_TRS_VALID_MEMBERS VM ON DC_ALIAS.PKEY_PTY = VM.PTY_PK;
    SELECT COUNT(*) INTO :l_rows FROM WRK_TRS_NM_S10_SRC;
    RETURN :l_rows;
END;$$;
