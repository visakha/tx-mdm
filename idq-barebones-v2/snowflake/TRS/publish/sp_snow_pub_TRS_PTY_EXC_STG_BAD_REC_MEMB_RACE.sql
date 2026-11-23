-- ============================================================================
-- sp_snow_pub_TRS_PTY_EXC_STG_BAD_REC_MEMB_RACE  --  BARE-BONES PUBLISH BRANCH (TRS)
--
-- Mapping: m_Tgt_C_S_TRS_Pty_OnGoing, workflow wf_TRS_Stage_Load_1_Ongoing.
-- Target: EXC_STG_BAD_REC_MEMB. Kind: EXCEPTION (Race exceptions).
-- Consumes (v2.1 declared inputs): WRK_TRS_PTY_S4_DEDUP.
-- Keeps P_RUN_TS: Y. Original params used: none.
--
-- The INSERT below is the v2.1 branch INSERT verbatim. NO transaction
-- control and NO completion calls in this proc: the driver calls it
-- inside ONE publish transaction (all branches together, so a publish
-- either lands completely or not at all). Returns SQLROWCOUNT.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_pub_TRS_PTY_EXC_STG_BAD_REC_MEMB_RACE (

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
           (SRC_SYS, SRC_SYS_ID_1, EXCEPTION_TYPE, EXCEPTION_DESC, EXCEPTION_CODE, ATTRIBUTE_NAME,
            ATTRIBUTE_VALUE, DEATH_DT, GENDER, BIRTH_DATE, MIDDLE_NAME, LAST_NAME, PREFIX, FIRST_NAME, SUFFIX,
            PERIOD_START_DATE, RUN_DATE, MAPPING_NAME)
    SELECT 'TRS', pkey_trim, race_exception_type, race_exception_desc, race_exception_code, 'Race_Cd',
           race_mstr, DEATH_DT, mdm_gender_code, std_birth_date, std_mdl_name, std_lst_name, std_prfx_name,
           std_first_name, std_sfx_name, CREATE_DT, :P_RUN_TS, :c_mapping
      FROM WRK_TRS_PTY_S4_DEDUP
     WHERE race_exception_code IS NOT NULL AND uq_exc_race;
    RETURN SQLROWCOUNT;
END;
$$;
