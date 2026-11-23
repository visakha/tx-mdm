-- sp_snow_pub_ECI_REL_EXC_STG_BAD_REC_MEMB -- BARE-BONES variant (ECI)
-- Mapping: m_Tgt_C_S_ECI_Pty_Rle_Rel, workflow wf_ECI_Stage_Load, publish step 60 (PUBLISH_EXC_STG_BAD_REC_MEMB).
-- Target: EXC_STG_BAD_REC_MEMB. Consumes: WRK_ECI_REL_S40_READY.
-- Called by the driver inside the single publish transaction; no gating, no checkpointing.
-- INSERT below is verbatim from the v2.1 publish procedure.
CREATE OR REPLACE PROCEDURE sp_snow_pub_ECI_REL_EXC_STG_BAD_REC_MEMB ()
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
    -- 50b. Relationship exceptions -> EXC_STG_BAD_REC_MEMB (verbatim from the main)
    INSERT INTO EXC_STG_BAD_REC_MEMB
           (SRC_SYS, SRC_SYS_ID_1, SRC_SYS_ID_2, SRC_SYS_ID_3, RUN_DATE, MAPPING_NAME, ATTRIBUTE_NAME,
            PERIOD_START_DATE, EXCEPTION_TYPE, EXCEPTION_CODE, EXCEPTION_DESC, ATTRIBUTE_VALUE)
    SELECT src_sys, ID_FAMILY, ID_CHILD, rel_src_key, run_ts, mapping_name, attr_family_cd, DATE_CREATED,
           exc_type, exc_code, exc_desc, rel_family_cd
      FROM WRK_ECI_REL_S40_READY
     WHERE mstr_ref_code IS NULL AND uq_rel_exc;
    RETURN SQLROWCOUNT;
END;
$$;
