-- sp_snow_pub_ECI_PHN_EXC_STG_BAD_REC_MEMB_PHONE -- BARE-BONES variant (ECI)
-- Mapping: m_Tgt_C_S_ECI_Pty_Rle_Phn_And_EAddr, workflow wf_ECI_Stage_Load, publish step 70 (PUBLISH_EXC_STG_BAD_REC_MEMB_PHONE).
-- Target: EXC_STG_BAD_REC_MEMB. Consumes: WRK_ECI_PHN_S50_READY.
-- Called by the driver inside the single publish transaction; no gating, no checkpointing.
-- INSERT below is verbatim from the v2.1 publish procedure.
CREATE OR REPLACE PROCEDURE sp_snow_pub_ECI_PHN_EXC_STG_BAD_REC_MEMB_PHONE ()
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    l_rows    NUMBER DEFAULT 0;
BEGIN
    INSERT INTO EXC_STG_BAD_REC_MEMB
           (SRC_SYS, EXCEPTION_CODE, EXCEPTION_DESC, RUN_DATE, PRIMARY_PHONE, WORK_PHONE, SECONDARY_PHONE,
            MAPPING_NAME, SRC_SYS_ID_1, EXCEPTION_TYPE, SRC_SYS_ID_3, PERIOD_START_DATE, ATTRIBUTE_VALUE,
            SRC_SYS_ID_2, ATTRIBUTE_NAME)
    SELECT src_sys, phone_exception_code, phone_exception_desc, run_ts, exc_primary_phone, exc_work_phone,
           exc_secondary_phone, mapping_name, NULL, exc_type_bad_value, USG_TP, PERIOD_START_DATE,
           std_phone, ID_CASE, exc_phone_attribute
      FROM WRK_ECI_PHN_S50_READY
     WHERE grp_phone_bad AND uq_phone_exc;
    l_rows := SQLROWCOUNT;
    RETURN :l_rows;
END;
$$;
