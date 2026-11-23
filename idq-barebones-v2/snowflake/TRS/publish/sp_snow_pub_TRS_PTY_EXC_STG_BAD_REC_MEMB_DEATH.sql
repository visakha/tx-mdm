-- ============================================================================
-- sp_snow_pub_TRS_PTY_EXC_STG_BAD_REC_MEMB_DEATH  --  BARE-BONES PUBLISH BRANCH (TRS)
--
-- Mapping: m_Tgt_C_S_TRS_Pty_OnGoing, workflow wf_TRS_Stage_Load_1_Ongoing.
-- Target: EXC_STG_BAD_REC_MEMB. Kind: EXCEPTION (Invalid death date).
-- Consumes (v2.1 declared inputs): WRK_TRS_PTY_S3_ROUTER.
-- Keeps P_RUN_TS: Y. Original params used: none.
--
-- The INSERT below is the v2.1 branch INSERT verbatim. NO transaction
-- control and NO completion calls in this proc: the driver calls it
-- inside ONE publish transaction (all branches together, so a publish
-- either lands completely or not at all). Returns SQLROWCOUNT.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_pub_TRS_PTY_EXC_STG_BAD_REC_MEMB_DEATH (

    P_RUN_TS       TIMESTAMP_NTZ DEFAULT NULL

)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
INSERT INTO EXC_STG_BAD_REC_MEMB
           (SRC_SYS, PREFIX, FIRST_NAME, MIDDLE_NAME, LAST_NAME, SUFFIX, GENDER, BIRTH_DATE, EXCEPTION_CODE,
            EXCEPTION_DESC, EXCEPTION_TYPE, DEATH_DT, ATTRIBUTE_VALUE, ATTRIBUTE_NAME, PERIOD_START_DATE,
            RUN_DATE, SRC_SYS_ID_1)
    SELECT 'TRS', std_prfx_name, std_first_name, std_mdl_name, std_lst_name, std_sfx_name, GENDER_CD,
           std_birth_date, death_exception_lkp_code, death_exception_desc, death_exception_type, DEATH_DT,
           TO_VARCHAR(DEATH_DT, 'MM/DD/YYYY HH24:MI:SS'), 'Death Date', CREATE_DT, :P_RUN_TS, pkey_src_object
      FROM WRK_TRS_PTY_S3_ROUTER
     WHERE death_exception_desc IS NOT NULL AND uq_exc_death;
    RETURN SQLROWCOUNT;
END;
$$;
