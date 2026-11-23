-- ============================================================================
-- sp_snow_pub_TRS_PTY_EXC_STG_BAD_REC_MEMB_ETHNICITY  --  BARE-BONES PUBLISH BRANCH (TRS)
--
-- Mapping: m_Tgt_C_S_TRS_Pty_OnGoing, workflow wf_TRS_Stage_Load_1_Ongoing.
-- Target: EXC_STG_BAD_REC_MEMB. Kind: EXCEPTION (Ethnicity exceptions).
-- Consumes (v2.1 declared inputs): WRK_TRS_PTY_S4_DEDUP.
-- Keeps P_RUN_TS: Y. Original params used: none.
--
-- The INSERT below is the v2.1 branch INSERT verbatim. NO transaction
-- control and NO completion calls in this proc: the driver calls it
-- inside ONE publish transaction (all branches together, so a publish
-- either lands completely or not at all). Returns SQLROWCOUNT.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_pub_TRS_PTY_EXC_STG_BAD_REC_MEMB_ETHNICITY (

    P_RUN_TS       TIMESTAMP_NTZ DEFAULT NULL

)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    c_mapping VARCHAR DEFAULT 'm_Tgt_C_S_TRS_Pty_OnGoing';
BEGIN
INSERT INTO EXC_STG_BAD_REC_MEMB
           (SRC_SYS, SRC_SYS_ID_1, ATTRIBUTE_NAME, ATTRIBUTE_VALUE, PERIOD_START_DATE, DEATH_DT, EXCEPTION_CODE,
            EXCEPTION_DESC, EXCEPTION_TYPE, RUN_DATE, PREFIX, LAST_NAME, MIDDLE_NAME, FIRST_NAME, SUFFIX, GENDER,
            MAPPING_NAME)
    SELECT 'TRS', pkey_trim, 'Ethnicity_Cd', ethnicity_mstr, CREATE_DT, DEATH_DT, ethnicity_exception_code,
           ethnicity_exception_desc, ethnicity_exception_type, :P_RUN_TS, std_prfx_name, std_lst_name,
           std_mdl_name, std_first_name, std_sfx_name, mdm_gender_code, :c_mapping
      FROM WRK_TRS_PTY_S4_DEDUP
     WHERE ethnicity_exception_code IS NOT NULL AND uq_exc_ethnicity;
    RETURN SQLROWCOUNT;
END;
$$;
