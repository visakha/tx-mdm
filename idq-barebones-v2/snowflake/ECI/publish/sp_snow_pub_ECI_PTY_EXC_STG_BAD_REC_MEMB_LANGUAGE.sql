-- sp_snow_pub_ECI_PTY_EXC_STG_BAD_REC_MEMB_LANGUAGE -- BARE-BONES variant (ECI)
-- Mapping: m_Tgt_C_S_ECI_Pty, workflow wf_ECI_Stage_Load, publish step 120 (PUBLISH_EXC_LANGUAGE).
-- Target: EXC_STG_BAD_REC_MEMB. Consumes: WRK_ECI_PTY_S50_READY.
-- Called by the driver inside the single publish transaction; no gating, no checkpointing.
-- INSERT below is verbatim from the v2.1 publish procedure.
CREATE OR REPLACE PROCEDURE sp_snow_pub_ECI_PTY_EXC_STG_BAD_REC_MEMB_LANGUAGE ()
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
    SELECT src_system, pkey_src_object, ID, language_exception_type, language_exception_code,
           language_exception_desc, run_ts, FIRST_NAME, std_mdl_name, std_lst_name, std_birth_date,
           GENDER, attr_language, LANGUAGE_CD, exc_mapping, DATE_CREATED
      FROM WRK_ECI_PTY_S50_READY
     WHERE grp_language AND uq_language;
    RETURN SQLROWCOUNT;
END;
$$;
