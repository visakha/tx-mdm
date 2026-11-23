-- sp_snow_pub_ECI_PTY_EXC_STG_BAD_REC_MEMB_GENDER -- BARE-BONES variant (ECI)
-- Mapping: m_Tgt_C_S_ECI_Pty, workflow wf_ECI_Stage_Load, publish step 80 (PUBLISH_EXC_GENDER).
-- Target: EXC_STG_BAD_REC_MEMB. Consumes: WRK_ECI_PTY_S50_READY.
-- Called by the driver inside the single publish transaction; no gating, no checkpointing.
-- INSERT below is verbatim from the v2.1 publish procedure.
CREATE OR REPLACE PROCEDURE sp_snow_pub_ECI_PTY_EXC_STG_BAD_REC_MEMB_GENDER ()
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
    INSERT INTO EXC_STG_BAD_REC_MEMB
           (SRC_SYS, EXCEPTION_TYPE, EXCEPTION_CODE, EXCEPTION_DESC, ATTRIBUTE_NAME, ATTRIBUTE_VALUE,
            MAPPING_NAME, SRC_SYS_ID_1, SRC_SYS_ID_2, GENDER, BIRTH_DATE, RUN_DATE)
    SELECT src_system, gender_exception_type, gender_exception_code, gender_exception_description,
           attr_gender, GENDER, exc_mapping, pkey_src_object, ID, GENDER, DOB, run_ts
      FROM WRK_ECI_PTY_S50_READY
     WHERE grp_gender AND uq_gender;
    RETURN SQLROWCOUNT;
END;
$$;
