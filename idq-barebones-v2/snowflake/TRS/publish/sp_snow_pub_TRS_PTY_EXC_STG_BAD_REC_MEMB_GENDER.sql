-- ============================================================================
-- sp_snow_pub_TRS_PTY_EXC_STG_BAD_REC_MEMB_GENDER  --  BARE-BONES PUBLISH BRANCH (TRS)
--
-- Mapping: m_Tgt_C_S_TRS_Pty_OnGoing, workflow wf_TRS_Stage_Load_1_Ongoing.
-- Target: EXC_STG_BAD_REC_MEMB. Kind: EXCEPTION (Invalid gender code).
-- Consumes (v2.1 declared inputs): WRK_TRS_PTY_S3_ROUTER.
-- Keeps P_RUN_TS: Y. Original params used: none.
--
-- The INSERT below is the v2.1 branch INSERT verbatim. NO transaction
-- control and NO completion calls in this proc: the driver calls it
-- inside ONE publish transaction (all branches together, so a publish
-- either lands completely or not at all). Returns SQLROWCOUNT.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_pub_TRS_PTY_EXC_STG_BAD_REC_MEMB_GENDER (

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
           (GENDER, PREFIX, FIRST_NAME, MIDDLE_NAME, LAST_NAME, SUFFIX, SRC_SYS, EXCEPTION_CODE, EXCEPTION_DESC,
            EXCEPTION_TYPE, BIRTH_DATE, ATTRIBUTE_NAME, MAPPING_NAME, PERIOD_START_DATE, ATTRIBUTE_VALUE,
            DEATH_DT, RUN_DATE, SRC_SYS_ID_1)
    SELECT GENDER_CD, std_prfx_name, std_first_name, std_mdl_name, std_lst_name, std_sfx_name, 'TRS',
           gender_exception_code, gender_exception_description, gender_exception_type, std_birth_date,
           'Gender', :c_mapping, CREATE_DT, GENDER_CD, DEATH_DT, :P_RUN_TS, pkey_src_object
      FROM WRK_TRS_PTY_S3_ROUTER
     WHERE gender_exception_description IS NOT NULL AND uq_exc_gender;
    RETURN SQLROWCOUNT;
END;
$$;
