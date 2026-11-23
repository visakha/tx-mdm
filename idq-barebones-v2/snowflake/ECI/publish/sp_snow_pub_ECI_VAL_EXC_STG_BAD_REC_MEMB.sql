-- sp_snow_pub_ECI_VAL_EXC_STG_BAD_REC_MEMB -- BARE-BONES variant (ECI)
-- Mapping: m_Tgt_C_S_ECI_Pty_Validation, workflow wf_ECI_Stage_Load, publish step 40 (PUBLISH_EXC_STG_BAD_REC_MEMB).
-- Target: EXC_STG_BAD_REC_MEMB. Consumes: WRK_ECI_VAL_S30_ROUTED.
-- Called by the driver inside the single publish transaction; no gating, no checkpointing.
-- INSERT below is verbatim from the v2.1 publish procedure.
CREATE OR REPLACE PROCEDURE sp_snow_pub_ECI_VAL_EXC_STG_BAD_REC_MEMB ()
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
    -- 40a. Invalid party name -> EXC_STG_BAD_REC_MEMB (verbatim from current main)
    INSERT INTO EXC_STG_BAD_REC_MEMB
           (SRC_SYS, SRC_SYS_ID_1, EXCEPTION_CODE, EXCEPTION_DESC, EXCEPTION_TYPE, RUN_DATE,
            FIRST_NAME, MIDDLE_NAME, LAST_NAME, BIRTH_DATE, ATTRIBUTE_NAME, ATTRIBUTE_VALUE, MAPPING_NAME,
            PERIOD_START_DATE)
    SELECT src_system, pkey_src_object, exc_code_name, exc_desc_name, exc_type_name, run_ts,
           std_first_name, std_mdl_name, std_lst_name, DOB, exc_attribute_name, exc_attribute_value,
           mapping_name, DATE_CREATED
      FROM WRK_ECI_VAL_S30_ROUTED
     WHERE grp_invalid_party_name AND uq_exc_name;
    RETURN SQLROWCOUNT;
END;
$$;
