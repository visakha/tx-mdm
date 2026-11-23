-- ============================================================================
-- sp_snow_pub_WIC_PTY_EXC_STG_BAD_REC_MEMB_BIRTH  --  BARE-BONES STEP DRIVER VARIANT (WIC)
--
-- Mapping: m_Tgt_C_S_WIC_Pty, workflow wf_WIC_Stage_Load.
-- Target: EXC_STG_BAD_REC_MEMB. Kind: EXCEPTION (invalid-birth-date exceptions).
-- WHERE guard: grp_birth AND uq_birth.
-- Reads ONLY WRK_WIC_PTY_S40_ROUTED. Reads the run_ts / mapping_name columns materialised in the final step; it takes no parameters.
--
-- Bare-bones variant: stripped of config gating, job tracking and
-- input checks; the INSERT below is unchanged business SQL. No
-- transaction control in this proc: the driver calls it inside ONE
-- publish transaction covering all branches.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_pub_WIC_PTY_EXC_STG_BAD_REC_MEMB_BIRTH (
)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
    INSERT INTO EXC_STG_BAD_REC_MEMB
           (SRC_SYS, SRC_SYS_ID_1, EXCEPTION_CODE, EXCEPTION_DESC, EXCEPTION_TYPE, RUN_DATE, MAPPING_NAME,
            GENDER, ATTRIBUTE_NAME, SRC_SYS_ID_2, PREFIX, FIRST_NAME, LAST_NAME, MIDDLE_NAME, ATTRIBUTE_VALUE,
            BIRTH_DATE)
    SELECT src_sys, PTY_SRC_KEY, birth_exception_code, birth_exception_description, birth_exception_type,
           run_ts, mapping_name, GENDER, attr_birth, ID, std_prfx_name, FIRST_NAME, LAST_NAME, MIDDLE_NAME,
           dob_text, DOB
      FROM WRK_WIC_PTY_S40_ROUTED
     WHERE grp_birth AND uq_birth;
    RETURN SQLROWCOUNT;
END;
$$;
