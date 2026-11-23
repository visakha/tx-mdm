-- ============================================================================
-- sp_snow_pub_TRS_PTY_EXC_STG_BAD_REC_MEMB_BIRTH  --  BARE-BONES PUBLISH BRANCH (TRS)
--
-- Mapping: m_Tgt_C_S_TRS_Pty_OnGoing, workflow wf_TRS_Stage_Load_1_Ongoing.
-- Target: EXC_STG_BAD_REC_MEMB. Kind: EXCEPTION (Invalid birth date).
-- Consumes (v2.1 declared inputs): WRK_TRS_PTY_S3_ROUTER.
-- Keeps P_RUN_TS: Y. Original params used: none.
--
-- The INSERT below is the v2.1 branch INSERT verbatim. NO transaction
-- control and NO completion calls in this proc: the driver calls it
-- inside ONE publish transaction (all branches together, so a publish
-- either lands completely or not at all). Returns SQLROWCOUNT.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_pub_TRS_PTY_EXC_STG_BAD_REC_MEMB_BIRTH (

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
           (SRC_SYS, FIRST_NAME, MIDDLE_NAME, LAST_NAME, SUFFIX, RUN_DATE, PREFIX, EXCEPTION_CODE, EXCEPTION_TYPE,
            EXCEPTION_DESC, BIRTH_DATE, GENDER, ATTRIBUTE_NAME, MAPPING_NAME, PERIOD_START_DATE, DEATH_DT,
            ATTRIBUTE_VALUE, SRC_SYS_ID_1)
    SELECT 'TRS', std_first_name, std_mdl_name, std_lst_name, std_sfx_name, :P_RUN_TS, std_prfx_name,
           birth_exception_code, birth_exception_type, birth_exception_description, std_birth_date,
           GENDER_CD, 'Birth Date', :c_mapping, CREATE_DT, DEATH_DT, TO_VARCHAR(DOB_DT, 'MM/DD/YYYY'), pkey_src_object
      FROM WRK_TRS_PTY_S3_ROUTER
     WHERE birth_exception_code IS NOT NULL AND uq_exc_birth;
    RETURN SQLROWCOUNT;
END;
$$;
