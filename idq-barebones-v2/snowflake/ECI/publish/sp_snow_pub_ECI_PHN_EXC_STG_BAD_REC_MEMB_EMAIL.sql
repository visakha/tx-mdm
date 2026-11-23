-- sp_snow_pub_ECI_PHN_EXC_STG_BAD_REC_MEMB_EMAIL -- BARE-BONES variant (ECI)
-- Mapping: m_Tgt_C_S_ECI_Pty_Rle_Phn_And_EAddr, workflow wf_ECI_Stage_Load, publish step 90 (PUBLISH_EXC_STG_BAD_REC_MEMB_EMAIL).
-- Target: EXC_STG_BAD_REC_MEMB. Consumes: WRK_ECI_PHN_S50_READY.
-- Called by the driver inside the single publish transaction; no gating, no checkpointing.
-- INSERT below is verbatim from the v2.1 publish procedure.
CREATE OR REPLACE PROCEDURE sp_snow_pub_ECI_PHN_EXC_STG_BAD_REC_MEMB_EMAIL ()
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    l_rows    NUMBER DEFAULT 0;
BEGIN
    INSERT INTO EXC_STG_BAD_REC_MEMB
           (SRC_SYS, SRC_SYS_ID_1, EXCEPTION_CODE, EXCEPTION_DESC, RUN_DATE, EMAIL, MAPPING_NAME,
            EXCEPTION_TYPE, PERIOD_START_DATE, ATTRIBUTE_VALUE, ATTRIBUTE_NAME)
    SELECT src_sys, ID_FAMILY_PHONE, email_exception_code, email_exception_desc, run_ts, PHONE_EMAIL,
           mapping_name, email_exception_type, PERIOD_START_DATE, PHONE_EMAIL, exc_email_attribute
      FROM WRK_ECI_PHN_S50_READY
     WHERE grp_email_bad AND uq_email_exc;
    l_rows := SQLROWCOUNT;
    RETURN :l_rows;
END;
$$;
