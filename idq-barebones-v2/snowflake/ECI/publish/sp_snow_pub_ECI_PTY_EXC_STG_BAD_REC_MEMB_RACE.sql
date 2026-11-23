-- sp_snow_pub_ECI_PTY_EXC_STG_BAD_REC_MEMB_RACE -- BARE-BONES variant (ECI)
-- Mapping: m_Tgt_C_S_ECI_Pty, workflow wf_ECI_Stage_Load, publish step 110 (PUBLISH_EXC_RACE).
-- Target: EXC_STG_BAD_REC_MEMB. Consumes: WRK_ECI_PTY_S50_READY.
-- Called by the driver inside the single publish transaction; no gating, no checkpointing.
-- INSERT below is verbatim from the v2.1 publish procedure.
CREATE OR REPLACE PROCEDURE sp_snow_pub_ECI_PTY_EXC_STG_BAD_REC_MEMB_RACE ()
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
    INSERT INTO EXC_STG_BAD_REC_MEMB
           (SRC_SYS_ID_2, SRC_SYS_ID_1, SRC_SYS, EXCEPTION_CODE, EXCEPTION_DESC, EXCEPTION_TYPE, RUN_DATE,
            FIRST_NAME, MIDDLE_NAME, LAST_NAME, GENDER, BIRTH_DATE, ATTRIBUTE_NAME, PREFIX, PERIOD_START_DATE,
            MAPPING_NAME, ATTRIBUTE_VALUE)
    SELECT ID, pkey_src_object, src_system, race_exception_cd, race_exception_desc, race_exception_type,
           run_ts, FIRST_NAME, std_mdl_name, std_lst_name, GENDER, DOB, attr_race, std_prfx_name,
           DATE_CREATED, exc_mapping, src_race_ind_list
      FROM WRK_ECI_PTY_S50_READY
     WHERE grp_race AND uq_race;
    RETURN SQLROWCOUNT;
END;
$$;
