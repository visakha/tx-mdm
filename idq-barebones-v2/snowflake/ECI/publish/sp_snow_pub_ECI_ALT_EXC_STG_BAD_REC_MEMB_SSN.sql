-- sp_snow_pub_ECI_ALT_EXC_STG_BAD_REC_MEMB_SSN -- BARE-BONES variant (ECI)
-- Mapping: m_Tgt_C_S_ECI_Pty_Rle_Alt_Id, workflow wf_ECI_Stage_Load, publish step 60 (PUBLISH_EXC_STG_BAD_REC_MEMB_SSN).
-- Target: EXC_STG_BAD_REC_MEMB. Consumes: WRK_ECI_ALT_S40_READY.
-- Called by the driver inside the single publish transaction; no gating, no checkpointing.
-- INSERT below is verbatim from the v2.1 publish procedure.
CREATE OR REPLACE PROCEDURE sp_snow_pub_ECI_ALT_EXC_STG_BAD_REC_MEMB_SSN ()
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    l_rows       NUMBER DEFAULT 0;
BEGIN
    -- ---- Publish branch 50b: invalid SSN -> EXC_STG_BAD_REC_MEMB (NON-SPINE, verbatim)
    INSERT INTO EXC_STG_BAD_REC_MEMB
           (EXCEPTION_CODE, EXCEPTION_DESC, EXCEPTION_TYPE, SRC_SYS, ATTRIBUTE_NAME, MAPPING_NAME,
            ATTRIBUTE_VALUE, SRC_SYS_ID_1, SRC_SYS_ID_2)
    SELECT ssn_lkp_code, ssn_lkp_desc, ssn_lkp_type, src_sys, attr_ssn, mapping_name, ALT_ID_VAL,
           PKEY_SRC_OBJECT, PTY_REL_FK
      FROM WRK_ECI_ALT_S40_READY
     WHERE grp_ssn_exc AND uq_ssn_exc;
    l_rows := SQLROWCOUNT;
    RETURN :l_rows;
END;
$$;
