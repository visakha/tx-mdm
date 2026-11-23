-- ============================================================================
-- sp_snow_pub_WIC_PHN_EXC_STG_BAD_REC_MEMB_PHONE  --  BARE-BONES STEP DRIVER VARIANT (WIC)
--
-- Mapping: m_Tgt_C_S_WIC_Pty_Rle_Phn_And_EAddr, workflow wf_WIC_Stage_Load.
-- Target: EXC_STG_BAD_REC_MEMB. Kind: EXCEPTION (bad-phone exceptions).
-- WHERE guard: grp_phone_bad AND uq_phone_exc.
-- Reads ONLY WRK_WIC_PHN_S40_READY. Reads the run_ts / mapping_name columns materialised in the final step; it takes no parameters.
--
-- Bare-bones variant: stripped of config gating, job tracking and
-- input checks; the INSERT below is unchanged business SQL. No
-- transaction control in this proc: the driver calls it inside ONE
-- publish transaction covering all branches.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_pub_WIC_PHN_EXC_STG_BAD_REC_MEMB_PHONE (
)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
    INSERT INTO EXC_STG_BAD_REC_MEMB
           (SRC_SYS, EXCEPTION_CODE, EXCEPTION_DESC, RUN_DATE, PRIMARY_PHONE, WORK_PHONE, SECONDARY_PHONE,
            MAPPING_NAME, SRC_SYS_ID_1, EXCEPTION_TYPE, SRC_SYS_ID_3, PERIOD_START_DATE, ATTRIBUTE_VALUE,
            ATTRIBUTE_NAME, SRC_SYS_ID_2)
    SELECT src_sys, phone_exception_code, phone_exception_desc, run_ts, std_phone, NULL, NULL, mapping_name,
           PTY_SRC_KEY, exc_type_bad_value, usg_tp, DATEKEY, std_phone, attr_phone, FID
      FROM WRK_WIC_PHN_S40_READY
     WHERE grp_phone_bad AND uq_phone_exc;
    RETURN SQLROWCOUNT;
END;
$$;
