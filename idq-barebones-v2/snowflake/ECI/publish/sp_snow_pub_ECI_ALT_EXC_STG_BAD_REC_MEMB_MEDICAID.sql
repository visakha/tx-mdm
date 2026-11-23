-- sp_snow_pub_ECI_ALT_EXC_STG_BAD_REC_MEMB_MEDICAID -- BARE-BONES variant (ECI)
-- Mapping: m_Tgt_C_S_ECI_Pty_Rle_Alt_Id, workflow wf_ECI_Stage_Load, publish step 70 (PUBLISH_EXC_STG_BAD_REC_MEMB_MEDICAID).
-- Target: EXC_STG_BAD_REC_MEMB. Consumes: WRK_ECI_ALT_S40_READY.
-- Called by the driver inside the single publish transaction; no gating, no checkpointing.
-- INSERT below is verbatim from the v2.1 publish procedure.
CREATE OR REPLACE PROCEDURE sp_snow_pub_ECI_ALT_EXC_STG_BAD_REC_MEMB_MEDICAID ()
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    l_rows       NUMBER DEFAULT 0;
BEGIN
    -- ---- Publish branch 50c: invalid Medicaid id -> EXC_STG_BAD_REC_MEMB (NON-SPINE, verbatim)
    INSERT INTO EXC_STG_BAD_REC_MEMB
           (SRC_SYS, RUN_DATE, EXCEPTION_TYPE, EXCEPTION_CODE, EXCEPTION_DESC, MAPPING_NAME, ATTRIBUTE_VALUE,
            ATTRIBUTE_NAME, SRC_SYS_ID_2, SRC_SYS_ID_1)
    SELECT src_sys, run_ts, medicaid_exception_type, medicaid_exception_code, medicaid_exception_desc,
           mapping_name, ALT_ID_VAL, attr_medicaid, PTY_REL_FK, PKEY_SRC_OBJECT
      FROM WRK_ECI_ALT_S40_READY
     WHERE grp_mcd_exc AND uq_mcd_exc;
    l_rows := SQLROWCOUNT;
    RETURN :l_rows;
END;
$$;
