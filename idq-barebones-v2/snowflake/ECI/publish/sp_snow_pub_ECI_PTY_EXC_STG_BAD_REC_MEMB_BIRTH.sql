-- sp_snow_pub_ECI_PTY_EXC_STG_BAD_REC_MEMB_BIRTH -- BARE-BONES variant (ECI)
-- Mapping: m_Tgt_C_S_ECI_Pty, workflow wf_ECI_Stage_Load, publish step 90 (PUBLISH_EXC_BIRTH).
-- Target: EXC_STG_BAD_REC_MEMB. Consumes: WRK_ECI_PTY_S50_READY.
-- Called by the driver inside the single publish transaction; no gating, no checkpointing.
-- INSERT below is verbatim from the v2.1 publish procedure.
CREATE OR REPLACE PROCEDURE sp_snow_pub_ECI_PTY_EXC_STG_BAD_REC_MEMB_BIRTH ()
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
    SELECT src_system, pkey_src_object, birth_exception_code, birth_exception_description,
           birth_exception_type, run_ts, exc_mapping, GENDER, attr_birth, ID, std_prfx_name,
           FIRST_NAME, LAST_NAME, MIDDLE_INITIAL, dob_text, DOB
      FROM WRK_ECI_PTY_S50_READY
     WHERE grp_birth AND uq_birth;
    RETURN SQLROWCOUNT;
END;
$$;
