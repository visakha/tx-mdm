-- ============================================================================
-- sp_snow_pub_WIC_VAL_EXC_STG_BAD_REC_MEMB  --  BARE-BONES STEP DRIVER VARIANT (WIC)
--
-- Mapping: m_Tgt_C_S_WIC_Pty_Validation, workflow wf_WIC_Stage_Load.
-- Target: EXC_STG_BAD_REC_MEMB. Kind: EXCEPTION (invalid-name exceptions).
-- WHERE guard: name_missing AND uq_exc_name.
-- Reads ONLY WRK_WIC_VAL_S30_ROUTED. Reads the run_ts / mapping_name columns materialised in the final step; it takes no parameters.
--
-- Bare-bones variant: stripped of config gating, job tracking and
-- input checks; the INSERT below is unchanged business SQL. No
-- transaction control in this proc: the driver calls it inside ONE
-- publish transaction covering all branches.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_pub_WIC_VAL_EXC_STG_BAD_REC_MEMB (
)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
    INSERT INTO EXC_STG_BAD_REC_MEMB
           (PERIOD_START_DATE, MAPPING_NAME, ATTRIBUTE_NAME, ATTRIBUTE_VALUE, FIRST_NAME, MIDDLE_NAME,
            LAST_NAME, RUN_DATE, SRC_SYS, SRC_SYS_ID_1, EXCEPTION_DESC, EXCEPTION_TYPE, EXCEPTION_CODE,
            BIRTH_DATE)
    SELECT DATEKEY, mapping_name, exc_attribute_name, exc_attribute_value, std_first_name, std_mdl_name,
           std_lst_name, run_ts, src_sys, PTY_SRC_KEY, exc_desc_name, exc_type_name, exc_code_name, DOB
      FROM WRK_WIC_VAL_S30_ROUTED
     WHERE name_missing AND uq_exc_name;
    RETURN SQLROWCOUNT;
END;
$$;
