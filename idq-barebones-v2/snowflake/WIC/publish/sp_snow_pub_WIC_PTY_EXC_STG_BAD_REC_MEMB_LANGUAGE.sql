-- ============================================================================
-- sp_snow_pub_WIC_PTY_EXC_STG_BAD_REC_MEMB_LANGUAGE  --  BARE-BONES STEP DRIVER VARIANT (WIC)
--
-- Mapping: m_Tgt_C_S_WIC_Pty, workflow wf_WIC_Stage_Load.
-- Target: EXC_STG_BAD_REC_MEMB. Kind: EXCEPTION (invalid-language exceptions).
-- WHERE guard: grp_language AND uq_language.
-- Reads ONLY WRK_WIC_PTY_S40_ROUTED. Reads the run_ts / mapping_name columns materialised in the final step; it takes no parameters.
--
-- Bare-bones variant: stripped of config gating, job tracking and
-- input checks; the INSERT below is unchanged business SQL. No
-- transaction control in this proc: the driver calls it inside ONE
-- publish transaction covering all branches.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_pub_WIC_PTY_EXC_STG_BAD_REC_MEMB_LANGUAGE (
)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
    INSERT INTO EXC_STG_BAD_REC_MEMB
           (SRC_SYS, SRC_SYS_ID_1, SRC_SYS_ID_2, EXCEPTION_TYPE, EXCEPTION_CODE, EXCEPTION_DESC, RUN_DATE,
            FIRST_NAME, MIDDLE_NAME, LAST_NAME, BIRTH_DATE, GENDER, ATTRIBUTE_NAME, ATTRIBUTE_VALUE,
            MAPPING_NAME, PERIOD_START_DATE)
    SELECT src_sys, PTY_SRC_KEY, ID, language_exception_type, language_exception_code,
           language_exception_desc, run_ts, FIRST_NAME, std_mdl_name, std_lst_name, std_birth_date,
           GENDER, attr_language, LANGUAGE_CD, mapping_name, DATEKEY
      FROM WRK_WIC_PTY_S40_ROUTED
     WHERE grp_language AND uq_language;
    RETURN SQLROWCOUNT;
END;
$$;
