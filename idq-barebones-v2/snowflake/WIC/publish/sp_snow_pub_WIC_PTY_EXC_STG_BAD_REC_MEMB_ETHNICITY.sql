-- ============================================================================
-- sp_snow_pub_WIC_PTY_EXC_STG_BAD_REC_MEMB_ETHNICITY  --  BARE-BONES STEP DRIVER VARIANT (WIC)
--
-- Mapping: m_Tgt_C_S_WIC_Pty, workflow wf_WIC_Stage_Load.
-- Target: EXC_STG_BAD_REC_MEMB. Kind: EXCEPTION (invalid-ethnicity exceptions).
-- WHERE guard: grp_ethnicity AND uq_ethnicity.
-- Reads ONLY WRK_WIC_PTY_S40_ROUTED. Reads the run_ts / mapping_name columns materialised in the final step; it takes no parameters.
--
-- Bare-bones variant: stripped of config gating, job tracking and
-- input checks; the INSERT below is unchanged business SQL. No
-- transaction control in this proc: the driver calls it inside ONE
-- publish transaction covering all branches.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_pub_WIC_PTY_EXC_STG_BAD_REC_MEMB_ETHNICITY (
)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
    INSERT INTO EXC_STG_BAD_REC_MEMB
           (RUN_DATE, EXCEPTION_CODE, EXCEPTION_TYPE, EXCEPTION_DESC, ATTRIBUTE_NAME, GENDER, SRC_SYS_ID_1,
            SRC_SYS, FIRST_NAME, LAST_NAME, MIDDLE_NAME, MAPPING_NAME, BIRTH_DATE, PERIOD_START_DATE,
            SRC_SYS_ID_2, ATTRIBUTE_VALUE)
    SELECT run_ts, ethnicity_exception_code, ethnicity_exception_type, ethnicity_exception_desc,
           attr_ethnicity, GENDER, PTY_SRC_KEY, src_sys, FIRST_NAME, std_lst_name, std_mdl_name,
           mapping_name, DOB, DATEKEY, ID, ETHNICITY
      FROM WRK_WIC_PTY_S40_ROUTED
     WHERE grp_ethnicity AND uq_ethnicity;
    RETURN SQLROWCOUNT;
END;
$$;
