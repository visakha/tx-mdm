-- ============================================================================
-- sp_snow_pub_TRS_PTY_EXC_STG_BAD_REC_MEMB_NAME  --  BARE-BONES PUBLISH BRANCH (TRS)
--
-- Mapping: m_Tgt_C_S_TRS_Pty_OnGoing, workflow wf_TRS_Stage_Load_1_Ongoing.
-- Target: EXC_STG_BAD_REC_MEMB. Kind: EXCEPTION (Invalid party name).
-- Consumes (v2.1 declared inputs): WRK_TRS_PTY_S3_ROUTER.
-- Keeps P_RUN_TS: Y. Original params used: none.
--
-- The INSERT below is the v2.1 branch INSERT verbatim. NO transaction
-- control and NO completion calls in this proc: the driver calls it
-- inside ONE publish transaction (all branches together, so a publish
-- either lands completely or not at all). Returns SQLROWCOUNT.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_pub_TRS_PTY_EXC_STG_BAD_REC_MEMB_NAME (

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
           (PERIOD_START_DATE, SRC_SYS, DEATH_DT, MAPPING_NAME, MIDDLE_NAME, LAST_NAME, FIRST_NAME,
            ATTRIBUTE_NAME, ATTRIBUTE_VALUE, RUN_DATE, EXCEPTION_CODE, SRC_SYS_ID_1, EXCEPTION_TYPE,
            EXCEPTION_DESC)
    SELECT CREATE_DT, 'TRS', DEATH_DT, :c_mapping, std_mdl_name, std_lst_name, std_first_name,
           name_attribute_name, name_attribute_value, :P_RUN_TS, name_exception_code, pkey_src_object,
           name_exception_type, name_exception_desc
      FROM WRK_TRS_PTY_S3_ROUTER
     WHERE name_missing AND uq_exc_name;
    RETURN SQLROWCOUNT;
END;
$$;
