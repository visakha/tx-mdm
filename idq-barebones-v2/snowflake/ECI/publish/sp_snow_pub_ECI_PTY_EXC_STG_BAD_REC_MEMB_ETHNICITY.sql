-- sp_snow_pub_ECI_PTY_EXC_STG_BAD_REC_MEMB_ETHNICITY -- BARE-BONES variant (ECI)
-- Mapping: m_Tgt_C_S_ECI_Pty, workflow wf_ECI_Stage_Load, publish step 100 (PUBLISH_EXC_ETHNICITY).
-- Target: EXC_STG_BAD_REC_MEMB. Consumes: WRK_ECI_PTY_S50_READY.
-- Called by the driver inside the single publish transaction; no gating, no checkpointing.
-- INSERT below is verbatim from the v2.1 publish procedure.
CREATE OR REPLACE PROCEDURE sp_snow_pub_ECI_PTY_EXC_STG_BAD_REC_MEMB_ETHNICITY ()
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
           attr_ethnicity, GENDER, pkey_src_object, src_system, FIRST_NAME, std_lst_name, std_mdl_name,
           exc_mapping, DOB, DATE_CREATED, ID, ETHNICITY
      FROM WRK_ECI_PTY_S50_READY
     WHERE grp_ethnicity AND uq_ethnicity;
    RETURN SQLROWCOUNT;
END;
$$;
