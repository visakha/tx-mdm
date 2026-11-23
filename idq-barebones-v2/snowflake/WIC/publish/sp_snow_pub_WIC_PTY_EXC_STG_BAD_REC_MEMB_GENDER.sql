-- ============================================================================
-- sp_snow_pub_WIC_PTY_EXC_STG_BAD_REC_MEMB_GENDER  --  BARE-BONES STEP DRIVER VARIANT (WIC)
--
-- Mapping: m_Tgt_C_S_WIC_Pty, workflow wf_WIC_Stage_Load.
-- Target: EXC_STG_BAD_REC_MEMB. Kind: EXCEPTION (invalid-gender exceptions).
-- WHERE guard: grp_gender AND uq_gender.
-- Reads ONLY WRK_WIC_PTY_S40_ROUTED. Reads the run_ts / mapping_name columns materialised in the final step; it takes no parameters.
--
-- Bare-bones variant: stripped of config gating, job tracking and
-- input checks; the INSERT below is unchanged business SQL. No
-- transaction control in this proc: the driver calls it inside ONE
-- publish transaction covering all branches.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_pub_WIC_PTY_EXC_STG_BAD_REC_MEMB_GENDER (
)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
    INSERT INTO EXC_STG_BAD_REC_MEMB
           (SRC_SYS, EXCEPTION_TYPE, EXCEPTION_CODE, EXCEPTION_DESC, ATTRIBUTE_NAME, ATTRIBUTE_VALUE,
            MAPPING_NAME, SRC_SYS_ID_1, SRC_SYS_ID_2, GENDER, BIRTH_DATE, RUN_DATE, FIRST_NAME, MIDDLE_NAME,
            LAST_NAME)
    SELECT src_sys, gender_exception_type, gender_exception_code, gender_exception_description, attr_gender,
           GENDER, mapping_name, PTY_SRC_KEY, ID, GENDER, DOB, run_ts, FIRST_NAME, MIDDLE_NAME, LAST_NAME
      FROM WRK_WIC_PTY_S40_ROUTED
     WHERE grp_gender AND uq_gender;
    RETURN SQLROWCOUNT;
END;
$$;
